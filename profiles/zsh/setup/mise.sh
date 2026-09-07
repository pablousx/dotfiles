#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"

ACTION="${1:-}"
require_action "$ACTION"
if [[ "$ACTION" == skip ]]; then
    log "Skipping mise and Node.js."
    exit 0
fi

NODE_VERSION="${NODE_VERSION:-24.12.0}"
[[ "$NODE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "NODE_VERSION must be an exact version (for example, 24.12.0)."
[[ "$HOME" == /* ]] || die "HOME must be an absolute path."
# This version and the hashes below must be updated together.
MISE_VERSION=2026.9.0
mise_bin="$HOME/.local/bin/mise"
marker="$HOME/.local/bin/.mise-installed-by-dotfiles"
export PATH="$HOME/.local/bin:$PATH"

if command -v mise >/dev/null 2>&1; then
    mise_bin="$(command -v mise)"
    log "Using existing mise: $mise_bin"
else
    [[ ! -e "$mise_bin" && ! -L "$mise_bin" ]] ||
        die "Refusing to overwrite an existing non-executable mise: $mise_bin"
    case "$(uname -s):$(uname -m)" in
        Darwin:arm64|Darwin:aarch64)
            target=macos-arm64
            expected_sha256=50eeb4b907fb5fd4ad87a5fec0e55735bb16dfe00c725c9c3dc40852afd55b06 ;;
        Darwin:x86_64)
            target=macos-x64
            expected_sha256=d4c68596addfd102717699243acfb795177dc025e7895bad581317c43fadb4ef ;;
        Linux:x86_64|Linux:amd64)
            target=linux-x64
            expected_sha256=c9b089f2be1db4d4262eacaf367e480e7a328848adcc37d9d1612996902485d0 ;;
        Linux:aarch64|Linux:arm64)
            target=linux-arm64
            expected_sha256=0b5c4586353010378d9caca62c95166588c3dc4e310eb2d276aac1068397faec ;;
        Linux:armv7l)
            target=linux-armv7
            expected_sha256=a8135ddc0034156a8a86d0b5ab995053b57ddf3038879553bfbec8009d19f216 ;;
        *) die "mise $MISE_VERSION has no configured artifact for $(uname -s)/$(uname -m)." ;;
    esac
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' EXIT
    artifact="$temp_dir/mise"
    url="https://github.com/jdx/mise/releases/download/v$MISE_VERSION/mise-v$MISE_VERSION-$target"
    log "Downloading and verifying mise $MISE_VERSION..."
    curl --fail --silent --show-error --location "$url" --output "$artifact"
    actual_sha256="$(sha256_file "$artifact")"
    [[ "$actual_sha256" == "$expected_sha256" ]] ||
        die "mise checksum mismatch: expected $expected_sha256, got $actual_sha256"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$artifact" "$mise_bin"
    printf '%s\n' "$expected_sha256" > "$marker"
fi

# Enable project Node files while preserving enabled tools for other languages.
"$mise_bin" settings add idiomatic_version_file_enable_tools node

log "Installing and selecting Node.js $NODE_VERSION globally with mise..."
"$mise_bin" use --global "node@$NODE_VERSION"
