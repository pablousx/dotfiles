#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"
case "${1:-}" in
    '') [[ "$#" -eq 0 ]] || die 'usage: scripts/sync-ai.sh [--dry-run]' ;;
    --dry-run) [[ "$#" -eq 1 ]] || die 'usage: scripts/sync-ai.sh [--dry-run]' ;;
    *) die 'usage: scripts/sync-ai.sh [--dry-run]' ;;
esac
command -v python3 >/dev/null 2>&1 || die 'python3 is required (install core dependencies first)'
VERSION=37.0.0
case "$(uname -s):$(uname -m)" in
    Darwin:arm64) asset=rulesync-darwin-arm64; checksum=e4df41f311c2f1150c9e8ec0fe5debba16d0c439574ed8525420ae6f81045081 ;;
    Darwin:x86_64) asset=rulesync-darwin-x64; checksum=6cb17bbf95a4d190ce5f1aea94cede54aece4e18851ac0d9b5344210ef484615 ;;
    Linux:aarch64|Linux:arm64) asset=rulesync-linux-arm64; checksum=cdd72b91cc0efd5cd9672ce8e45b57b738648db0627305f3affe3e833e290fe9 ;;
    Linux:x86_64|Linux:amd64) asset=rulesync-linux-x64; checksum=a84bcb2336be9ec0baea826e3b2b195d92d2c4000c1bdabbe87de6e3b92c4f5e ;;
    *) die "Rulesync $VERSION: unsupported OS/architecture" ;;
esac
cache="$REPO_ROOT/.cache/rulesync/$VERSION"
binary="$cache/$asset"
if [[ ! -f "$binary" ]] || [[ "$(sha256_file "$binary")" != "$checksum" ]]; then
    mkdir -p "$cache"
    download="$(mktemp "$cache/download.XXXXXX")"
    trap 'rm -f "$download"' EXIT
    curl --fail --silent --show-error --location \
        "https://github.com/dyoshikawa/rulesync/releases/download/v$VERSION/$asset" --output "$download"
    [[ "$(sha256_file "$download")" == "$checksum" ]] || die 'Rulesync SHA-256 mismatch'
    chmod 0755 "$download"
    mv "$download" "$binary"
    trap - EXIT
fi
exec python3 "$REPO_ROOT/scripts/sync-ai.py" "$binary" ${1+"$1"}
