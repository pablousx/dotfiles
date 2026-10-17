#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"
# shellcheck source=setup/mise-lib.sh
source "$REPO_ROOT/setup/mise-lib.sh"
require_action "${1:-}"
[[ "$#" -eq 1 ]] || die 'usage: setup/tools.sh install|skip'
if [[ "$1" == skip ]]; then
    log 'Skipping mise tools.'
    exit 0
fi

VERSION=2026.10.11
case "$(uname -s):$(uname -m)" in
    Darwin:arm64|Darwin:aarch64) target=macos-arm64; checksum=62e86e51f834899610e9bd0ee37580cfe01fac5fff03002318e714fbdb86faeb ;;
    Darwin:x86_64|Darwin:amd64) target=macos-x64; checksum=7e4328b82d9f8a785500c5624bc7bf36afec9bd9a5fadeca089a51c824f030b5 ;;
    Linux:aarch64|Linux:arm64) target=linux-arm64; checksum=370b4b4cfd740402e9a55aa1a8a01fbb1ac95c50af1207b2db2c5489dd4da0cd ;;
    Linux:x86_64|Linux:amd64) target=linux-x64; checksum=f9612efcddda0ae55b62d3b6f82a6c860d5b54ebee0807d4f1a1d578055e1607 ;;
    *) die "mise tools do not support $(uname -s)/$(uname -m)" ;;
esac

fragment="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/conf.d/dotfiles.toml"
manifest="$REPO_ROOT/tools/mise.toml"
[[ "$fragment" == /* ]] || die 'mise configuration directory must be absolute'
# Check ownership before downloading or installing anything.
if [[ -e "$fragment" || -L "$fragment" ]]; then
    [[ -L "$fragment" && "$(readlink "$fragment")" == "$manifest" ]] ||
        die "mise configuration conflict: $fragment; left unchanged"
fi
temporary="$(mktemp -d)"
staged=""
trap 'rm -rf "$temporary"; [[ -z "$staged" ]] || rm -f "$staged"' EXIT
MISE_BIN="$(find_mise 2>/dev/null)" || MISE_BIN=""
if [[ -z "$MISE_BIN" ]]; then
    destination="$HOME/.local/bin/mise"
    [[ ! -e "$destination" && ! -L "$destination" ]] || die "mise destination conflict: $destination"
    command -v curl >/dev/null 2>&1 || die 'curl is required; install core dependencies first'
    curl --fail --silent --show-error --location \
        "https://github.com/jdx/mise/releases/download/v$VERSION/mise-v$VERSION-$target" \
        --output "$temporary/mise"
    [[ "$(sha256_file "$temporary/mise")" == "$checksum" ]] || die 'mise SHA-256 mismatch'
    chmod 0755 "$temporary/mise"
    [[ "$("$temporary/mise" --version)" == "$VERSION "* ]] || die 'unexpected mise version'
    mkdir -p "$HOME/.local/bin"
    staged="$(mktemp "$HOME/.local/bin/.mise.XXXXXX")"
    cp "$temporary/mise" "$staged"
    chmod 0755 "$staged"
    mv "$staged" "$destination"
    staged=""
    MISE_BIN="$destination"
fi

installed_version="$("$MISE_BIN" --version)"
installed_version="${installed_version%% *}"
if ! awk -v actual="$installed_version" -v minimum="$VERSION" 'BEGIN {
    if (actual !~ /^[0-9]+\.[0-9]+\.[0-9]+$/) exit 1
    split(actual, a, "."); split(minimum, b, ".")
    for (i = 1; i <= 3; i++) { if (a[i]+0 > b[i]+0) exit 0; if (a[i]+0 < b[i]+0) exit 1 }
}' ; then
    die "mise $VERSION or newer is required; found $installed_version at $MISE_BIN"
fi
log 'Installing pinned mise tools...'
dotfiles_mise --yes --locked install
mkdir -p "$(dirname "$fragment")"
[[ -L "$fragment" ]] || ln -s "$manifest" "$fragment"
log "Mise tools configured through $fragment. Open a new shell session."
