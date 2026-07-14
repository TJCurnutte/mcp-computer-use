"""Test client for the MCP computer-use server."""

import asyncio
import json
import sys
from contextlib import AsyncExitStack

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


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

        # Non-invasive tests
        for tool in ["get_display_info", "get_cursor_position", "wait"]:
            args = {"duration": 0.2} if tool == "wait" else {}
            result = await session.call_tool(tool, arguments=args)
            print(f"\n{tool}:")
            print(result.content[0].text[:500])

        # Screenshot
        result = await session.call_tool("screenshot", arguments={"display": 0})
        payload = json.loads(result.content[0].text)
        print("\nscreenshot:", {k: v for k, v in payload.items() if k != "image"})

        # Shell command (safe)
        result = await session.call_tool("run_shell_command", arguments={"command": "pwd"})
        print("\nrun_shell_command pwd:")
        print(result.content[0].text[:500])

        # Clipboard write/read
        result = await session.call_tool("clipboard_set", arguments={"text": "mcp-computer-use test"})
        print("\nclipboard_set:", result.content[0].text[:200])
        result = await session.call_tool("clipboard_get", arguments={})
        print("clipboard_get:", result.content[0].text[:200])

        # Open app (Terminal) - may bring it forward
        # result = await session.call_tool("open_app", arguments={"name": "Terminal"})
        # print("\nopen_app:", result.content[0].text[:500])


if __name__ == "__main__":
    asyncio.run(main())
