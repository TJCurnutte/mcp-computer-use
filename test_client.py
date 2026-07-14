"""Test client for the MCP computer-use server."""

import asyncio
import json
import sys
from contextlib import AsyncExitStack

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def call_tool(session, name, args):
    result = await session.call_tool(name, arguments=args)
    text = result.content[0].text
    print(f"\n[{name}] {json.dumps(args)}")
    print(text[:1000])
    return json.loads(text)


async def main():
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
        print(f"Tools: {len(tools.tools)} tools")
        print([t.name for t in tools.tools])

        await call_tool(session, "get_status", {})
        await call_tool(session, "get_display_info", {})
        await call_tool(session, "get_cursor_position", {})
        await call_tool(session, "wait", {"duration": 0.2})

        payload = await call_tool(session, "screenshot", {"display": 0})
        print("screenshot meta:", {k: v for k, v in payload.items() if k != "image"})

        region = await call_tool(session, "screenshot_region", {"left": 0, "top": 0, "width": 400, "height": 300})
        print("screenshot_region meta:", {k: v for k, v in region.items() if k != "image"})

        await call_tool(session, "list_windows", {})

        await call_tool(session, "run_shell_command", {"command": "pwd"})
        await call_tool(session, "clipboard_set", {"text": "mcp-computer-use test"})
        await call_tool(session, "clipboard_get", {})

        await call_tool(session, "list_dir", {"path": "/Users/curnutte/CascadeProjects/mcp-computer-use"})
        await call_tool(session, "write_file", {
            "path": "/Users/curnutte/.mcp-computer-use/test.txt",
            "content": "hello from mcp-computer-use",
        })
        await call_tool(session, "read_file", {"path": "/Users/curnutte/.mcp-computer-use/test.txt"})
        result = await call_tool(session, "delete_file", {"path": "/Users/curnutte/.mcp-computer-use/test.txt"})
        if result.get("requires_confirmation"):
            await call_tool(session, "confirm_sensitive_action", {"pending_id": result["pending_id"]})

        result = await call_tool(session, "process_start", {"command": "ping -c 30 127.0.0.1"})
        pid = result.get("process_id")
        await asyncio.sleep(0.3)
        await call_tool(session, "process_read", {"process_id": pid, "timeout": 0.5, "max_lines": 10})
        await call_tool(session, "process_kill", {"process_id": pid, "signal": "SIGTERM"})

        result = await call_tool(session, "find_text_on_screen", {"text": "mcp", "display": 0})
        print("OCR count:", result.get("count"))


if __name__ == "__main__":
    asyncio.run(main())
