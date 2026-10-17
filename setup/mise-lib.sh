#!/usr/bin/env bash
# Shared lookup and isolated config selection; loading this file installs nothing.
find_mise() {
    local binary
    binary="$(type -P mise || true)"
    if [[ -z "$binary" && -x "$HOME/.local/bin/mise" ]]; then
        binary="$HOME/.local/bin/mise"
    fi
    [[ -n "$binary" ]] || die 'mise is required; run ./setup.sh --tools'
    [[ "$binary" == /* ]] || binary="$PWD/$binary"
    printf '%s\n' "$binary"
}

# MISE_GLOBAL_CONFIG_FILE selects the complete tool manifest as a global config. Run
# outside the checkout/home so ancestor project configs cannot add other tools.
dotfiles_mise() (
    local work
    work="$(mktemp -d)" || exit 1
    trap 'rm -rf "$work"' EXIT
    cd "$work" || exit 1
    MISE_GLOBAL_CONFIG_FILE="$REPO_ROOT/tools/mise.toml" \
        MISE_SYSTEM_CONFIG_FILE="$work/system.toml" \
        MISE_ENV='' MISE_AUTO_INSTALL=0 MISE_EXEC_AUTO_INSTALL=0 \
        "$MISE_BIN" "$@"
)
