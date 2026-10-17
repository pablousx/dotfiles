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
# shellcheck source=setup/mise-lib.sh
source "$REPO_ROOT/setup/mise-lib.sh"
MISE_BIN="$(find_mise)"
# Resolve absolute paths before Rulesync gets its isolated temporary HOME.
python="$(dotfiles_mise which python3)" || die 'Python is missing; run ./setup.sh --tools'
rulesync="$(dotfiles_mise which rulesync)" || die 'Rulesync is missing; run ./setup.sh --tools'
exec "$python" "$REPO_ROOT/scripts/sync-ai.py" "$rulesync" ${1+"$1"}
