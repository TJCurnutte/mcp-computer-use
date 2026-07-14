"""Backwards-compatible shim. The server now lives in the mcp_computer_use package."""
from mcp_computer_use.server import main

if __name__ == "__main__":
    main()
