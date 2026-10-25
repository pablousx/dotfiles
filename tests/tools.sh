#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
# macOS temporary paths may contain symlinks; match installer physical paths.
temporary="$(cd "$temporary" && pwd -P)"
trap 'rm -rf "$temporary"' EXIT
repo="$temporary/repo space"
mkdir -p "$repo/setup" "$repo/tools" "$temporary/bin"
cp "$REPO_ROOT/setup/"{tools,mise-lib,lib}.sh "$repo/setup/"
cp "$REPO_ROOT/tools/"* "$repo/tools/"
# Use a minimal PATH so the host's mise cannot satisfy the bootstrap test.
for tool in cat bash uname awk dirname mktemp rm mkdir cp chmod mv ln readlink curl sha256sum shasum; do
    binary="$(type -P "$tool" || true)"
    [[ -z "$binary" ]] || ln -s "$binary" "$temporary/bin/$tool"
done
export PATH="$temporary/bin"
export HOME="$temporary/skip-home"
export XDG_CONFIG_HOME="$HOME/config" TMPDIR="$temporary"
unset MISE_CONFIG_DIR
export TOOLS_CALLS="$temporary/calls" TOOLS_PAYLOAD="$temporary/mise"
cat > "$TOOLS_PAYLOAD" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == --version ]]; then printf '%s linux-x64\n' "${TOOLS_VERSION:-2026.10.11}"; exit; fi
[[ "$*" == '--yes --locked install' ]] || exit 99
[[ "$MISE_GLOBAL_CONFIG_FILE" == "$TOOLS_MANIFEST" && "$MISE_SYSTEM_CONFIG_FILE" == */system.toml ]] || exit 98
printf 'install\n' >> "$TOOLS_CALLS"
[[ "${TOOLS_FAIL:-false}" != true ]]
MOCK
chmod +x "$TOOLS_PAYLOAD"
export TOOLS_MANIFEST="$repo/tools/mise.toml"
# Substitute fixture digests only in the disposable installer copy.
# shellcheck source=setup/lib.sh
source "$repo/setup/lib.sh"
fixture_sha="$(sha256_file "$TOOLS_PAYLOAD")"
/usr/bin/sed -E "s/checksum=[a-f0-9]{64}/checksum=$fixture_sha/g" \
    "$repo/setup/tools.sh" > "$temporary/installer"
cp "$temporary/installer" "$repo/setup/tools.sh"
rm "$temporary/bin/curl" "$temporary/bin/uname"
cat > "$temporary/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TOOLS_CALLS"
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == --output ]]; then cp "$TOOLS_PAYLOAD" "$2"; exit; fi
    shift
done
exit 99
MOCK
cat > "$temporary/bin/uname" <<'MOCK'
#!/usr/bin/env bash
case "$1" in -s) printf '%s\n' "$TOOLS_KERNEL" ;; -m) printf '%s\n' "$TOOLS_ARCH" ;; *) exit 99 ;; esac
MOCK
chmod +x "$temporary/bin/curl" "$temporary/bin/uname"
bash "$repo/setup/tools.sh" skip >/dev/null
[[ ! -e "$HOME" && ! -e "$TOOLS_CALLS" ]]
if bash "$repo/setup/tools.sh" invalid >/dev/null 2>&1; then exit 1; fi
while IFS='|' read -r TOOLS_KERNEL TOOLS_ARCH expected; do
    export TOOLS_KERNEL TOOLS_ARCH
    export HOME="$temporary/$TOOLS_KERNEL-$TOOLS_ARCH" XDG_CONFIG_HOME="$temporary/$TOOLS_KERNEL-$TOOLS_ARCH/config"
    bash "$repo/setup/tools.sh" install >/dev/null
    [[ -x "$HOME/.local/bin/mise" ]]
    [[ "$(readlink "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml")" == "$TOOLS_MANIFEST" ]]
    /usr/bin/grep -q "mise-v2026.10.11-$expected" "$TOOLS_CALLS"
    before="$(/usr/bin/grep -c github.com "$TOOLS_CALLS")"
    bash "$repo/setup/tools.sh" install >/dev/null
    [[ "$(/usr/bin/grep -c github.com "$TOOLS_CALLS")" == "$before" ]]
done <<'MATRIX'
Linux|x86_64|linux-x64
Linux|aarch64|linux-arm64
Darwin|x86_64|macos-x64
Darwin|arm64|macos-arm64
MATRIX

export TOOLS_KERNEL=Linux TOOLS_ARCH=x86_64

# Existing mise is reused; personal config stays byte-for-byte unchanged.
cp "$TOOLS_PAYLOAD" "$temporary/bin/mise"
export HOME="$temporary/existing" XDG_CONFIG_HOME="$temporary/existing/config"
mkdir -p "$XDG_CONFIG_HOME/mise"
printf 'personal config\n' > "$XDG_CONFIG_HOME/mise/config.toml"
bash "$repo/setup/tools.sh" install >/dev/null
[[ ! -e "$HOME/.local/bin/mise" ]]
[[ "$(/usr/bin/cat "$XDG_CONFIG_HOME/mise/config.toml")" == 'personal config' ]]
export TOOLS_VERSION=2025.1.1
if bash "$repo/setup/tools.sh" install >/dev/null 2>&1; then exit 1; fi
unset TOOLS_VERSION
rm "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml"
printf 'personal fragment\n' > "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml"
cp "$TOOLS_CALLS" "$temporary/previous-calls"
if bash "$repo/setup/tools.sh" install >/dev/null 2>&1; then exit 1; fi
/usr/bin/cmp "$TOOLS_CALLS" "$temporary/previous-calls"
[[ "$(/usr/bin/cat "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml")" == 'personal fragment' ]]
rm "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml"
export TOOLS_FAIL=true
if bash "$repo/setup/tools.sh" install >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml" ]]
unset TOOLS_FAIL
rm "$temporary/bin/mise"

# Reject unsupported platforms and corruption before executing the payload.
export HOME="$temporary/corrupt" XDG_CONFIG_HOME="$temporary/corrupt/config"
export TOOLS_KERNEL=FreeBSD
if bash "$repo/setup/tools.sh" install >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$HOME" ]]
export TOOLS_KERNEL=Linux TOOLS_ARCH=x86_64
printf 'corrupted\n' > "$TOOLS_PAYLOAD"
if bash "$repo/setup/tools.sh" install > "$temporary/error" 2>&1; then exit 1; fi
/usr/bin/grep -q 'mise SHA-256 mismatch' "$temporary/error"
[[ ! -e "$HOME/.local/bin/mise" ]]

# Removal owns only the matching fragment, never mise's shared install store.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
mkdir -p "$XDG_CONFIG_HOME/mise/conf.d" "$HOME/.local/share/mise/installs"
ln -s "$REPO_ROOT/tools/mise.toml" "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml"
printf 'keep\n' > "$HOME/.local/share/mise/installs/personal"
printf 'uninstall\n' | bash "$REPO_ROOT/uninstall.sh" --tools >/dev/null
[[ ! -L "$XDG_CONFIG_HOME/mise/conf.d/dotfiles.toml" && -f "$HOME/.local/share/mise/installs/personal" ]]
printf 'ok - mise bootstrap platforms, verification, reuse, ownership, failure and removal\n'
