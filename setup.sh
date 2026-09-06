#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"

# Select the profile before parsing its component and module options.
PROFILE=auto
profile_explicit=false
profile_args=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --profile)
            [[ "$#" -ge 2 ]] || die "--profile requires auto, zsh, or omarchy"
            [[ "$profile_explicit" == false ]] || die "--profile may only be supplied once"
            PROFILE="$2"; profile_explicit=true; shift 2 ;;
        *) profile_args+=("$1"); shift ;;
    esac
done
case "$PROFILE" in auto|zsh|omarchy) ;; *) die "unknown profile: $PROFILE" ;; esac
help_requested=false
for option in ${profile_args[@]+"${profile_args[@]}"}; do
    case "$option" in --help|-h) help_requested=true ;; esac
done
if [[ "$help_requested" == true ]]; then
    # Prefer matching help, but keep general help available on unsupported hosts.
    if [[ "$PROFILE" == auto ]]; then
        if detected_help_profile="$(detect_platform && printf '%s\n' "$DETECTED_PROFILE")" 2>/dev/null; then
            PROFILE="$detected_help_profile"
        else
            PROFILE=zsh
        fi
    fi
else
    detect_platform
    [[ "$PROFILE" != auto ]] || PROFILE="$DETECTED_PROFILE"
    require_profile_platform "$PROFILE"
    log "Detected distribution: $DETECTED_DISTRO; profile: $PROFILE"
fi
exec bash "$REPO_ROOT/profiles/$PROFILE/setup.sh" ${profile_args[@]+"${profile_args[@]}"}
