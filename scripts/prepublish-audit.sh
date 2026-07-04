#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'audit failed: %s\n' "$*" >&2
  exit 1
}

printf 'checking repository path...\n'
case "$repo_root" in
  "$HOME/Downloads"*|"$HOME/.local/share/codex-mac-port"*|"$HOME/.local/share/codex-app-linux"*|"$HOME/.local/share/codex-app-ubuntu"*)
    fail "repo is inside a sensitive/generated directory: $repo_root"
    ;;
esac

printf 'checking project naming...\n'
if rg -n \
  -g '!scripts/prepublish-audit.sh' \
  -e 'Codex App Ubuntu' \
  -e 'Codex Ubuntu Port' \
  -e 'codex-app-ubuntu\.desktop' \
  -e 'codex-app-ubuntu\.service' \
  -e 'github\.com/antonlobanovskiy/codex-app-ubuntu' \
  README.md docs scripts .github >/tmp/codex-app-linux-audit-naming 2>/dev/null; then
  cat /tmp/codex-app-linux-audit-naming >&2
  fail "Ubuntu-specific public project naming remains"
fi

printf 'checking for blocked generated paths...\n'
blocked_path_regex='(^|/)(app-unpacked|app-linux[^/]*|linux-port[^/]*|native-linux[^/]*|runner[^/]*|user-data[^/]*|logs|screenshots|backups|tmp|dist|build|out|node_modules|\.codex)(/|$)'
if git ls-files -co --exclude-standard | LC_ALL=C grep -E "$blocked_path_regex" >/tmp/codex-app-linux-audit-paths 2>/dev/null; then
  cat /tmp/codex-app-linux-audit-paths >&2
  fail "blocked generated path present"
fi

printf 'checking for blocked file names and extensions...\n'
blocked_file_regex='(^|/)(auth\.json|hosts\.yml|client_secret.*\.json|.*secret.*|.*\.dmg|.*\.asar|.*\.app|.*\.node|.*\.so|.*\.dylib|.*\.dll|.*\.exe|.*\.icns|.*\.png|.*\.jpe?g|.*\.webp|.*\.xwd|.*\.pnm|.*\.pem|.*\.key|.*\.p12|.*\.pfx|id_rsa.*|id_ed25519.*)$'
if git ls-files -co --exclude-standard | LC_ALL=C grep -Ei "$blocked_file_regex" >/tmp/codex-app-linux-audit-files 2>/dev/null; then
  cat /tmp/codex-app-linux-audit-files >&2
  fail "blocked file present"
fi

printf 'checking for large files...\n'
while IFS= read -r file; do
  [ -f "$file" ] || continue
  size="$(wc -c < "$file")"
  if [ "$size" -gt 1048576 ]; then
    printf '%s %s bytes\n' "$file" "$size" >&2
    fail "file larger than 1 MiB"
  fi
done < <(git ls-files -co --exclude-standard)

printf 'checking token-like content...\n'
if rg -n --hidden --no-ignore-vcs \
  -g '!node_modules/**' \
  -g '!dist/**' \
  -g '!build/**' \
  -g '!out/**' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e 'gh[pousr]_[A-Za-z0-9_]{20,}' \
  -e 'github_pat_[A-Za-z0-9_]{20,}' \
  -e 'xox[baprs]-[A-Za-z0-9-]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e '-----BEGIN (RSA |OPENSSH |EC |DSA |)PRIVATE KEY-----' \
  -e '(access_token|refresh_token|id_token|OPENAI_API_KEY|CODEX_ACCESS_TOKEN)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9._~+/=-]{12,}' \
  . >/tmp/codex-app-linux-audit-secrets 2>/dev/null; then
  cat /tmp/codex-app-linux-audit-secrets >&2
  fail "token-like content found"
fi

printf 'checking scripts parse...\n'
bash -n scripts/install.sh
bash -n scripts/prepublish-audit.sh
node --check scripts/patch-main.js >/dev/null
node --check scripts/linux-node-repl-shim.cjs >/dev/null

if command -v gitleaks >/dev/null 2>&1; then
  printf 'running gitleaks...\n'
  gitleaks detect --no-git --source "$repo_root"
else
  printf 'gitleaks not installed; built-in audit completed.\n'
fi

printf 'audit passed.\n'
