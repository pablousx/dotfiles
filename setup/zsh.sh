#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/lib.sh"

ACTION="${1:-}"
DOTFILES_DIR="${2:-}"
ANTIDOTE_COMMIT="${ANTIDOTE_COMMIT:-4913257e0ae3fee2a77e7189e526fe55b6ff9536}"

require_action "$ACTION"
[[ -n "$DOTFILES_DIR" ]] || die "repository path was not supplied to zsh setup."
[[ -f "$DOTFILES_DIR/.zshrc" ]] || die ".zshrc not found in $DOTFILES_DIR"

if [[ "$ACTION" == "skip" ]]; then
    log "Skipping Zsh setup."
    exit 0
fi

log "Setting up Zsh and plugins..."

touch "$HOME/.zshrc" "$HOME/.zshenv"
printf -v quoted_dotfiles_dir '%q' "$DOTFILES_DIR"

update_dotfiles_path() {
    local startup_file="$1"
    local generated
    generated="$(mktemp)"
    awk -v assignment="export DOTFILES_DIR=$quoted_dotfiles_dir" '
        /^[[:space:]]*(export[[:space:]]+)?DOTFILES_DIR=/ {
            print assignment
            next
        }
        { print }
    ' "$startup_file" > "$generated"
    mv "$generated" "$startup_file"
}

update_dotfiles_path "$HOME/.zshrc"
update_dotfiles_path "$HOME/.zshenv"

zshrc_source="source \"\$DOTFILES_DIR/.zshrc\""
zshenv_source="source \"\$DOTFILES_DIR/.zshenv\""

if ! grep -Fq "$zshrc_source" "$HOME/.zshrc" &&
    ! grep -Fq "source \$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"; then
    {
        printf '\n%s\n' "# Dotfiles shell configuration"
        printf 'export DOTFILES_DIR=%s\n' "$quoted_dotfiles_dir"
        printf '%s\n' "$zshrc_source"
    } >> "$HOME/.zshrc"
fi

if ! grep -Fq "$zshenv_source" "$HOME/.zshenv" &&
    ! grep -Fq "source \$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"; then
    {
        printf '\n%s\n' "# Dotfiles login-shell configuration"
        printf 'export DOTFILES_DIR=%s\n' "$quoted_dotfiles_dir"
        printf '%s\n' "$zshenv_source"
    } >> "$HOME/.zshenv"
fi
unset -f update_dotfiles_path
unset zshrc_source zshenv_source

zsh_path="$(command -v zsh)"
current_shell="${SHELL:-}"
if command -v getent >/dev/null 2>&1; then
    current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    current_shell="$(dscl . -read "/Users/$(id -un)" UserShell | awk '{print $2}')"
fi
if [[ "$current_shell" != "$zsh_path" ]]; then
    log "Changing the default shell to $zsh_path..."
    chsh -s "$zsh_path"
fi

if [[ ! -d "$DOTFILES_DIR/.antidote/.git" ]]; then
    git clone --filter=blob:none https://github.com/mattmc3/antidote.git "$DOTFILES_DIR/.antidote"
else
    git -C "$DOTFILES_DIR/.antidote" fetch --depth=1 origin "$ANTIDOTE_COMMIT"
fi
git -C "$DOTFILES_DIR/.antidote" checkout --detach "$ANTIDOTE_COMMIT"

ZSH_CACHE_DIR="$DOTFILES_DIR/.cache/zsh"
mkdir -p "$ZSH_CACHE_DIR/completions"

plugins_tmp="$DOTFILES_DIR/modules/plugins.zsh.tmp"
trap 'rm -f "$plugins_tmp"' EXIT
ZSH_CACHE_DIR="$ZSH_CACHE_DIR" zsh -dfc \
    'source "$1"; antidote bundle < "$2"' _ \
    "$DOTFILES_DIR/.antidote/antidote.zsh" \
    "$DOTFILES_DIR/modules/plugins.txt" > "$plugins_tmp"
mv "$plugins_tmp" "$DOTFILES_DIR/modules/plugins.zsh"
trap - EXIT

PNPM_COMPLETION_VERSION="${PNPM_COMPLETION_VERSION:-0.5.5}"
case "$(uname -s):$(uname -m)" in
    Darwin:arm64|Darwin:aarch64)
        pnpm_target="aarch64-apple-darwin"
        pnpm_sha256="852d2922291b460c151352799c4a7f3cb34133c6b094913ec9d904d64d85b83e"
        ;;
    Darwin:x86_64|Darwin:amd64)
        pnpm_target="x86_64-apple-darwin"
        pnpm_sha256="fc93ab7e8410892b29d0f2f4905c89d67a41b9ef86c3c5716370e68b4a207b7e"
        ;;
    Linux:aarch64|Linux:arm64)
        pnpm_target="aarch64-unknown-linux-gnu"
        pnpm_sha256="87fec87f0f52a6bea2344440fd25d2a7498c4a225bcbcbe10fd36186a38a0ba0"
        ;;
    Linux:x86_64|Linux:amd64)
        pnpm_target="x86_64-unknown-linux-gnu"
        pnpm_sha256="eae0a5ab8dc26e296a9735753cfb569e7e2bcd9f29a686294ac6f68871b0e712"
        ;;
    *)
        die "pnpm-shell-completion has no configured artifact for $(uname -s)/$(uname -m)."
        ;;
esac

PNPM_COMPLETION_DIR="${ANTIDOTE_HOME:-$HOME/.cache/antidote}/github.com/g-plane/pnpm-shell-completion"
if [[ -d "$PNPM_COMPLETION_DIR" ]]; then
    pnpm_temp="$(mktemp -d)"
    trap 'rm -rf "$pnpm_temp"' EXIT
    pnpm_archive="$pnpm_temp/pnpm-shell-completion.tar.gz"
    pnpm_url="https://github.com/g-plane/pnpm-shell-completion/releases/download/v$PNPM_COMPLETION_VERSION/pnpm-shell-completion_$pnpm_target.tar.gz"
    curl --fail --silent --show-error --location "$pnpm_url" --output "$pnpm_archive"
    actual_pnpm_sha256="$(sha256_file "$pnpm_archive")"
    [[ "$actual_pnpm_sha256" == "$pnpm_sha256" ]] ||
        die "pnpm-shell-completion checksum mismatch."
    tar -xzf "$pnpm_archive" -C "$pnpm_temp"
    pnpm_binary="$(find "$pnpm_temp" -type f -name pnpm-shell-completion -print -quit)"
    [[ -n "$pnpm_binary" ]] || die "pnpm-shell-completion archive did not contain the expected binary."
    install -m 0755 "$pnpm_binary" "$PNPM_COMPLETION_DIR/pnpm-shell-completion"
    trap - EXIT
    rm -rf "$pnpm_temp"
fi

if [[ ! -f "$DOTFILES_DIR/.env" ]]; then
    cp "$DOTFILES_DIR/.env.example" "$DOTFILES_DIR/.env"
fi

log "Zsh configuration is installed."
