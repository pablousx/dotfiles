#!/usr/bin/env bash

# Helper to prompt user
prompt_option() {
    local prompt_text="$1"
    local default_val="$2"
    local user_input

    while true; do
        read -p "$prompt_text (yes [y], no [n], skip [s]) [$default_val]: " user_input
        user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
        [ -z "$user_input" ] && user_input="$default_val"

        case "$user_input" in
            y|yes) echo "yes"; return 0 ;;
            n|no) echo "no"; return 0 ;;
            s|skip) echo "skip"; return 0 ;;
            *) echo "Invalid option. Please use 'y', 'n', or 's'." >&2 ;;
        esac
    done
}

echo "========================================"
echo "  Dotfiles Interactive Setup"
echo "========================================"
echo

OPT_CORE=$(prompt_option "1. Would you like to install core dependencies? (zsh, git, curl, fzf, etc.)" "yes")
OPT_FNM=$(prompt_option "2. Would you like to set up FNM & Node.js?" "yes")
OPT_XXH=$(prompt_option "3. Would you like to set up XXH (Portable Shell)?" "yes")
OPT_ZELLIJ=$(prompt_option "4. Would you like to set up Zellij & Plugins?" "yes")
OPT_ZSH=$(prompt_option "5. Would you like to configure the Zsh Environment & Plugins?" "yes")

echo
echo "========================================"
echo "Final Confirmation:"
echo "  1. Core Dependencies: $OPT_CORE"
echo "  2. FNM & Node.js:     $OPT_FNM"
echo "  3. XXH:               $OPT_XXH"
echo "  4. Zellij & Plugins:  $OPT_ZELLIJ"
echo "  5. Zsh Environment:   $OPT_ZSH"
echo "========================================"
echo

read -p "Proceed with these settings? (y/n) [y]: " CONFIRM
CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
[ -z "$CONFIRM" ] && CONFIRM="y"

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "yes" ]; then
    echo "Setup aborted."
    exit 1
fi

REPO_ROOT=$(realpath "$(dirname "$0")")

# Make scripts executable
chmod +x "$REPO_ROOT/setup/core.sh"
chmod +x "$REPO_ROOT/setup/fnm.sh"
chmod +x "$REPO_ROOT/setup/xxh.sh"
chmod +x "$REPO_ROOT/setup/zellij.sh"
chmod +x "$REPO_ROOT/setup/zsh.sh"

# Execute setups
echo "Executing setup steps..."
bash "$REPO_ROOT/setup/core.sh" "$OPT_CORE"
bash "$REPO_ROOT/setup/fnm.sh" "$OPT_FNM"
bash "$REPO_ROOT/setup/xxh.sh" "$OPT_XXH"
bash "$REPO_ROOT/setup/zellij.sh" "$OPT_ZELLIJ"
bash "$REPO_ROOT/setup/zsh.sh" "$OPT_ZSH"

echo
echo "========================================"
echo "Setup complete! Restart your terminal or run: reload"
