# Distro Support Matrix

This matrix tracks where Codex App Linux has been installed and tested by the
project or community contributors. A distro is checked only after a PR includes
test evidence from a real machine or VM.

## Support Levels

- `[x] Tested`: installer ran and the app launched with evidence in a merged PR.
- `[ ] Needs PR`: no accepted test evidence yet.
- `[ ] In progress`: a contributor is actively testing or has a PR open.

## Matrix

| Tested | Distro | Family | Setup guide | Last tested | Evidence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [x] | Ubuntu 24.04 LTS | Debian/Ubuntu | [ubuntu.md](ubuntu.md) | GNOME/X11, x86_64 | Initial project test | Baseline distro. |
| [x] | Fedora Linux 44 Workstation Edition | Fedora/RHEL | [fedora.md](fedora.md) | Cinnamon/X11, x86_64 | Community PR | Installed with `dnf`; `scripts/install.sh` completed and `codex-desktop-linux` launched. Browser Use shim not tested. |
| [ ] | Debian Stable | Debian/Ubuntu | Needed | Pending | Needs PR | Likely close to Ubuntu with different Node.js setup. |
| [ ] | Linux Mint | Debian/Ubuntu | Needed | Pending | Needs PR | Ubuntu-family desktop distro. |
| [ ] | Pop!_OS | Debian/Ubuntu | Needed | Pending | Needs PR | Ubuntu-family desktop distro. |
| [ ] | Zorin OS | Debian/Ubuntu | Needed | Pending | Needs PR | Ubuntu-family desktop distro. |
| [ ] | elementary OS | Debian/Ubuntu | Needed | Pending | Needs PR | Ubuntu-family desktop distro. |
| [ ] | Arch Linux | Arch | Needed | Pending | Needs PR | Rolling distro; package names and native module builds need validation. |
| [ ] | EndeavourOS | Arch | Needed | Pending | Needs PR | Arch-family desktop distro. |
| [ ] | Manjaro | Arch | Needed | Pending | Needs PR | Arch-family desktop distro with delayed package channels. |
| [ ] | openSUSE Tumbleweed | openSUSE | Needed | Pending | Needs PR | Rolling openSUSE target. |
| [ ] | openSUSE Leap | openSUSE | Needed | Pending | Needs PR | Stable openSUSE target. |
| [ ] | Nobara | Fedora/RHEL | Needed | Pending | Needs PR | Fedora-family desktop distro. |
| [ ] | AlmaLinux | Fedora/RHEL | Needed | Pending | Needs PR | Enterprise Linux target; desktop packages may vary. |
| [ ] | Rocky Linux | Fedora/RHEL | Needed | Pending | Needs PR | Enterprise Linux target; desktop packages may vary. |

## How To Check Off A Distro

Open a PR that includes:

1. An update to the distro row above.
2. A setup guide under `docs/` if package commands differ from an existing
   guide.
3. Test evidence in the PR body using the repository PR template.
4. The result of `./scripts/prepublish-audit.sh`.

Keep the support matrix honest. If the app installs but has known gaps, leave
clear notes instead of marking the distro fully tested.
