#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"

prompt_option() {
    local prompt_text="$1"
    local default_val="$2"
    local user_input

    while true; do
        read -r -p "$prompt_text (yes [y], no [n]) [$default_val]: " user_input
        user_input="$(printf '%s' "$user_input" | tr '[:upper:]' '[:lower:]')"
        [[ -n "$user_input" ]] || user_input="$default_val"

        case "$user_input" in
            y|yes) printf '%s\n' "install"; return 0 ;;
            n|no) printf '%s\n' "skip"; return 0 ;;
            *) printf '%s\n' "Invalid option. Please use 'y' or 'n'." >&2 ;;
        esac
    done
}

prompt_module() {
    local prompt_text="$1"
    local current_disabled="$2"
    local default_answer="yes"
    local user_input

    [[ "$current_disabled" == true ]] && default_answer="no"

    while true; do
        read -r -p "$prompt_text (yes [y], no [n]) [$default_answer]: " user_input
        user_input="$(printf '%s' "$user_input" | tr '[:upper:]' '[:lower:]')"
        [[ -n "$user_input" ]] || user_input="$default_answer"

        case "$user_input" in
            y|yes) printf '%s\n' "false"; return 0 ;;
            n|no) printf '%s\n' "true"; return 0 ;;
            *) printf '%s\n' "Invalid option. Please use 'y' or 'n'." >&2 ;;
        esac
    done
}

configure_modules_interactively() {
    printf '\n%s\n' "Module configuration:"
    DISABLE_ALIASES_VALUE="$(prompt_module "  Enable aliases and helper functions?" "$DISABLE_ALIASES_VALUE")"
    DISABLE_PROMPT_VALUE="$(prompt_module "  Enable the Powerlevel10k prompt?" "$DISABLE_PROMPT_VALUE")"
    DISABLE_PLUGINS_VALUE="$(prompt_module "  Enable Antidote plugins?" "$DISABLE_PLUGINS_VALUE")"
    DISABLE_PRINT_ALIAS_COMPLETION_VALUE="$(
        prompt_module "  Show alias expansion hints before execution?" "$DISABLE_PRINT_ALIAS_COMPLETION_VALUE"
    )"
    DISABLE_EXPAND_ALIAS_VALUE="$(prompt_module "  Expand aliases when accepting a command?" "$DISABLE_EXPAND_ALIAS_VALUE")"
    MODULE_ACTION="write"
}

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--all | COMPONENT...]

Components:
  --core       Install core command-line dependencies
  --fnm        Install FNM and the configured Node.js version
  --zsh        Configure Zsh and plugins
  --all        Install every component without prompting
  --configure-modules
               Prompt for all module settings
  --help       Show this help

Module flags:
  --enable-aliases | --disable-aliases
  --enable-prompt | --disable-prompt
  --enable-plugins | --disable-plugins
  --enable-print-alias-completion | --disable-print-alias-completion
  --enable-expand-alias | --disable-expand-alias

Module flags persist these values in .env:
  DISABLE_ALIASES, DISABLE_PROMPT, DISABLE_PLUGINS,
  DISABLE_PRINT_ALIAS_COMPLETION, DISABLE_EXPAND_ALIAS

With no arguments, setup runs interactively. Declining a component leaves the
existing installation untouched.
EOF
}

OPT_CORE="skip"
OPT_FNM="skip"
OPT_ZSH="skip"
MODULE_ACTION="skip"

DISABLE_ALIASES_VALUE="$(read_boolean_setting "$REPO_ROOT/.env" DISABLE_ALIASES false)"
DISABLE_PROMPT_VALUE="$(read_boolean_setting "$REPO_ROOT/.env" DISABLE_PROMPT false)"
DISABLE_PLUGINS_VALUE="$(read_boolean_setting "$REPO_ROOT/.env" DISABLE_PLUGINS false)"
DISABLE_PRINT_ALIAS_COMPLETION_VALUE="$(
    read_boolean_setting "$REPO_ROOT/.env" DISABLE_PRINT_ALIAS_COMPLETION false
)"
DISABLE_EXPAND_ALIAS_VALUE="$(read_boolean_setting "$REPO_ROOT/.env" DISABLE_EXPAND_ALIAS false)"
PROMPT_MODULES=false

if [[ "$#" -gt 0 ]]; then
    for option in "$@"; do
        case "$option" in
            --all)
                OPT_CORE="install"
                OPT_FNM="install"
                OPT_ZSH="install"
                ;;
            --core) OPT_CORE="install" ;;
            --fnm) OPT_FNM="install" ;;
            --zsh) OPT_ZSH="install" ;;
            --configure-modules) PROMPT_MODULES=true ;;
            --enable-aliases) DISABLE_ALIASES_VALUE=false; MODULE_ACTION="write" ;;
            --disable-aliases) DISABLE_ALIASES_VALUE=true; MODULE_ACTION="write" ;;
            --enable-prompt) DISABLE_PROMPT_VALUE=false; MODULE_ACTION="write" ;;
            --disable-prompt) DISABLE_PROMPT_VALUE=true; MODULE_ACTION="write" ;;
            --enable-plugins) DISABLE_PLUGINS_VALUE=false; MODULE_ACTION="write" ;;
            --disable-plugins) DISABLE_PLUGINS_VALUE=true; MODULE_ACTION="write" ;;
            --enable-print-alias-completion)
                DISABLE_PRINT_ALIAS_COMPLETION_VALUE=false
                MODULE_ACTION="write"
                ;;
            --disable-print-alias-completion)
                DISABLE_PRINT_ALIAS_COMPLETION_VALUE=true
                MODULE_ACTION="write"
                ;;
            --enable-expand-alias) DISABLE_EXPAND_ALIAS_VALUE=false; MODULE_ACTION="write" ;;
            --disable-expand-alias) DISABLE_EXPAND_ALIAS_VALUE=true; MODULE_ACTION="write" ;;
            --help|-h) usage; exit 0 ;;
            *) die "unknown option: $option (run ./setup.sh --help)" ;;
        esac
    done
    [[ "$PROMPT_MODULES" == false ]] || configure_modules_interactively
else
    printf '%s\n' "========================================"
    printf '%s\n' "  Dotfiles Interactive Setup"
    printf '%s\n\n' "========================================"

    OPT_CORE="$(prompt_option "1. Install core dependencies (zsh, git, curl, fzf, etc.)?" "yes")"
    OPT_FNM="$(prompt_option "2. Install FNM and Node.js?" "yes")"
    OPT_ZSH="$(prompt_option "3. Configure the Zsh environment and plugins?" "yes")"
    configure_modules_interactively

    printf '\n%s\n' "========================================"
    printf '%-24s %s\n' "Core dependencies:" "$OPT_CORE"
    printf '%-24s %s\n' "FNM and Node.js:" "$OPT_FNM"
    printf '%-24s %s\n' "Zsh environment:" "$OPT_ZSH"
    printf '%-24s %s\n' "Aliases enabled:" "$([[ "$DISABLE_ALIASES_VALUE" == false ]] && printf yes || printf no)"
    printf '%-24s %s\n' "Prompt enabled:" "$([[ "$DISABLE_PROMPT_VALUE" == false ]] && printf yes || printf no)"
    printf '%-24s %s\n' "Plugins enabled:" "$([[ "$DISABLE_PLUGINS_VALUE" == false ]] && printf yes || printf no)"
    printf '%-24s %s\n' "Alias hints enabled:" \
        "$([[ "$DISABLE_PRINT_ALIAS_COMPLETION_VALUE" == false ]] && printf yes || printf no)"
    printf '%-24s %s\n' "Alias expansion enabled:" \
        "$([[ "$DISABLE_EXPAND_ALIAS_VALUE" == false ]] && printf yes || printf no)"
    printf '%s\n\n' "========================================"

    read -r -p "Proceed with these settings? (y/n) [y]: " CONFIRM
    CONFIRM="$(printf '%s' "${CONFIRM:-y}" | tr '[:upper:]' '[:lower:]')"
    [[ "$CONFIRM" == "y" || "$CONFIRM" == "yes" ]] || die "setup aborted."
fi

log "Executing setup steps..."
bash "$REPO_ROOT/setup/core.sh" "$OPT_CORE"
bash "$REPO_ROOT/setup/fnm.sh" "$OPT_FNM"
bash "$REPO_ROOT/setup/zsh.sh" "$OPT_ZSH" "$REPO_ROOT"
bash "$REPO_ROOT/setup/modules.sh" \
    "$MODULE_ACTION" \
    "$REPO_ROOT" \
    "$DISABLE_ALIASES_VALUE" \
    "$DISABLE_PROMPT_VALUE" \
    "$DISABLE_PLUGINS_VALUE" \
    "$DISABLE_PRINT_ALIAS_COMPLETION_VALUE" \
    "$DISABLE_EXPAND_ALIAS_VALUE"

printf '\n%s\n' "========================================"
log "Setup complete. Restart your terminal or run: exec zsh"
