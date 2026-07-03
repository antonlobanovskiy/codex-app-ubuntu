# Security And Publishing Checklist

This repo is designed to be safe to publish because it excludes generated app
output and local identity material.

## Never Commit

- `Codex-latest-x64.dmg`
- `Codex.app`
- `app.asar`
- extracted app folders
- Electron runtime folders
- native addon binaries such as `.node` files
- `~/.codex/auth.json`
- `~/.config/gh/hosts.yml`
- Electron `user-data` directories
- logs, screenshots, caches, crash reports
- files named `client_secret*.json`
- `.env` files, private keys, certificates, tokens

## Required Before Push

```bash
./scripts/prepublish-audit.sh
git status --short
git diff --cached --stat
```

The audit intentionally blocks large files and common credential patterns. It
is conservative: if it fails, inspect the path instead of adding an exception.

## GitHub Token Note

The GitHub CLI stores its token in `~/.config/gh/hosts.yml`. This repository's
ignore file blocks that filename. Do not copy GitHub CLI config into this repo.

## Codex Token Note

Codex can store ChatGPT OAuth refresh tokens in `~/.codex/auth.json`. This file
must be treated like a password. Do not copy it into this repo or paste it into
issues, logs, or support requests.
