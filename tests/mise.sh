#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
repo="$TEMP_ROOT/repo"
mkdir -p "$repo/profiles/zsh/setup" "$repo/setup" "$TEMP_ROOT/bin" "$TEMP_ROOT/home"
cp "$REPO_ROOT/profiles/zsh/setup/mise.sh" "$repo/profiles/zsh/setup/"
cp "$REPO_ROOT/setup/lib.sh" "$repo/setup/"
cp "$REPO_ROOT/uninstall.sh" "$repo/"
export HOME="$TEMP_ROOT/home" PATH="$TEMP_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MISE_TEST_LOG="$TEMP_ROOT/log" MISE_TEST_ARTIFACT="$TEMP_ROOT/artifact"
cat > "$MISE_TEST_ARTIFACT" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MISE_TEST_LOG"
MOCK
cat > "$TEMP_ROOT/bin/uname" <<'MOCK'
#!/usr/bin/env bash
case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac
MOCK
cat > "$TEMP_ROOT/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MISE_TEST_LOG"
while [[ $# -gt 0 ]]; do
    if [[ "$1" == --output ]]; then cp "$MISE_TEST_ARTIFACT" "$2"; exit; fi
    shift
done
exit 1
MOCK
chmod +x "$TEMP_ROOT/bin/"*
installer="$repo/profiles/zsh/setup/mise.sh"
bash "$installer" skip
[[ ! -e "$MISE_TEST_LOG" ]]
if NODE_VERSION='--help' bash "$installer" install >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$MISE_TEST_LOG" ]]
# A bad download must never be installed or executed.
if bash "$installer" install >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$HOME/.local/bin/mise" ]]
if grep -q '^use ' "$MISE_TEST_LOG"; then exit 1; fi
# Change only the copied fixture's expected digest to exercise successful install.
# shellcheck source=setup/lib.sh
source "$repo/setup/lib.sh"
digest="$(sha256_file "$MISE_TEST_ARTIFACT")"
sed "s/c9b089f2be1db4d4262eacaf367e480e7a328848adcc37d9d1612996902485d0/$digest/" \
    "$installer" > "$TEMP_ROOT/installer"
cp "$TEMP_ROOT/installer" "$installer"
: > "$MISE_TEST_LOG"
bash "$installer" install
[[ -x "$HOME/.local/bin/mise" ]]
grep -qx 'settings add idiomatic_version_file_enable_tools node' "$MISE_TEST_LOG"
grep -qx 'use --global node@24.12.0' "$MISE_TEST_LOG"
: > "$MISE_TEST_LOG"
NODE_VERSION=22.14.0 bash "$installer" install
grep -qx 'use --global node@22.14.0' "$MISE_TEST_LOG"
[[ $(wc -l < "$MISE_TEST_LOG") -eq 2 ]]
mkdir -p "$HOME/.local/share/mise" "$HOME/.config/mise"
echo retained > "$HOME/.local/share/mise/runtime"
echo retained > "$HOME/.config/mise/config.toml"
printf 'uninstall\n' | bash "$repo/uninstall.sh" --mise
[[ ! -e "$HOME/.local/bin/mise" ]]
[[ -f "$HOME/.local/share/mise/runtime" && -f "$HOME/.config/mise/config.toml" ]]
# External installations are reused and remain unowned.
cp "$MISE_TEST_ARTIFACT" "$HOME/.local/bin/mise"
chmod +x "$HOME/.local/bin/mise"
bash "$installer" install
[[ ! -e "$HOME/.local/bin/.mise-installed-by-dotfiles" ]]
printf 'uninstall\n' | bash "$repo/uninstall.sh" --mise
[[ -x "$HOME/.local/bin/mise" ]]
echo changed > "$HOME/.local/bin/.mise-installed-by-dotfiles"
printf 'uninstall\n' | bash "$repo/uninstall.sh" --mise
[[ -x "$HOME/.local/bin/mise" ]]
printf 'ok - mise verification, setup, reuse, and guarded removal\n'

# Exercise the normal interactive flow with every side effect confined to fixtures.
cp "$REPO_ROOT/profiles/zsh/setup.sh" "$repo/profiles/zsh/"
touch "$repo/.zshrc"
# Keep the real dependency invocation; stop before shell/plugin installation.
awk '/^log "Setting up Zsh/ { print "exit 0"; exit } { print }' \
    "$REPO_ROOT/profiles/zsh/setup/zsh.sh" > "$repo/profiles/zsh/setup/zsh.sh"
for component in core modules; do
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$repo/profiles/zsh/setup/$component.sh"
done
: > "$MISE_TEST_LOG"
printf 'n\ny\nn\nn\nn\nn\nn\ny\n' | bash "$repo/profiles/zsh/setup.sh" >/dev/null
grep -qx 'settings add idiomatic_version_file_enable_tools node' "$MISE_TEST_LOG"
grep -qx 'use --global node@24.12.0' "$MISE_TEST_LOG"
[[ $(wc -l < "$MISE_TEST_LOG") -eq 2 ]]
: > "$MISE_TEST_LOG"
printf 'n\nn\nn\nn\nn\nn\nn\ny\n' | bash "$repo/profiles/zsh/setup.sh" >/dev/null
[[ ! -s "$MISE_TEST_LOG" ]]
printf 'ok - interactive Zsh setup configures mise automatically; declining leaves it unchanged\n'
