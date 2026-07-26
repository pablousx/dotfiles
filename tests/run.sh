#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

pass() {
    printf 'ok - %s\n' "$1"
}

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

bash -n \
    "$REPO_ROOT/setup.sh" \
    "$REPO_ROOT/uninstall.sh" \
    "$REPO_ROOT/setup/lib.sh" \
    "$REPO_ROOT/setup/core.sh" \
    "$REPO_ROOT/setup/fnm.sh" \
    "$REPO_ROOT/setup/modules.sh" \
    "$REPO_ROOT/setup/zsh.sh"
pass "Bash syntax"

zsh -n \
    "$REPO_ROOT/.zshenv" \
    "$REPO_ROOT/.zshrc" \
    "$REPO_ROOT/modules/"*.zsh
pass "Zsh syntax"

"$REPO_ROOT/setup.sh" --help | grep -q DISABLE_PRINT_ALIAS_COMPLETION
bash "$REPO_ROOT/setup/core.sh" skip >/dev/null
if bash "$REPO_ROOT/setup/core.sh" invalid >/dev/null 2>&1; then
    fail "invalid setup action was accepted"
fi
pass "setup command validation"

UNINSTALL_HOME="$TEMP_ROOT/uninstall-home"
mkdir -p "$UNINSTALL_HOME"
printf '%s\n' n n > "$TEMP_ROOT/uninstall-input"
HOME="$UNINSTALL_HOME" "$REPO_ROOT/uninstall.sh" \
    < "$TEMP_ROOT/uninstall-input" \
    > "$TEMP_ROOT/uninstall-output"
grep -q 'No components selected; nothing was removed.' "$TEMP_ROOT/uninstall-output"
pass "zero-argument interactive uninstall"

MODULE_ROOT="$TEMP_ROOT/module-config"
mkdir -p "$MODULE_ROOT"
bash "$REPO_ROOT/setup/modules.sh" \
    write \
    "$MODULE_ROOT" \
    true \
    false \
    true \
    false \
    true >/dev/null
grep -qx 'DISABLE_ALIASES=true' "$MODULE_ROOT/.env"
grep -qx 'DISABLE_PROMPT=false' "$MODULE_ROOT/.env"
grep -qx 'DISABLE_PLUGINS=true' "$MODULE_ROOT/.env"
grep -qx 'DISABLE_PRINT_ALIAS_COMPLETION=false' "$MODULE_ROOT/.env"
grep -qx 'DISABLE_EXPAND_ALIAS=true' "$MODULE_ROOT/.env"
if bash "$REPO_ROOT/setup/modules.sh" \
    write "$MODULE_ROOT" maybe false false false false >/dev/null 2>&1; then
    fail "invalid module boolean was accepted"
fi
pass "module configuration persistence"

TEST_HOME="$TEMP_ROOT/home"
TEST_CACHE="$TEST_HOME/.cache"
TEST_STATE="$TEST_HOME/.local/state"
COMPLETION_DIR="$TEST_CACHE/antidote/github.com/zsh-users/zsh-completions/src"
ZSH_BIN="$(command -v zsh)"
TEST_PATH="${ZSH_BIN%/*}:/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$COMPLETION_DIR"
printf '%s\n' '#compdef dotfiles-smoke' '_arguments "*:file:_files"' \
    > "$COMPLETION_DIR/_dotfiles-smoke"

# The single-quoted program is evaluated by Zsh, not Bash.
# shellcheck disable=SC2016
env -u FPATH \
    HOME="$TEST_HOME" \
    XDG_CACHE_HOME="$TEST_CACHE" \
    XDG_STATE_HOME="$TEST_STATE" \
    ANTIDOTE_HOME="$TEST_CACHE/antidote" \
    PATH="$TEST_PATH" \
    DOTFILES_DIR="$REPO_ROOT" \
    DISABLE_ALIASES=true \
    DISABLE_PROMPT=true \
    DISABLE_PLUGINS=true \
    DISABLE_PRINT_ALIAS_COMPLETION=true \
    DISABLE_EXPAND_ALIAS=true \
    zsh -dfc '
        source "$DOTFILES_DIR/.zshrc"
        [[ "${_comps[dotfiles-smoke]-}" == "_dotfiles-smoke" ]]
        (( ! ${+functions[dotfiles]} ))
    '
pass "clean startup, environment overrides, and third-party completion discovery"

# The single-quoted program is evaluated by Zsh, not Bash.
# shellcheck disable=SC2016
env -u FPATH \
    HOME="$TEST_HOME" \
    XDG_CACHE_HOME="$TEST_CACHE" \
    XDG_STATE_HOME="$TEST_STATE" \
    ANTIDOTE_HOME="$TEST_CACHE/antidote" \
    PATH="$TEST_PATH" \
    DOTFILES_DIR="$REPO_ROOT" \
    DISABLE_ALIASES=false \
    DISABLE_PROMPT=true \
    DISABLE_PLUGINS=true \
    DISABLE_PRINT_ALIAS_COMPLETION=true \
    DISABLE_EXPAND_ALIAS=true \
    zsh -dfc '
        source "$DOTFILES_DIR/.zshrc"
        [[ "$(dotfiles rev-parse --show-toplevel)" == "$DOTFILES_DIR" ]]
    '
pass "dotfiles Git helper"

COMP_DUMP="$REPO_ROOT/.cache/zsh/zcompdump-$(zsh --version | awk '{print $2}')"
[[ -s "$COMP_DUMP" ]] || fail "completion dump was not created"
[[ -s "$COMP_DUMP.zwc" ]] || fail "compiled completion dump was not created"
pass "completion cache"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck \
        "$REPO_ROOT/setup.sh" \
        "$REPO_ROOT/uninstall.sh" \
        "$REPO_ROOT/setup/"*.sh \
        "$REPO_ROOT/scripts/"*.sh \
        "$REPO_ROOT/tests/run.sh"
    pass "ShellCheck"
else
    printf 'skip - ShellCheck is not installed\n'
fi

git -C "$REPO_ROOT" diff --check
pass "whitespace validation"

printf 'All checks passed.\n'
