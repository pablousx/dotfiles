#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/lib.sh"

ACTION="${1:-}"
NODE_VERSION="${NODE_VERSION:-24.12.0}"
FNM_VERSION="${FNM_VERSION:-1.39.0}"
FNM_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"

require_action "$ACTION"

if [[ "$ACTION" == "skip" ]]; then
    log "Skipping FNM and Node.js."
    exit 0
fi

case "$(uname -s):$(uname -m)" in
    Darwin:*)
        asset="fnm-macos.zip"
        expected_sha256="f046483e85c53b3278efe49a3620c8680f22efa58a8dabfd03eafc6b59b31a25"
        ;;
    Linux:x86_64|Linux:amd64)
        asset="fnm-linux.zip"
        expected_sha256="7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224"
        ;;
    Linux:aarch64|Linux:arm64)
        asset="fnm-arm64.zip"
        expected_sha256="4eaff58b2c5bf30d0934027572dd0b5bbb60d2a1af309230b53662d4b1d45599"
        ;;
    Linux:armv7l|Linux:armv6l)
        asset="fnm-arm32.zip"
        expected_sha256="3d11d96a49d49cb3f11051a1aabf968fce30db665e79ee7d81851059731fa4ac"
        ;;
    *)
        die "FNM $FNM_VERSION has no configured artifact for $(uname -s)/$(uname -m)."
        ;;
esac

installed_version=""
if [[ -x "$FNM_DIR/fnm" ]]; then
    installed_version="$("$FNM_DIR/fnm" --version 2>/dev/null || true)"
fi

if [[ "$installed_version" != "fnm $FNM_VERSION" ]]; then
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' EXIT
    archive="$temp_dir/$asset"
    url="https://github.com/Schniz/fnm/releases/download/v$FNM_VERSION/$asset"

    log "Downloading and verifying FNM $FNM_VERSION..."
    curl --fail --silent --show-error --location "$url" --output "$archive"
    actual_sha256="$(sha256_file "$archive")"
    [[ "$actual_sha256" == "$expected_sha256" ]] ||
        die "FNM checksum mismatch: expected $expected_sha256, got $actual_sha256"

    mkdir -p "$FNM_DIR"
    unzip -oq "$archive" -d "$FNM_DIR"
    chmod 0755 "$FNM_DIR/fnm"
    printf '%s\n' "$FNM_VERSION" > "$FNM_DIR/.installed-by-dotfiles"
    trap - EXIT
    rm -rf "$temp_dir"
fi

export PATH="$FNM_DIR:$PATH"
eval "$(fnm env --shell bash)"
log "Installing Node.js $NODE_VERSION..."
fnm install "$NODE_VERSION"
fnm default "$NODE_VERSION"
