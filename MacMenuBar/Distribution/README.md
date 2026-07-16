# Reflex Distribution

This directory contains the release packaging assets for `Reflex`.

- `build_dmg.sh` — creates a drag-to-Applications DMG.
- `build_zip.sh` — creates a `.zip` archive of the app.
- `background.png` — DMG window background image.
- `Instructions.txt` — fallback instructions shown in the DMG if Finder layout cannot be configured.

## Build the app

`build_dmg.sh` and `build_zip.sh` both read `MacMenuBar/MCPMenuBar/build/Reflex.app`, which is produced by:

```bash
cd MacMenuBar/MCPMenuBar
./build_app.sh
```

`build_app.sh` already applies an ad-hoc code signature (`codesign -s - --force --deep`), so no additional signing or notarization is performed here.

## Build the release archives

From this directory:

```bash
./build_dmg.sh
./build_zip.sh
```

Outputs:

- `MacMenuBar/MCPMenuBar/build/Reflex.dmg`
- `MacMenuBar/MCPMenuBar/build/Reflex.zip`

`build_dmg.sh` attempts to set a polished window background and icon positions via `osascript`/`Finder`. If it is run in a non-GUI environment (e.g. CI) it falls back to placing `Instructions.txt` in the DMG window. The default `osascript` timeout is 60 seconds; you can override it with:

```bash
MCP_MENUBAR_BUILD_TIMEOUT=30 ./build_dmg.sh
```

`hdiutil internet-enable` is attempted at the end for compatibility with older macOS versions, but it is not present on macOS 10.15+ and is safely skipped.

## Install the app

For end-user install steps, see `INSTALL.md`.

## Install the LaunchAgent

The included LaunchAgent starts `Reflex` at login:

```bash
cd MacMenuBar
./scripts/install_launchagent.sh
```

This copies `LaunchAgent/com.curnutte.mcp-computer-use.plist` to `~/Library/LaunchAgents/` and loads it with `launchctl`. To start immediately:

```bash
launchctl start com.curnutte.mcp-computer-use
```

If you installed the app somewhere other than `/Applications/Reflex.app`, edit the `ProgramArguments` path in the plist before loading it.
