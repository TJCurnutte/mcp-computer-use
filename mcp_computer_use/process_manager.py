"""Long-running process management for the computer-use server."""

import os
import queue
import subprocess
import threading
import time
import uuid
from typing import Dict, Optional

from .utils import get_logger

logger = get_logger("mcp-computer-use.process_manager")


class ProcessManager:
    """Start, read, and kill long-running shell processes."""

    def __init__(self):
        self._processes: Dict[str, subprocess.Popen] = {}
        self._output_queues: Dict[str, queue.Queue] = {}
        self._locks: Dict[str, threading.Lock] = {}
        self._threads: Dict[str, threading.Thread] = {}

    def start(self, command: str, cwd: Optional[str] = None, env: Optional[dict] = None) -> dict:
        process_id = str(uuid.uuid4())
        try:
            proc = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=cwd,
                env=env,
                bufsize=1,
                universal_newlines=True,
            )
            q = queue.Queue()
            lock = threading.Lock()
            self._processes[process_id] = proc
            self._output_queues[process_id] = q
            self._locks[process_id] = lock
            t = threading.Thread(target=self._reader, args=(process_id, proc, q), daemon=True)
            t.start()
            self._threads[process_id] = t
            logger.info(f"Started process {process_id}: {command}")
            return {
                "process_id": process_id,
                "pid": proc.pid,
                "command": command,
                "running": True,
            }
        except Exception as e:
            return {"error": str(e), "command": command}

    def _reader(self, process_id: str, proc: subprocess.Popen, q: queue.Queue):
        """Read stdout and stderr lines into a queue."""
        def _read_stream(stream, name):
            try:
                for line in iter(stream.readline, ""):
                    q.put((name, line))
            except Exception as e:
                logger.debug(f"Process {process_id} {name} reader finished: {e}")
            finally:
                try:
                    stream.close()
                except Exception:
                    pass

        stdout_thread = threading.Thread(target=_read_stream, args=(proc.stdout, "stdout"), daemon=True)
        stderr_thread = threading.Thread(target=_read_stream, args=(proc.stderr, "stderr"), daemon=True)
        stdout_thread.start()
        stderr_thread.start()
        stdout_thread.join()
        stderr_thread.join()
        proc.wait()
        q.put(("exit", proc.returncode))

    def read(self, process_id: str, timeout: float = 0.5, max_lines: int = 100) -> dict:
        with self._locks.get(process_id, threading.Lock()):
            pass
        q = self._output_queues.get(process_id)
        proc = self._processes.get(process_id)
        if q is None or proc is None:
            return {"error": "process not found", "process_id": process_id}

        lines = []
        start = time.time()
        while len(lines) < max_lines and (time.time() - start) < timeout:
            try:
                channel, data = q.get_nowait()
                if channel == "exit":
                    lines.append({"channel": "exit", "code": data})
                    break
                lines.append({"channel": channel, "line": data})
            except queue.Empty:
                if proc.poll() is not None:
                    break
                time.sleep(0.05)

        return {
            "process_id": process_id,
            "running": proc.poll() is None,
            "lines": lines,
            "returncode": proc.poll(),
        }

    def kill(self, process_id: str, signal_name: str = "SIGTERM") -> dict:
        proc = self._processes.get(process_id)
        if proc is None:
            return {"error": "process not found", "process_id": process_id}
        try:
            sig = getattr(os, signal_name, None)
            if sig is None:
                return {"error": f"unknown signal {signal_name}", "process_id": process_id}
            proc.send_signal(sig)
            return {"killed": True, "process_id": process_id, "signal": signal_name}
        except Exception as e:
            return {"error": str(e), "process_id": process_id}


PROCESS_MANAGER = ProcessManager()
