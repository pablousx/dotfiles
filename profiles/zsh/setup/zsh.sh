#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"

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

plugins_tmp="$DOTFILES_DIR/profiles/zsh/modules/plugins.zsh.tmp"
trap 'rm -f "$plugins_tmp"' EXIT
ZSH_CACHE_DIR="$ZSH_CACHE_DIR" zsh -dfc \
    'source "$1"; antidote bundle < "$2"' _ \
    "$DOTFILES_DIR/.antidote/antidote.zsh" \
    "$DOTFILES_DIR/profiles/zsh/modules/plugins.txt" > "$plugins_tmp"
mv "$plugins_tmp" "$DOTFILES_DIR/profiles/zsh/modules/plugins.zsh"
trap - EXIT

if [[ ! -f "$DOTFILES_DIR/.env" ]]; then
    cp "$DOTFILES_DIR/.env.example" "$DOTFILES_DIR/.env"
fi

log "Zsh configuration is installed."
