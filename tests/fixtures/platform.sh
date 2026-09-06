#!/usr/bin/env bash
# Replace host reads only in a disposable copy, never in production setup code.
install_platform_fixture() {
    local repo="$1" temporary="$2"
    export TEST_DISTRO_KERNEL=Linux
    export TEST_DISTRO_RELEASE="$temporary/os-release"
    export OMARCHY_PATH="$temporary/no-omarchy"
    printf 'ID=omarchy\nID_LIKE=arch\n' > "$TEST_DISTRO_RELEASE"
    cat >> "$repo/setup/lib.sh" <<'FIXTURE'

platform_kernel() { printf '%s\n' "$TEST_DISTRO_KERNEL"; }
platform_release_file() { printf '%s\n' "$TEST_DISTRO_RELEASE"; }
FIXTURE
}
