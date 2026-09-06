#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
repo="$temporary/repo"
mkdir -p "$repo" "$temporary/bin" "$temporary/empty-path" "$temporary/home"
cp -R "$REPO_ROOT/profiles" "$REPO_ROOT/shared" "$REPO_ROOT/setup" "$REPO_ROOT/config" "$repo/"
cp "$REPO_ROOT/setup.sh" "$REPO_ROOT/.zshrc" "$repo/"
# shellcheck source=tests/fixtures/platform.sh
source "$REPO_ROOT/tests/fixtures/platform.sh"
install_platform_fixture "$repo" "$temporary"
# shellcheck source=setup/lib.sh
source "$repo/setup/lib.sh"
export HOME="$temporary/home"
export DISTRO_CALLS="$temporary/calls"
for manager in apt-get dnf pacman zypper brew omarchy; do
    cat > "$temporary/bin/$manager" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected installation\n' >> "$DISTRO_CALLS"
exit 99
MOCK
    chmod +x "$temporary/bin/$manager"
done
export PATH="$temporary/bin:$PATH"

# Classification follows ID, then ID_LIKE order, never executable order on PATH.
while IFS='|' read -r distro like manager profile; do
    printf 'NAME="Fixture Linux"\nID="%s"\nID_LIKE="%s"\n' "$distro" "$like" > "$TEST_DISTRO_RELEASE"
    detect_platform
    [[ "$DETECTED_DISTRO" == "$distro" && "$DETECTED_MANAGER" == "$manager" && "$DETECTED_PROFILE" == "$profile" ]]
    [[ "$(detect_package_manager)" == "$manager" ]]
done <<'MATRIX'
ubuntu|debian|apt-get|zsh
debian||apt-get|zsh
linuxmint|ubuntu debian|apt-get|zsh
pop|ubuntu debian|apt-get|zsh
fedora||dnf|zsh
rhel|fedora|dnf|zsh
centos|rhel fedora|dnf|zsh
rocky|rhel centos fedora|dnf|zsh
almalinux|rhel centos fedora|dnf|zsh
arch||pacman|zsh
manjaro|arch|pacman|zsh
endeavouros|arch|pacman|zsh
omarchy|arch|pacman|omarchy
opensuse-leap|suse opensuse|zypper|zsh
opensuse-tumbleweed|opensuse suse|zypper|zsh
sles|suse|zypper|zsh
custom-linux|unmatched debian|apt-get|zsh
fedora|debian|dnf|zsh
MATRIX
# WSL reports Linux and uses the installed distro's ID/ID_LIKE, same as native.
printf "ID='ubuntu'\r\nID_LIKE='debian'\r\n" > "$TEST_DISTRO_RELEASE"
detect_platform Linux "$TEST_DISTRO_RELEASE"
[[ "$DETECTED_DISTRO" == ubuntu && "$DETECTED_MANAGER" == apt-get ]]
# Older Omarchy installations used ID=arch and a packaged Bash startup marker.
printf 'ID=arch\n' > "$TEST_DISTRO_RELEASE"
mkdir -p "$temporary/omarchy/default/bash"
touch "$temporary/omarchy/default/bash/rc"
OMARCHY_PATH="$temporary/omarchy" detect_platform
[[ "$DETECTED_DISTRO" == omarchy && "$DETECTED_PROFILE" == omarchy ]]
# macOS remains supported without requiring os-release.
TEST_DISTRO_KERNEL=Darwin detect_platform
[[ "$DETECTED_DISTRO" == macos && "$DETECTED_MANAGER" == brew && "$DETECTED_PROFILE" == zsh ]]
# Unknown hosts fail before settings, startup files or installers are touched.
printf 'ID=alpine\n' > "$TEST_DISTRO_RELEASE"
if bash "$repo/setup.sh" --all > "$temporary/error" 2>&1; then exit 1; fi
grep -q 'unsupported Linux distribution: alpine' "$temporary/error"
[[ ! -e "$DISTRO_CALLS" && ! -e "$repo/.env" && ! -e "$repo/.env.omarchy" && ! -e "$HOME/.bashrc" ]]
if bash "$repo/setup.sh" --profile zsh --disable-prompt >/dev/null 2>&1; then exit 1; fi
if TEST_DISTRO_KERNEL=FreeBSD bash "$repo/setup.sh" --all >/dev/null 2>&1; then exit 1; fi
# Help is available even when detection cannot succeed.
bash "$repo/setup.sh" --help > "$temporary/help"
grep -q 'profile auto|zsh|omarchy' "$temporary/help"
TEST_DISTRO_RELEASE="$temporary/missing" bash "$repo/setup.sh" --profile omarchy --help >/dev/null
if TEST_DISTRO_RELEASE="$temporary/missing" bash "$repo/setup.sh" --all >/dev/null 2>&1; then exit 1; fi
# A foreign package manager must not make an unsupported distro eligible.
[[ -x "$temporary/bin/apt-get" && -x "$temporary/bin/pacman" ]]
if (detect_package_manager) >/dev/null 2>&1; then exit 1; fi
# Invalid metadata is rejected as data, never evaluated as shell code.
# Intentionally inert shell syntax: os-release must never be evaluated.
# shellcheck disable=SC2016
printf '%s\n' 'ID="$(touch should-not-exist)"' > "$TEST_DISTRO_RELEASE"
if bash "$repo/setup.sh" --all >/dev/null 2>&1; then exit 1; fi
[[ ! -e should-not-exist ]]
printf 'ID=ubuntu\nID_LIKE="debian;false"\n' > "$TEST_DISTRO_RELEASE"
if bash "$repo/setup.sh" --all >/dev/null 2>&1; then exit 1; fi
# A missing native manager fails instead of falling back to an unrelated one.
printf 'ID=ubuntu\n' > "$TEST_DISTRO_RELEASE"
if (PATH="$temporary/empty-path" detect_package_manager) > "$temporary/error" 2>&1; then exit 1; fi
grep -q 'apt-get is required for ubuntu' "$temporary/error"
# A supported distro cannot select an incompatible profile.
if bash "$repo/setup.sh" --profile omarchy --all > "$temporary/error" 2>&1; then exit 1; fi
grep -q 'profile omarchy is incompatible with ubuntu' "$temporary/error"
[[ ! -e "$DISTRO_CALLS" && ! -e "$repo/.env" && ! -e "$repo/.env.omarchy" ]]
# Argument-bearing automation now auto-selects too, while explicit Zsh works.
bash "$repo/setup.sh" --disable-prompt > "$temporary/ubuntu-output"
grep -q 'Detected distribution: ubuntu; profile: zsh' "$temporary/ubuntu-output"
grep -qx 'DISABLE_PROMPT=true' "$repo/.env"
[[ ! -e "$repo/.env.omarchy" ]]
printf 'ID=omarchy\nID_LIKE=arch\n' > "$TEST_DISTRO_RELEASE"
bash "$repo/setup.sh" --help > "$temporary/omarchy-help"
grep -q -- '--save-keyboard' "$temporary/omarchy-help"
bash "$repo/setup.sh" --disable-prompt > "$temporary/omarchy-output"
grep -q 'Detected distribution: omarchy; profile: omarchy' "$temporary/omarchy-output"
grep -qx 'DISABLE_PROMPT=true' "$repo/.env.omarchy"
bash "$repo/setup.sh" --profile zsh --enable-prompt >/dev/null
grep -qx 'DISABLE_PROMPT=false' "$repo/.env"
grep -qx 'DISABLE_PROMPT=true' "$repo/.env.omarchy"
[[ ! -e "$DISTRO_CALLS" ]]
printf 'ok - distro families, auto profiles, compatibility, missing managers and fail-before-write\n'
