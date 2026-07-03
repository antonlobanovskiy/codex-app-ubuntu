# Codex App Ubuntu

Unofficial Ubuntu installer for running the OpenAI Codex desktop app from a
user-supplied macOS Intel DMG.

This repository does not contain the Codex desktop app, the DMG, a repacked
`app.asar`, Electron binaries, icons, extracted assets, auth files, user data,
logs, or screenshots. It contains only installer scripts, compatibility
patches, and documentation.

## Status

- Tested on Ubuntu 24.04 x86_64 with GNOME/X11.
- Requires an OpenAI Codex desktop DMG that you already obtained from OpenAI.
- Requires the Codex CLI to be installed and authenticated separately.
- This is unsupported by OpenAI.

OpenAI's public docs describe the Codex app as available on macOS and Windows.
The open-source component used by rich clients is the Codex app-server in the
`openai/codex` repository; the desktop app itself is not redistributed here.

## Install

Install system dependencies first:

```bash
sudo apt update
sudo apt install -y nodejs npm p7zip-full rsync python3 make g++
```

Install the Codex CLI and sign in:

```bash
npm install -g @openai/codex
codex login
```

Then run the installer with your local DMG:

```bash
./scripts/install.sh ~/Downloads/Codex-latest-x64.dmg
```

Launch it from your app menu as **Codex Ubuntu Port**, or run:

```bash
codex-desktop-linux
```

Optional user service:

```bash
./scripts/install.sh --service ~/Downloads/Codex-latest-x64.dmg
systemctl --user start codex-app-ubuntu
```

## What The Installer Does

1. Extracts `Codex.app` from the DMG locally.
2. Extracts the app's `app.asar` into a temporary staging directory.
3. Installs a matching Linux Electron runtime from npm.
4. Rebuilds Linux native modules used by the app.
5. Applies Linux window-manager compatibility patches.
6. Installs a small Linux Node REPL/MCP shim for Browser Use.
7. Repackages the local app into `~/.local/share/codex-app-ubuntu`.
8. Creates a launcher and desktop entry.

## Security Boundary

Do not commit or publish anything produced by the installer. Generated output
contains upstream app code and may contain local state if you run the app.

Before publishing changes to this repository, run:

```bash
./scripts/prepublish-audit.sh
```

The audit fails on known risky file types, extracted app directories, auth
caches, user-data, large binaries, and common token patterns.

## Authentication

This port uses your existing Codex CLI authentication. Codex local credentials
live in `~/.codex/auth.json` or your OS credential store, depending on your
Codex configuration. The installer does not copy those credentials into this
repository.

To log out:

```bash
codex logout
rm -rf ~/.local/share/codex-app-ubuntu/user-data
```

## Legal Notes

The MIT license in this repository applies only to this repository's original
scripts and documentation. It does not grant rights to redistribute OpenAI
Codex Desktop, OpenAI assets, OpenAI trademarks, Electron, Node.js, or any
third-party dependency.

If you fork this project, keep it as an installer/patcher. Do not publish the
converted app, DMG contents, repacked ASAR, icons, logs, user-data, or auth
files.
