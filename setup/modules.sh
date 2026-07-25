#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/lib.sh"

ACTION="${1:-}"
DOTFILES_DIR="${2:-}"
DISABLE_ALIASES_VALUE="${3:-}"
DISABLE_PROMPT_VALUE="${4:-}"
DISABLE_PLUGINS_VALUE="${5:-}"
DISABLE_PRINT_ALIAS_COMPLETION_VALUE="${6:-}"
DISABLE_EXPAND_ALIAS_VALUE="${7:-}"

case "$ACTION" in
    write|skip) ;;
    *) die "expected module action 'write' or 'skip', got '${ACTION:-<empty>}'." ;;
esac

if [[ "$ACTION" == "skip" ]]; then
    log "Keeping the existing module configuration."
    exit 0
fi

[[ -d "$DOTFILES_DIR" ]] || die "repository path was not supplied to module setup."
require_boolean "$DISABLE_ALIASES_VALUE"
require_boolean "$DISABLE_PROMPT_VALUE"
require_boolean "$DISABLE_PLUGINS_VALUE"
require_boolean "$DISABLE_PRINT_ALIAS_COMPLETION_VALUE"
require_boolean "$DISABLE_EXPAND_ALIAS_VALUE"

generated="$(mktemp "$DOTFILES_DIR/.env.tmp.XXXXXX")"
trap 'rm -f "$generated"' EXIT
{
    printf 'DISABLE_ALIASES=%s\n' "$DISABLE_ALIASES_VALUE"
    printf 'DISABLE_PROMPT=%s\n' "$DISABLE_PROMPT_VALUE"
    printf 'DISABLE_PLUGINS=%s\n' "$DISABLE_PLUGINS_VALUE"
    printf 'DISABLE_PRINT_ALIAS_COMPLETION=%s\n' "$DISABLE_PRINT_ALIAS_COMPLETION_VALUE"
    printf 'DISABLE_EXPAND_ALIAS=%s\n' "$DISABLE_EXPAND_ALIAS_VALUE"
} > "$generated"
chmod 0600 "$generated"
mv "$generated" "$DOTFILES_DIR/.env"
trap - EXIT

log "Saved module configuration to $DOTFILES_DIR/.env"
