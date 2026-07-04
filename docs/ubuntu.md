# Ubuntu Setup

These steps prepare Ubuntu before running the shared Linux installer.

Tested target:

- Ubuntu 24.04 x86_64
- GNOME/X11

Install system packages:

```bash
sudo apt update
sudo apt install -y curl p7zip-full rsync xdg-utils python3 make g++
```

Install Node.js 22 or newer if `node --version` is older than `v22`:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node --version
```

Return to the main [README](../README.md) and continue with the DMG download,
Codex CLI login, and `scripts/install.sh`.
