## Summary

-

## Type

- [ ] Distro support or test result
- [ ] Installer fix
- [ ] Linux compatibility patch
- [ ] Documentation
- [ ] Security/audit cleanup

## Distro Test Evidence

Fill this out for distro support PRs.

- Distro and version:
- Desktop environment:
- Session type: X11 / Wayland / other:
- CPU architecture:
- Node.js version:
- npm version:
- Codex CLI version:
- DMG source used: official download page / direct x64 DMG / existing local copy

Dependency install command:

```bash

```

Installer command:

```bash

```

Results:

- [ ] `scripts/install.sh` completed
- [ ] `codex-desktop-linux` launched the app
- [ ] desktop entry appeared in the app menu
- [ ] login/auth worked through existing Codex CLI credentials
- [ ] Browser Use shim was not tested
- [ ] Browser Use shim worked

Known gaps:

-

## Safety Checklist

- [ ] I did not commit or upload the DMG.
- [ ] I did not commit extracted app files, `app.asar`, `Codex.app`, Electron runtimes, native binaries, logs, screenshots with secrets, or user data.
- [ ] I did not commit `~/.codex/auth.json`, `.env`, GitHub CLI config, tokens, private keys, or certificates.
- [ ] I ran `./scripts/prepublish-audit.sh`.

Audit output:

```text

```
