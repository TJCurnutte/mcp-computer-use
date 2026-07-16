# Installing Reflex

These are the steps for someone who downloads the `.dmg` or `.zip` release.

## Install from the DMG

1. Open `Reflex.dmg`. A window opens showing `Reflex.app`, an `Applications` alias, and (if a window layout could not be applied) an `Instructions.txt` file.
2. Drag `Reflex.app` onto the `Applications` alias. This copies it to `/Applications/Reflex.app`.
3. Eject the disk image.
4. Open `Reflex` from `/Applications` (or from Launchpad).

## Install from the ZIP

1. Open `Reflex.zip`.
2. Move `Reflex.app` to `/Applications` (or `~/Applications`).
3. Open `Reflex` from the Applications folder.

## First run / onboarding

The first time you launch Reflex, it opens an onboarding window:

- Confirms the app is in `/Applications` (optional; you can keep it in `~/Applications`, but the LaunchAgent example below uses `/Applications`).
- Walks through Accessibility, Screen Recording, and Input Monitoring permissions.
- Installs or shows the MCP bridge config for Devin / Cursor / Windsurf.
- Runs a quick `get_status` and `screenshot` test.

## Start at login (LaunchAgent)

To start `Reflex` automatically when you log in:

```bash
cd MacMenuBar
./scripts/install_launchagent.sh
```

Then start it immediately with:

```bash
launchctl start com.curnutte.mcp-computer-use
```

The LaunchAgent is installed to `~/Library/LaunchAgents/com.curnutte.mcp-computer-use.plist`.

If you installed the app to `~/Applications` instead of `/Applications`, edit the `ProgramArguments` path in the plist before loading it.
