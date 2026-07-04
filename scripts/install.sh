#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

install_root="${CODEX_APP_LINUX_ROOT:-${CODEX_APP_UBUNTU_ROOT:-$HOME/.local/share/codex-app-linux}}"
bin_dir="${CODEX_APP_LINUX_BIN_DIR:-${CODEX_APP_UBUNTU_BIN_DIR:-$HOME/.local/bin}}"
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
install_service=0
keep_work=0
dmg_path=""

usage() {
  cat <<'USAGE'
usage: scripts/install.sh [--service] [--keep-work] /path/to/Codex-latest-x64.dmg

Options:
  --service    Install a systemd user service named codex-app-linux.
  --keep-work  Keep temporary extraction/build directories for debugging.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --service)
      install_service=1
      shift
      ;;
    --keep-work)
      keep_work=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$dmg_path" ]; then
        printf 'only one DMG path is supported\n' >&2
        exit 2
      fi
      dmg_path="$1"
      shift
      ;;
  esac
done

if [ -z "$dmg_path" ]; then
  dmg_path="$HOME/Downloads/Codex-latest-x64.dmg"
fi

fail() {
  printf 'install failed: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[codex-app-linux] %s\n' "$*" >&2
}

require_cmd() {
  local cmd="$1"
  local hint="$2"
  command -v "$cmd" >/dev/null 2>&1 || fail "missing command '$cmd'. $hint"
}

find_7z() {
  if command -v 7z >/dev/null 2>&1; then
    command -v 7z
    return
  fi
  if command -v 7zz >/dev/null 2>&1; then
    command -v 7zz
    return
  fi
  fail "missing 7z/7zz. Install p7zip-full on Ubuntu or p7zip/p7zip-plugins on Fedora."
}

shell_quote() {
  printf '%q' "$1"
}

extract_app_from_dmg() {
  local dmg="$1"
  local dest="$2"
  local sevenz="$3"
  local raw="$dest/raw"
  local app_path

  mkdir -p "$raw"
  log "extracting DMG"
  "$sevenz" x -y "$dmg" "-o$raw" >/dev/null

  app_path="$(find "$raw" -type d -name 'Codex.app' -print -quit)"
  if [ -n "$app_path" ]; then
    printf '%s\n' "$app_path"
    return
  fi

  local index=0
  while IFS= read -r image; do
    index=$((index + 1))
    local nested="$dest/nested-$index"
    mkdir -p "$nested"
    log "extracting nested image $(basename "$image")"
    "$sevenz" x -y "$image" "-o$nested" >/dev/null || true
    app_path="$(find "$nested" -type d -name 'Codex.app' -print -quit)"
    if [ -n "$app_path" ]; then
      printf '%s\n' "$app_path"
      return
    fi
  done < <(find "$raw" -type f \( -iname '*.hfs' -o -iname '*.img' -o -iname '*.dmg' \) -size +10M -print)

  fail "could not find Codex.app inside $dmg"
}

infer_electron_version() {
  local app_dir="$1"
  node - "$app_dir/package.json" <<'NODE'
const fs = require('node:fs');
const pkg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const raw = pkg.devDependencies && pkg.devDependencies.electron;
if (!raw) process.exit(1);
process.stdout.write(String(raw).replace(/^[^0-9]*/, ''));
NODE
}

resolve_electron_dist() {
  local runner_dir="$1"
  node - "$runner_dir" <<'NODE'
const path = require('node:path');
const runner = process.argv[2];
const electronPath = require(path.join(runner, 'node_modules', 'electron'));
process.stdout.write(path.dirname(electronPath));
NODE
}

write_launcher() {
  local launcher="$1"
  local app_root="$2"
  local log_dir="$3"
  local browser_node="$4"
  local codex_bin="${5:-}"

  mkdir -p "$(dirname "$launcher")" "$log_dir"
  cat > "$launcher" <<LAUNCHER
#!/usr/bin/env bash
set -euo pipefail

APP_ROOT=$(shell_quote "$app_root")
LOG_DIR=$(shell_quote "$log_dir")
DEFAULT_BROWSER_NODE=$(shell_quote "$browser_node")
DEFAULT_CODEX_BIN=$(shell_quote "$codex_bin")

mkdir -p "\$LOG_DIR"

if [ -n "\${DEFAULT_CODEX_BIN}" ] && [ -z "\${CODEX_CLI_PATH:-}" ]; then
  export CODEX_CLI_PATH="\$DEFAULT_CODEX_BIN"
fi

export CODEX_ELECTRON_USER_DATA_PATH="\${CODEX_ELECTRON_USER_DATA_PATH:-\$HOME/.local/share/codex-app-linux/user-data}"
export CODEX_BROWSER_USE_NODE_PATH="\${CODEX_BROWSER_USE_NODE_PATH:-\$DEFAULT_BROWSER_NODE}"
export ELECTRON_OZONE_PLATFORM_HINT="\${ELECTRON_OZONE_PLATFORM_HINT:-x11}"

exec "\$APP_ROOT/codex-electron" --no-sandbox --ozone-platform=x11 "\$@" >>"\$LOG_DIR/codex-desktop-linux.log" 2>&1
LAUNCHER
  chmod 0755 "$launcher"
}

write_desktop_entry() {
  local desktop_file="$1"
  local launcher="$2"
  local icon_path="$3"

  mkdir -p "$(dirname "$desktop_file")"
  cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Codex Linux Port
Comment=Unofficial local Linux launcher for Codex Desktop
Exec=$launcher %u
Terminal=false
Categories=Development;
StartupWMClass=Codex
MimeType=x-scheme-handler/codex;
DESKTOP

  if [ -f "$icon_path" ]; then
    printf 'Icon=%s\n' "$icon_path" >> "$desktop_file"
  fi
}

write_service() {
  local service_file="$1"
  local launcher="$2"

  mkdir -p "$(dirname "$service_file")"
  cat > "$service_file" <<SERVICE
[Unit]
Description=Codex Linux Port

[Service]
Type=simple
ExecStart=$launcher
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
SERVICE
  systemctl --user daemon-reload || true
}

require_cmd node "Install Node.js 22 or newer."
require_cmd npm "Install npm."
require_cmd rsync "Install rsync. See docs/ubuntu.md or docs/fedora.md."
require_cmd python3 "Install build dependencies. See docs/ubuntu.md or docs/fedora.md."
require_cmd make "Install build dependencies. See docs/ubuntu.md or docs/fedora.md."
require_cmd g++ "Install build dependencies. See docs/ubuntu.md or docs/fedora.md."

sevenz="$(find_7z)"

[ -f "$dmg_path" ] || fail "DMG not found: $dmg_path"

arch="$(uname -m)"
[ "$arch" = "x86_64" ] || fail "only x86_64 Linux is currently supported; got $arch"

work="$(mktemp -d "${TMPDIR:-/tmp}/codex-app-linux.XXXXXX")"
if [ "$keep_work" -eq 0 ]; then
  trap 'rm -rf "$work"' EXIT
else
  log "keeping work directory: $work"
fi

codex_app="$(extract_app_from_dmg "$dmg_path" "$work/dmg" "$sevenz")"
resources_dir="$codex_app/Contents/Resources"
[ -f "$resources_dir/app.asar" ] || fail "missing app.asar in $resources_dir"

tools_dir="$install_root/tools"
runner_dir="$tools_dir/electron-runner"
native_dir="$tools_dir/native-linux"
mkdir -p "$runner_dir" "$native_dir"

log "installing local build tools"
if [ ! -f "$runner_dir/package.json" ]; then
  npm --prefix "$runner_dir" init -y >/dev/null
fi
npm --prefix "$runner_dir" install --save-exact @electron/asar @electron/rebuild >/dev/null

staging="$work/app"
log "extracting app.asar"
"$runner_dir/node_modules/.bin/asar" extract "$resources_dir/app.asar" "$staging"

app_version="$(node -e "const fs=require('fs');const p='$staging/package.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));process.stdout.write(j.version||'unknown')")"
safe_version="$(printf '%s' "$app_version" | tr -c 'A-Za-z0-9._-' '-')"
electron_version="$(infer_electron_version "$staging")"
[ -n "$electron_version" ] || fail "could not infer Electron version"
log "app version $app_version; Electron $electron_version"

log "installing matching Electron runtime"
npm --prefix "$runner_dir" install --save-exact "electron@$electron_version" @electron/asar @electron/rebuild >/dev/null
electron_dist="$(resolve_electron_dist "$runner_dir")"
[ -x "$electron_dist/electron" ] || fail "could not resolve Electron binary in $electron_dist"

log "installing and rebuilding Linux native modules"
if [ ! -f "$native_dir/package.json" ]; then
  npm --prefix "$native_dir" init -y >/dev/null
fi
npm --prefix "$native_dir" install "better-sqlite3@^12.9.0" "node-pty@^1.1.0" >/dev/null
"$runner_dir/node_modules/.bin/electron-rebuild" -v "$electron_version" -m "$native_dir" -f -w better-sqlite3 -w node-pty

rm -rf "$staging/node_modules/better-sqlite3" "$staging/node_modules/node-pty"
mkdir -p "$staging/node_modules"
cp -a "$native_dir/node_modules/better-sqlite3" "$staging/node_modules/"
cp -a "$native_dir/node_modules/node-pty" "$staging/node_modules/"

log "applying Linux compatibility patches"
node "$repo_root/scripts/patch-main.js" "$staging"

app_root="$install_root/linux-port-$safe_version"
log "assembling local app in $app_root"
rm -rf "$app_root"
mkdir -p "$app_root"
rsync -a "$electron_dist/" "$app_root/"
rm -rf "$app_root/resources"
cp -a "$resources_dir" "$app_root/resources"

if [ -f "$app_root/electron" ]; then
  mv "$app_root/electron" "$app_root/codex-electron"
  ln -s codex-electron "$app_root/electron"
fi

log "installing Linux Browser Use node_repl shim"
cua_bin="$app_root/resources/cua_node/bin"
if [ -d "$cua_bin" ]; then
  if [ -f "$cua_bin/node_repl" ] && [ ! -f "$cua_bin/node_repl.macho-darwin-x64" ]; then
    mv "$cua_bin/node_repl" "$cua_bin/node_repl.macho-darwin-x64"
  fi
  install -m 0755 "$repo_root/scripts/linux-node-repl-shim.cjs" "$cua_bin/node_repl_linux_mcp.cjs"
  cat > "$cua_bin/node_repl" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NODE_BIN="${NODE_REPL_NODE_PATH:-${CODEX_BROWSER_USE_NODE_PATH:-$(command -v node)}}"
exec "$NODE_BIN" "$SCRIPT_DIR/node_repl_linux_mcp.cjs" "$@"
WRAPPER
  chmod 0755 "$cua_bin/node_repl"
else
  log "warning: Browser Use node_repl directory not found; skipping shim"
fi

log "repacking app.asar"
"$runner_dir/node_modules/.bin/asar" pack "$staging" "$app_root/resources/app.asar"

browser_node="$(command -v node)"
codex_bin="$(command -v codex || true)"
if [ -z "$codex_bin" ]; then
  log "warning: codex CLI not found on PATH; install @openai/codex before launching"
fi

launcher="$bin_dir/codex-desktop-linux"
log "writing launcher $launcher"
write_launcher "$launcher" "$app_root" "$install_root/logs" "$browser_node" "$codex_bin"

desktop_file="$applications_dir/codex-app-linux.desktop"
icon_path="$app_root/resources/icon.png"
[ -f "$icon_path" ] || icon_path="$app_root/resources/icon-codex-dark-color.png"
log "writing desktop entry $desktop_file"
write_desktop_entry "$desktop_file" "$launcher" "$icon_path"

if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default codex-app-linux.desktop x-scheme-handler/codex || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" || true
fi

if [ "$install_service" -eq 1 ]; then
  service_file="$service_dir/codex-app-linux.service"
  log "writing user service $service_file"
  write_service "$service_file" "$launcher"
fi

log "done"
log "launch with: $launcher"
