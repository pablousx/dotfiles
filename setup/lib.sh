#!/usr/bin/env bash

set -Eeuo pipefail

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_action() {
    case "${1:-}" in
        install|skip) ;;
        *) die "expected action 'install' or 'skip', got '${1:-<empty>}'." ;;
    esac
}

require_boolean() {
    case "${1:-}" in
        true|false) ;;
        *) die "expected boolean 'true' or 'false', got '${1:-<empty>}'." ;;
    esac
}

read_boolean_setting() {
    local env_file="$1"
    local key="$2"
    local default_value="$3"
    local value=""

    require_boolean "$default_value"
    if [[ -r "$env_file" ]]; then
        value="$(
            awk -F= -v key="$key" '
                NF == 2 && $1 == key && ($2 == "true" || $2 == "false") { value = $2 }
                END { print value }
            ' "$env_file"
        )"
    fi

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$default_value"
    fi
}

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "sudo is required to install system packages."
    fi
}

# Separate host reads from classification so tests can supply isolated fixtures.
platform_kernel() {
    uname -s
}

platform_release_file() {
    if [[ -r /etc/os-release ]]; then
        printf '%s\n' /etc/os-release
    elif [[ -r /usr/lib/os-release ]]; then
        printf '%s\n' /usr/lib/os-release
    else
        die 'cannot detect Linux distribution: no readable os-release file'
    fi
}

read_os_release_field() {
    local file="$1" field="$2" key value result=""
    [[ -r "$file" ]] || die "cannot read distribution metadata: $file"
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" == "$field" ]] || continue
        value="${value%$'\r'}"
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
        esac
        result="$value"
    done < "$file"
    case "$field" in
        ID) [[ "$result" =~ ^[a-z0-9._-]+$ ]] || die "missing or invalid ID in $file" ;;
        ID_LIKE) [[ "$result" =~ ^[a-z0-9._[:space:]-]*$ ]] || die "invalid ID_LIKE in $file" ;;
        *) die "unsupported os-release field: $field" ;;
    esac
    printf '%s\n' "$result"
}

# Optional arguments are for read-only classification of fixtures/images.
# Normal setup always reads the running host; environment variables cannot
# substitute arbitrary distro metadata.
detect_platform() {
    local kernel="${1:-$(platform_kernel)}" release_file="${2:-}" id like candidate
    local -a candidates
    DETECTED_DISTRO=""
    DETECTED_MANAGER=""
    DETECTED_PROFILE=zsh
    case "$kernel" in
        Darwin)
            DETECTED_DISTRO=macos
            DETECTED_MANAGER=brew
            return ;;
        Linux) ;;
        *) die "unsupported operating system: $kernel (supported: macOS and compatible Linux distributions)" ;;
    esac
    [[ -n "$release_file" ]] || release_file="$(platform_release_file)" || return
    id="$(read_os_release_field "$release_file" ID)" || return
    like="$(read_os_release_field "$release_file" ID_LIKE)" || return
    read -r -a candidates <<< "$id $like"
    for candidate in "${candidates[@]}"; do
        case "$candidate" in
            omarchy|arch|archlinux) DETECTED_MANAGER=pacman ;;
            ubuntu|debian) DETECTED_MANAGER=apt-get ;;
            fedora|rhel|centos|rocky|almalinux) DETECTED_MANAGER=dnf ;;
            opensuse|opensuse-leap|opensuse-tumbleweed|suse|sles|sled) DETECTED_MANAGER=zypper ;;
            *) continue ;;
        esac
        break
    done
    [[ -n "$DETECTED_MANAGER" ]] ||
        die "unsupported Linux distribution: $id (ID_LIKE: ${like:-none}); supported families: Debian/Ubuntu, Fedora/RHEL, Arch/Omarchy, openSUSE/SUSE"
    DETECTED_DISTRO="$id"
    # New Omarchy releases identify themselves; older installs identify as Arch.
    if [[ "$id" == omarchy || ( "$DETECTED_MANAGER" == pacman &&
        -r "${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/rc" ) ]]; then
        DETECTED_DISTRO=omarchy
        DETECTED_PROFILE=omarchy
    fi
}

require_profile_platform() {
    case "$1" in
        zsh) ;; # Every detected platform supports the portable Zsh profile.
        omarchy)
            [[ "$DETECTED_PROFILE" == omarchy ]] ||
                die "profile omarchy is incompatible with $DETECTED_DISTRO; use --profile zsh" ;;
        *) die "unknown profile: $1" ;;
    esac
}

detect_package_manager() {
    detect_platform || return
    command -v "$DETECTED_MANAGER" >/dev/null 2>&1 ||
        die "$DETECTED_MANAGER is required for $DETECTED_DISTRO; no alternate package manager will be used"
    printf '%s\n' "$DETECTED_MANAGER"
}

install_core_packages() {
    local manager="$1"

    case "$manager" in
        brew)
            command -v brew >/dev/null 2>&1 ||
                die "Homebrew is required on macOS. Install it from https://brew.sh and rerun setup."
            brew install zsh git curl nano unzip fzf python
            ;;
        apt-get)
            run_as_root apt-get update
            run_as_root apt-get install -y zsh git curl nano unzip fzf ca-certificates python3 python3-venv
            ;;
        dnf)
            run_as_root dnf install -y zsh git curl nano unzip fzf ca-certificates python3
            ;;
        pacman)
            run_as_root pacman -Sy --needed --noconfirm zsh git curl nano unzip fzf ca-certificates python
            ;;
        zypper)
            run_as_root zypper --non-interactive install zsh git curl nano unzip fzf ca-certificates python3
            ;;
        *)
            die "unsupported package manager: $manager"
            ;;
    esac
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        die "sha256sum or shasum is required to verify downloads."
    fi
}
