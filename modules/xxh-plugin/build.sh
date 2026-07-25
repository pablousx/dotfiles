#!/usr/bin/env bash

set -Eeuo pipefail

CDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="${XXH_DOTFILES_SRC:-$(cd "$CDIR/../.." && pwd -P)}"
BUILD_DIR="$CDIR/build"
CACHE_DIR="${XXH_BUILD_CACHE:-$SRC_DIR/.cache/xxh-sources}"

P10K_REPOSITORY="https://github.com/romkatv/powerlevel10k.git"
P10K_COMMIT="9253fb1c5034410c43a0c681ff8294181c54016c"
AUTOSUGGESTIONS_REPOSITORY="https://github.com/zsh-users/zsh-autosuggestions.git"
AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
HIGHLIGHTING_REPOSITORY="https://github.com/zsh-users/zsh-syntax-highlighting.git"
HIGHLIGHTING_COMMIT="1d85c692615a25fe2293bdd44b34c217d5d2bf04"

[[ -f "$SRC_DIR/.zshrc" ]] || {
    printf 'build error: .zshrc not found in %s\n' "$SRC_DIR" >&2
    exit 1
}
[[ "$BUILD_DIR" == "$CDIR/build" ]] || {
    printf 'build error: refusing unexpected build directory: %s\n' "$BUILD_DIR" >&2
    exit 1
}

mkdir -p "$CACHE_DIR"
STAGE_DIR="$(mktemp -d "$CDIR/.build.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
mkdir -p "$STAGE_DIR/plugins"

ensure_checkout() {
    local repository="$1"
    local commit="$2"
    local destination="$3"

    if [[ ! -d "$destination/.git" ]]; then
        git clone --filter=blob:none --no-checkout "$repository" "$destination"
    fi
    if ! git -C "$destination" cat-file -e "$commit^{commit}" 2>/dev/null; then
        git -C "$destination" fetch --depth=1 origin "$commit"
    fi
    git -C "$destination" checkout --detach "$commit"
}

archive_checkout() {
    local checkout="$1"
    local commit="$2"
    local destination="$3"

    mkdir -p "$destination"
    git -C "$checkout" archive "$commit" | tar -x -C "$destination"
}

printf 'Building XXH plugin from %s...\n' "$SRC_DIR"

ensure_checkout "$P10K_REPOSITORY" "$P10K_COMMIT" "$CACHE_DIR/powerlevel10k"
ensure_checkout "$AUTOSUGGESTIONS_REPOSITORY" "$AUTOSUGGESTIONS_COMMIT" "$CACHE_DIR/zsh-autosuggestions"
ensure_checkout "$HIGHLIGHTING_REPOSITORY" "$HIGHLIGHTING_COMMIT" "$CACHE_DIR/zsh-syntax-highlighting"

archive_checkout "$CACHE_DIR/powerlevel10k" "$P10K_COMMIT" "$STAGE_DIR/powerlevel10k"
archive_checkout \
    "$CACHE_DIR/zsh-autosuggestions" \
    "$AUTOSUGGESTIONS_COMMIT" \
    "$STAGE_DIR/plugins/zsh-autosuggestions"
archive_checkout \
    "$CACHE_DIR/zsh-syntax-highlighting" \
    "$HIGHLIGHTING_COMMIT" \
    "$STAGE_DIR/plugins/zsh-syntax-highlighting"

# Remove development-only content while retaining licenses and runtime files.
rm -rf \
    "$STAGE_DIR/powerlevel10k/.github" \
    "$STAGE_DIR/powerlevel10k/.vscode" \
    "$STAGE_DIR/powerlevel10k/config" \
    "$STAGE_DIR/powerlevel10k/gitstatus/docs" \
    "$STAGE_DIR/powerlevel10k/gitstatus/src" \
    "$STAGE_DIR/powerlevel10k/powerlevel10k.png" \
    "$STAGE_DIR/plugins/zsh-autosuggestions/.github" \
    "$STAGE_DIR/plugins/zsh-autosuggestions/spec" \
    "$STAGE_DIR/plugins/zsh-syntax-highlighting/.github" \
    "$STAGE_DIR/plugins/zsh-syntax-highlighting/docs" \
    "$STAGE_DIR/plugins/zsh-syntax-highlighting/images" \
    "$STAGE_DIR/plugins/zsh-syntax-highlighting/tests"
find "$STAGE_DIR/plugins/zsh-syntax-highlighting/highlighters" \
    -type d -name test-data -prune -exec rm -rf {} +

cp "$CDIR/pluginrc.zsh" "$STAGE_DIR/pluginrc.zsh"
{
    printf '\n%s\n' "# --- Core options ---"
    grep '^setopt ' "$SRC_DIR/.zshrc"
    printf '\n%s\n' "# --- Completion settings ---"
    grep '^zstyle ' "$SRC_DIR/.zshrc" | grep -v 'fzf-preview'
    printf '\n%s\n' "# --- Git aliases ---"
    cat "$CDIR/git-aliases.zsh"
    printf '\n%s\n' "# --- Portable aliases ---"
    cat "$CDIR/portable-aliases.zsh"
} >> "$STAGE_DIR/pluginrc.zsh"

cp "$SRC_DIR/.p10k.zsh" "$STAGE_DIR/p10k.zsh"

HASH_LIST="$STAGE_DIR/.content-hashes"
: > "$HASH_LIST"
while IFS= read -r runtime_file; do
    printf '%s  %s\n' \
        "$(git hash-object "$runtime_file")" \
        "${runtime_file#"$STAGE_DIR"/}" >> "$HASH_LIST"
done < <(find "$STAGE_DIR" -type f ! -name .content-hashes | LC_ALL=C sort)
CONTENT_HASH="$(git hash-object "$HASH_LIST")"
rm "$HASH_LIST"

printf '{"name":"xxh-plugin-zsh-dotfiles","version":"%s"}\n' \
    "${CONTENT_HASH:0:12}" > "$CDIR/manifest.json"
cp "$CDIR/manifest.json" "$STAGE_DIR/manifest.json"

rm -rf "$BUILD_DIR"
mv "$STAGE_DIR" "$BUILD_DIR"
trap - EXIT

printf 'Built %s files (%s).\n' \
    "$(find "$BUILD_DIR" -type f | wc -l | tr -d ' ')" \
    "$(du -sh "$BUILD_DIR" | awk '{print $1}')"
