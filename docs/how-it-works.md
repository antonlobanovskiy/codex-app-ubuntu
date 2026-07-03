# How It Works

The official desktop app is an Electron application packaged for supported
desktop platforms. This project performs a local compatibility conversion:

- keep the user's upstream DMG local
- extract the app locally
- replace the Electron runtime with Linux Electron
- rebuild Linux native modules for the app's Electron ABI
- patch Linux window options so GNOME manages the windows normally
- install a Linux launcher and desktop entry

The most important Linux window patch is avoiding unmanaged override-redirect
windows for the primary app window. The patch keeps Linux primary windows
framed, taskbar-visible, minimizable, maximizable, resizable, and workspace
managed.

The Browser Use helper in the macOS bundle is a Mach-O executable. The installer
keeps the original file as a local backup and replaces `node_repl` with a small
Linux Node.js MCP shim. That shim is original code in this repository.

Generated files are installed under:

```text
~/.local/share/codex-app-ubuntu/
~/.local/bin/codex-desktop-linux
~/.local/share/applications/codex-app-ubuntu.desktop
```

Those paths are install output, not source code for this repository.
