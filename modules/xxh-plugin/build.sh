#!/usr/bin/env bash
CDIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${XXH_DOTFILES_SRC:-$(cd "$CDIR/../.." && pwd)}"
BUILD_DIR="$CDIR/build"

# Safety Check
if [ ! -f "$SRC_DIR/.zshrc" ]; then
    echo "❌ build error: .zshrc not found in $SRC_DIR"
    exit 1
fi

mkdir -p "$BUILD_DIR/plugins"

echo "building xxh-plugin from $SRC_DIR..."

# 1. Bundle Theme & Plugins
[ ! -d "$BUILD_DIR/powerlevel10k" ] && echo "  ↓ cloning p10k..." && git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git "$BUILD_DIR/powerlevel10k"
[ ! -d "$BUILD_DIR/plugins/zsh-autosuggestions" ] && echo "  ↓ bundling autosuggestions..." && git clone -q --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$BUILD_DIR/plugins/zsh-autosuggestions"
[ ! -d "$BUILD_DIR/plugins/zsh-syntax-highlighting" ] && echo "  ↓ bundling syntax-highlighting..." && git clone -q --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$BUILD_DIR/plugins/zsh-syntax-highlighting"

# 2. Copy the clean master pluginrc.zsh
cp "$CDIR/pluginrc.zsh" "$BUILD_DIR/pluginrc.zsh"

# 3. Append dynamic parts
{
  echo -e "\n# --- Core Options ---"
  grep "^setopt " "$SRC_DIR/.zshrc"
  echo -e "\n# --- Completion Settings ---"
  grep "^zstyle " "$SRC_DIR/.zshrc" | grep -v "fzf-preview"
  echo -e "\n# --- Git Aliases ---"
  [ -f "$CDIR/git-aliases.zsh" ] && cat "$CDIR/git-aliases.zsh"
  echo -e "\n# --- General Aliases ---"
  sed '/^\(function \)\?xxhh().*/,/^}/d' "$SRC_DIR/modules/aliases.zsh"
} >> "$BUILD_DIR/pluginrc.zsh"

# 4. Copy P10k config
[ -f "$SRC_DIR/.p10k.zsh" ] && cp "$SRC_DIR/.p10k.zsh" "$BUILD_DIR/p10k.zsh"

# 5. Update manifest
echo "{\"name\":\"xxh-plugin-zsh-dotfiles\",\"version\":\"$(date +%s)\"}" > "$CDIR/manifest.json"
