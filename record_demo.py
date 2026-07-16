#!/usr/bin/env python3
"""Record a short Reflex demo video by driving the MCP server while ffmpeg captures the screen."""

import asyncio
import json
import os
import re
import subprocess
import sys
import time
from contextlib import AsyncExitStack
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

REPO_ROOT = Path(__file__).resolve().parent
VIDEO_PATH = REPO_ROOT / "site" / "reflex-demo-raw.mp4"
FINAL_PATH = REPO_ROOT / "site" / "reflex-demo.mp4"
TITLE_IMG = REPO_ROOT / "site" / "reflex-demo-title.png"
TITLE_CLIP = REPO_ROOT / "site" / "reflex-demo-title.mp4"


def get_screen_device() -> str:
    """Return the avfoundation device spec for the first screen capture source."""
    proc = subprocess.run(
        ["ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", ""],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    for line in proc.stdout.splitlines():
        match = re.search(r"\[(\d+)\] Capture screen", line)
        if match:
            return f"{match.group(1)}:none"
    raise RuntimeError("No screen capture device found in ffmpeg output")


def start_ffmpeg(device: str) -> subprocess.Popen:
    VIDEO_PATH.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "ffmpeg",
        "-y",
        "-f", "avfoundation",
        "-i", device,
        "-r", "30",
        "-pix_fmt", "yuv420p",
        "-an",
        str(VIDEO_PATH),
    ]
    return subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )


def stop_ffmpeg(proc: subprocess.Popen) -> None:
    try:
        proc.stdin.write(b"q")
        proc.stdin.flush()
    except Exception:
        pass
    try:
        outs, errs = proc.communicate(timeout=10)
    except Exception:
        proc.terminate()
        try:
            outs, errs = proc.communicate(timeout=5)
        except Exception:
            errs = b""
    if proc.returncode not in (0, 255):
        print("ffmpeg stderr:", errs.decode("utf-8", "ignore")[-500:], file=sys.stderr)


async def call_tool(session, name, args):
    result = await session.call_tool(name, arguments=args)
    text = result.content[0].text
    try:
        data = json.loads(text)
    except Exception:
        data = text
    return data


async def run_demo() -> None:
    server_params = StdioServerParameters(
        command=sys.executable,
        args=["-m", "mcp_computer_use"],
        env=None,
    )

    async with AsyncExitStack() as stack:
        stdio_transport = await stack.enter_async_context(stdio_client(server_params))
        session = await stack.enter_async_context(ClientSession(*stdio_transport))
        await session.initialize()

        tools = await session.list_tools()
        print(f"Connected. {len(tools.tools)} tools available.")

        await asyncio.sleep(1)

        print("-> get_status")
        await call_tool(session, "get_status", {})

        print("-> Open Calculator")
        await call_tool(session, "open_app", {"name": "Calculator"})
        await asyncio.sleep(0.5)
        await call_tool(session, "keyboard_type", {"text": "123456789"})
        await asyncio.sleep(0.3)

        print("-> Open Terminal and run a command")
        await call_tool(session, "open_app", {"name": "Terminal"})
        await asyncio.sleep(0.5)
        await call_tool(session, "key", {"keys": "command+n"})
        await asyncio.sleep(0.3)
        await call_tool(session, "keyboard_type", {"text": "date"})
        await call_tool(session, "key", {"keys": "return"})
        await asyncio.sleep(0.5)

        print("-> Open Notes and type a message")
        await call_tool(session, "open_app", {"name": "Notes"})
        await asyncio.sleep(0.8)
        await call_tool(session, "key", {"keys": "command+n"})
        await asyncio.sleep(0.3)
        await call_tool(session, "keyboard_type", {"text": "Hello from Reflex AI"})
        await asyncio.sleep(0.5)

        print("-> Take a screenshot")
        await call_tool(session, "screenshot", {"display": 0})
        await asyncio.sleep(1)


def make_title_card(screen_width: int, screen_height: int) -> None:
    """Create a PNG title card matching the screen dimensions."""
    from PIL import Image, ImageDraw, ImageFont

    bg = (15, 23, 42)  # #0f172a
    img = Image.new("RGB", (screen_width, screen_height), bg)
    draw = ImageDraw.Draw(img)

    # Try to load a decent system font; fall back to the default bitmap font.
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Andale Mono.ttf",
    ]
    font_large = None
    font_small = None
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                font_large = ImageFont.truetype(fp, screen_height // 8)
                font_small = ImageFont.truetype(fp, screen_height // 20)
                break
            except Exception:
                pass
    if font_large is None:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()

    title = "Reflex"
    subtitle = "AI control for your Mac"
    bbox = draw.textbbox((0, 0), title, font=font_large)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((screen_width - tw) // 2, (screen_height - th) // 2 - screen_height // 15), title, fill="white", font=font_large)

    bbox = draw.textbbox((0, 0), subtitle, font=font_small)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((screen_width - tw) // 2, (screen_height - th) // 2 + screen_height // 12), subtitle, fill=(148, 163, 184), font=font_small)

    img.save(TITLE_IMG)

    # Turn the PNG into a 2-second MP4 clip.
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loop", "1",
            "-i", str(TITLE_IMG),
            "-c:v", "libx264",
            "-t", "2",
            "-pix_fmt", "yuv420p",
            str(TITLE_CLIP),
        ],
        check=True,
    )


def concat_and_scale() -> None:
    """Concatenate the title card and raw recording, scale to a web-friendly size."""
    list_file = REPO_ROOT / "site" / "concat_list.txt"
    list_file.write_text(
        f"file '{TITLE_CLIP.name}'\nfile '{VIDEO_PATH.name}'\n"
    )
    output_w, output_h = 1280, 720
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", str(list_file),
            "-vf",
            f"scale={output_w}:{output_h}:force_original_aspect_ratio=decrease,pad={output_w}:{output_h}:(ow-iw)/2:(oh-ih)/2:0x0f172a",
            "-c:v", "libx264",
            "-crf", "28",
            "-preset", "fast",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            str(FINAL_PATH),
        ],
        check=True,
    )
    list_file.unlink()


def get_video_dimensions(path: Path) -> tuple:
    proc = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height",
         "-of", "csv=p=0", str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 0 and proc.stdout.strip():
        w, h = proc.stdout.strip().split(",")
        return int(w), int(h)
    return 1280, 720


def main() -> int:
    device = get_screen_device()
    print(f"Using screen capture device: {device}")

    print("Starting screen capture...")
    ffmpeg_proc = start_ffmpeg(device)
    time.sleep(1.5)

    try:
        print("Running demo actions...")
        asyncio.run(run_demo())
    finally:
        print("Stopping screen capture...")
        stop_ffmpeg(ffmpeg_proc)

    if not VIDEO_PATH.exists():
        print("Error: raw screen capture did not produce a file.", file=sys.stderr)
        return 1

    screen_width, screen_height = get_video_dimensions(VIDEO_PATH)
    print(f"Raw video dimensions: {screen_width}x{screen_height}")

    print("Creating title card and finalizing video...")
    make_title_card(screen_width, screen_height)
    concat_and_scale()

    # Cleanup raw files.
    VIDEO_PATH.unlink(missing_ok=True)
    TITLE_CLIP.unlink(missing_ok=True)
    TITLE_IMG.unlink(missing_ok=True)

    size = FINAL_PATH.stat().st_size / (1024 * 1024)
    print(f"Demo video ready: {FINAL_PATH} ({size:.2f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
