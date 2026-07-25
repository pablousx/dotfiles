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
                $1 == key && ($2 == "true" || $2 == "false") { value = $2 }
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

detect_package_manager() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf '%s\n' "brew"
        return
    fi

    local manager
    for manager in apt-get dnf pacman zypper; do
        if command -v "$manager" >/dev/null 2>&1; then
            printf '%s\n' "$manager"
            return
        fi
    done

    die "unsupported platform: install zsh, git, curl, nano, unzip, and fzf manually."
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
