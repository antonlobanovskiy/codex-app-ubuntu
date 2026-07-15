# Codex App Linux

Unofficial Linux installer for running the OpenAI Codex desktop app from a
user-supplied macOS Intel DMG.

This repository does not contain the Codex desktop app, the DMG, a repacked
`app.asar`, Electron binaries, icons, extracted assets, auth files, user data,
logs, or screenshots. It contains only installer scripts, compatibility
patches, and documentation.

## Status

- Tested on Ubuntu 24.04 x86_64 with GNOME/X11.
- Tested on Fedora Linux 44 x86_64 with Cinnamon/X11.
- Requires an OpenAI Codex desktop DMG that you already obtained from OpenAI.
- Requires the Codex CLI to be installed and authenticated separately.
- This is unsupported by OpenAI.

OpenAI's public docs describe the Codex app as available on macOS and Windows.
The open-source component used by rich clients is the Codex app-server in the
`openai/codex` repository; the desktop app itself is not redistributed here.

## Distro Flavors

Use the same installer on each supported Linux distro. The distro-specific part
is installing system packages before running `scripts/install.sh`.

| Distro | Status | Setup |
| --- | --- | --- |
| Ubuntu 24.04 x86_64 | Tested | [docs/ubuntu.md](docs/ubuntu.md) |
| Fedora Linux 44 Cinnamon/X11 x86_64 | Tested | [docs/fedora.md](docs/fedora.md) |

See [docs/distro-support.md](docs/distro-support.md) for the full distro
support matrix and test checklist. Contributions for new distros should follow
[CONTRIBUTING.md](CONTRIBUTING.md).

## Quick Start

This installer needs the official macOS Intel Codex DMG. The DMG is not
included in this repository.

Download it from either source:

- Official Codex app download page:
  <https://developers.openai.com/codex/app>
- Direct current macOS Intel DMG:
  <https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg>

Install dependencies for your distro:

- Ubuntu: [docs/ubuntu.md](docs/ubuntu.md)
- Fedora: [docs/fedora.md](docs/fedora.md)

Download the required DMG:

```bash
mkdir -p ~/Downloads
curl -L --fail \
  -o ~/Downloads/Codex-latest-x64.dmg \
  https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg
```

Install the Codex CLI and sign in. If sign-in opens a browser, finish the
browser flow before continuing:

```bash
npm install -g @openai/codex
codex login
```

Clone this repository, run the installer, and launch the app:

```bash
git clone https://github.com/antonlobanovskiy/codex-app-linux.git
cd codex-app-linux
./scripts/install.sh ~/Downloads/Codex-latest-x64.dmg
codex-desktop-linux
```

You can also launch it from your app menu as **Codex Linux Port**.

## AI Agent Runbook

Give this section to an AI agent with shell access on Linux x86_64. The agent
should run the commands from a normal working directory such as `~/dev`.

```bash
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y curl p7zip-full rsync xdg-utils python3 make g++
  if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)" -lt 22 ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
  fi
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y curl p7zip p7zip-plugins rsync xdg-utils python3 make gcc-c++ nodejs npm
  if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)" -lt 22 ]; then
    echo "Node.js 22 or newer is required. Install or enable a newer Node.js package, then rerun this runbook." >&2
    exit 1
  fi
else
  echo "Unsupported package manager. Install curl, 7z, rsync, xdg-open, Node.js 22+, npm, python3, make, and a C++ compiler." >&2
  exit 1
fi

mkdir -p "$HOME/Downloads"
curl -L --fail \
  -o "$HOME/Downloads/Codex-latest-x64.dmg" \
  https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg

npm install -g @openai/codex
codex login

mkdir -p "$HOME/dev"
cd "$HOME/dev"
git clone https://github.com/antonlobanovskiy/codex-app-linux.git
cd codex-app-linux

./scripts/install.sh "$HOME/Downloads/Codex-latest-x64.dmg"
codex-desktop-linux
```

Agent rules:

- Stop at `codex login` if user interaction is required, then continue after
  the user finishes sign-in.
- Do not commit or upload `Codex-latest-x64.dmg`, `Codex.app`, `app.asar`,
  extracted app folders, Electron runtime folders, user-data, logs, screenshots,
  or credentials.
- Before pushing any repository changes, run:

```bash
./scripts/prepublish-audit.sh
git status --short
```

Optional user service:

```bash
./scripts/install.sh --service ~/Downloads/Codex-latest-x64.dmg
systemctl --user start codex-app-linux
```

## What The Installer Does

1. Extracts `Codex.app` from the DMG locally.
2. Extracts the app's `app.asar` into a temporary staging directory.
3. Installs a matching Linux Electron runtime from npm.
4. Rebuilds Linux native modules used by the app.
5. Applies Linux window-manager compatibility patches.
6. Installs a small Linux Node REPL/MCP shim for Browser Use.
7. Repackages the local app into `~/.local/share/codex-app-linux`.
8. Creates a launcher and desktop entry.

## Security Boundary

Do not commit or publish anything produced by the installer. Generated output
contains upstream app code and may contain local state if you run the app.

Before publishing changes to this repository, run:

```bash
./scripts/prepublish-audit.sh
```

The audit fails on known risky file types, extracted app directories, auth
caches, user-data, large binaries, common token patterns, and stale public
Ubuntu-specific project naming.

## Authentication

This port uses your existing Codex CLI authentication. Codex local credentials
live in `~/.codex/auth.json` or your OS credential store, depending on your
Codex configuration. The installer does not copy those credentials into this
repository.

To log out:

```bash
codex logout
rm -rf ~/.local/share/codex-app-linux/user-data
```

## Legal Notes

The MIT license in this repository applies only to this repository's original
scripts and documentation. It does not grant rights to redistribute OpenAI
Codex Desktop, OpenAI assets, OpenAI trademarks, Electron, Node.js, or any
third-party dependency.

If you fork this project, keep it as an installer/patcher. Do not publish the
converted app, DMG contents, repacked ASAR, icons, logs, user-data, or auth
files.
