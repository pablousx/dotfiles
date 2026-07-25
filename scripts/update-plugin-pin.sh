#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PLUGIN_FILE="$REPO_ROOT/modules/plugins.txt"
REPOSITORY="${1:-}"
COMMIT="${2:-}"

if [[ -z "$REPOSITORY" || ! "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'Usage: %s owner/repository 40-character-commit\n' "$0" >&2
    exit 2
fi

CACHE_DIR="${ANTIDOTE_HOME:-$HOME/.cache/antidote}/github.com/$REPOSITORY"
if [[ ! -d "$CACHE_DIR/.git" ]]; then
    git clone --filter=blob:none "https://github.com/$REPOSITORY.git" "$CACHE_DIR"
fi
git -C "$CACHE_DIR" fetch --depth=1 origin "$COMMIT"
git -C "$CACHE_DIR" checkout --detach "$COMMIT"

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

awk -v repository="$REPOSITORY" -v commit="$COMMIT" '
    $1 == repository {
        output = ""
        found_pin = 0
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^pin:/) {
                $i = "pin:" commit
                found_pin = 1
            }
            output = output (i == 1 ? "" : " ") $i
        }
        if (!found_pin) {
            output = output " pin:" commit
        }
        print output
        next
    }
    { print }
' "$PLUGIN_FILE" > "$TEMP_FILE"

if cmp -s "$PLUGIN_FILE" "$TEMP_FILE"; then
    printf '%s is already pinned to %s.\n' "$REPOSITORY" "$COMMIT"
    exit 0
fi

mv "$TEMP_FILE" "$PLUGIN_FILE"
trap - EXIT

generated="$REPO_ROOT/modules/plugins.zsh.tmp"
trap 'rm -f "$generated"' EXIT
zsh -dfc 'source "$1"; antidote bundle < "$2"' _ \
    "$REPO_ROOT/.antidote/antidote.zsh" \
    "$PLUGIN_FILE" > "$generated"
mv "$generated" "$REPO_ROOT/modules/plugins.zsh"
trap - EXIT

printf 'Pinned %s to %s and regenerated modules/plugins.zsh.\n' "$REPOSITORY" "$COMMIT"
