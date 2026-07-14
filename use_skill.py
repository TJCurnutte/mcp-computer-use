"""Use the MCP computer-use skill to set up the project git repo."""

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

        cwd = "/Users/curnutte/CascadeProjects/mcp-computer-use"
        await call_tool(session, "run_shell_command", {"command": "git init", "cwd": cwd})
        await call_tool(session, "run_shell_command", {"command": "git config user.email 'agent@example.com'", "cwd": cwd})
        await call_tool(session, "run_shell_command", {"command": "git config user.name 'MCP Agent'", "cwd": cwd})
        await call_tool(session, "run_shell_command", {"command": "git add -A", "cwd": cwd})
        await call_tool(session, "run_shell_command", {"command": "git commit -m 'Initial commit of mcp-computer-use enterprise package'", "cwd": cwd})


if __name__ == "__main__":
    asyncio.run(main())
