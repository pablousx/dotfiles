#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/lib.sh"

ACTION="${1:-}"
require_action "$ACTION"

if [[ "$ACTION" == "skip" ]]; then
    log "Skipping core dependencies."
    exit 0
fi

manager="$(detect_package_manager)"
log "Installing core dependencies with $manager..."
install_core_packages "$manager"
