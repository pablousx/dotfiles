#!/usr/bin/env bash
set -Eeuo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SETUP_DIR/../../.." && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"

usage() {
    cat <<'HELP'
Usage: ./setup.sh --profile omarchy [OPTIONS]
No options: interactive components, module settings, summary and confirmation.
  --core                 Install Bash helper dependencies through omarchy pkg add
  --bash                 Add the guarded Bash startup block
  --all                  Select all shell components
  --keyboard             Install the saved Spanish AltGr keyboard layout
  --save-keyboard        Save the current us-altgr-spanish keymap to this repository
  --brightness-knob      Make brightness keys adjust every active display by 10%
  --configure-modules    Prompt for profile settings
  --enable-aliases | --disable-aliases
  --enable-prompt | --disable-prompt   Use the custom Starship prompt / keep the current prompt
  --enable-completions | --disable-completions
  --enable-history-sync | --disable-history-sync
Settings: .env.omarchy; DISABLE_ALIASES, DISABLE_PROMPT,
DISABLE_COMPLETIONS, DISABLE_HISTORY_SYNC. Only true/false are valid.
HELP
}
choose() {
    local question="$1" default="$2" answer
    while true; do
        read -r -p "$question (yes/no) [$default]: " answer || return 1
        case "${answer:-$default}" in
            [Yy]|[Yy][Ee][Ss]) printf false; return ;;
            [Nn]|[Nn][Oo]) printf true; return ;;
            *) printf '%s\n' 'Choose yes or no.' >&2 ;;
        esac
    done
}
choose_keyboard() {
    local answer
    printf '%s\n' '' 'Keyboard configuration:' \
        '  1) None (leave unchanged)' \
        '  2) US with Spanish AltGr (us-altgr-spanish)' >&2
    while true; do
        read -r -p 'Keyboard configuration [None]: ' answer || return 1
        case "${answer:-None}" in
            1|[Nn][Oo][Nn][Ee]) printf skip; return ;;
            2|us-altgr-spanish) printf install; return ;;
            *) printf '%s\n' 'Choose 1 (None) or 2 (US with Spanish AltGr).' >&2 ;;
        esac
    done
}
keys=(DISABLE_ALIASES DISABLE_PROMPT DISABLE_COMPLETIONS DISABLE_HISTORY_SYNC)
values=()
for key in "${keys[@]}"; do
    values+=("$(read_boolean_setting "$REPO_ROOT/.env.omarchy" "$key" false)")
done
core=skip
startup=skip
keyboard=skip
brightness_knob=skip
write=false
interactive=false
prompt_modules=false
[[ "$#" -ne 0 ]] || interactive=true
for option in "$@"; do
    case "$option" in
        --help|-h) usage; exit 0 ;;
        --core) core=install ;;
        --bash) startup=install ;;
        --all) core=install; startup=install ;;
        --keyboard)
            [[ "$keyboard" != save ]] || die '--keyboard and --save-keyboard cannot be combined'
            keyboard=install ;;
        --save-keyboard)
            [[ "$keyboard" != install ]] || die '--keyboard and --save-keyboard cannot be combined'
            keyboard=save ;;
        --brightness-knob) brightness_knob=install ;;
        --configure-modules) prompt_modules=true ;;
        --enable-aliases) values[0]=false; write=true ;;
        --disable-aliases) values[0]=true; write=true ;;
        --enable-prompt) values[1]=false; write=true ;;
        --disable-prompt) values[1]=true; write=true ;;
        --enable-completions) values[2]=false; write=true ;;
        --disable-completions) values[2]=true; write=true ;;
        --enable-history-sync) values[3]=false; write=true ;;
        --disable-history-sync) values[3]=true; write=true ;;
        *) die "unsupported Omarchy option: $option (see --profile omarchy --help)" ;;
    esac
done
detect_platform
require_profile_platform omarchy

if [[ "$interactive" == true ]]; then
    choice="$(choose 'Install helper dependencies?' no)" || die 'setup input ended'
    [[ "$choice" == true ]] || core=install
    choice="$(choose 'Configure Bash startup?' yes)" || die 'setup input ended'
    [[ "$choice" == true ]] || startup=install
    keyboard="$(choose_keyboard)" || die 'setup input ended'
    choice="$(choose 'Configure brightness keys for 10% changes on every active display?' no)" ||
        die 'setup input ended'
    [[ "$choice" == true ]] || brightness_knob=install
    prompt_modules=true
fi
if [[ "$prompt_modules" == true ]]; then
    labels=('Enable aliases and helpers? (no disables them)' 'Use the custom Starship prompt? (no keeps the current prompt)' 'Enable additional completions? (no disables additions)' 'Enable Bash history synchronization? (no disables it)')
    for i in 0 1 2 3; do
        default=yes
        [[ "${values[$i]}" != true ]] || default=no
        values[i]="$(choose "${labels[$i]}" "$default")"
    done
    write=true
fi
if [[ "$interactive" == true || "$prompt_modules" == true ]]; then
    case "$keyboard" in
        skip) keyboard_label='None (leave unchanged)' ;;
        install) keyboard_label='US with Spanish AltGr (us-altgr-spanish)' ;;
        save) keyboard_label='Save current us-altgr-spanish layout' ;;
    esac
    printf 'Omarchy profile: dependencies=%s, Bash startup=%s\n' "$core" "$startup"
    printf 'Keyboard configuration: %s\n' "$keyboard_label"
    printf 'All-monitor brightness knob: %s\n' "$brightness_knob"
    for i in 0 1 2 3; do printf '%s=%s\n' "${keys[$i]}" "${values[$i]}"; done
    [[ "$(choose 'Apply these settings?' yes)" == false ]] || die 'setup aborted'
fi
if [[ "$core" == install ]]; then
    command -v omarchy >/dev/null 2>&1 || die 'omarchy is required for --core'
    omarchy pkg add git curl python bash-completion unzip wl-clipboard
fi
bash "$SETUP_DIR/bash-startup.sh" "$startup" "$REPO_ROOT"
bash "$SETUP_DIR/keyboard.sh" "$keyboard"
bash "$SETUP_DIR/brightness-knob.sh" "$brightness_knob" "$REPO_ROOT"
if [[ "$write" == true ]]; then
    generated="$(mktemp "$REPO_ROOT/.env.omarchy.tmp.XXXXXX")"
    trap 'rm -f "$generated"' EXIT
    for i in 0 1 2 3; do
        require_boolean "${values[$i]}"
        printf '%s=%s\n' "${keys[$i]}" "${values[$i]}"
    done > "$generated"
    chmod 0600 "$generated"
    mv "$generated" "$REPO_ROOT/.env.omarchy"
fi
if [[ "$startup" == install || "$write" == true ]]; then
    log 'Omarchy profile setup complete. Open a new Bash session or run: exec bash'
else
    log 'Omarchy profile setup complete.'
fi
