#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"
ACTION="${1:-}"
require_action "$ACTION"
[[ "$#" -le 1 ]] || die 'usage: setup/ai.sh install|skip'
if [[ "$ACTION" == skip ]]; then
    log 'Skipping global AI configuration.'
    exit 0
fi
bash "$REPO_ROOT/scripts/sync-ai.sh"
