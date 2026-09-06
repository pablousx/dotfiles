#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home"
export XDG_CONFIG_HOME="$HOME/custom config"
export HYPRLAND_INSTANCE_SIGNATURE=keyboard-test
export KEYBOARD_CALLS="$temporary/calls"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$temporary/bin" "$temporary/repo"
repo="$temporary/repo"
cp -R "$REPO_ROOT/setup" "$REPO_ROOT/config" "$REPO_ROOT/profiles" "$repo/"
cp "$REPO_ROOT/setup.sh" "$REPO_ROOT/uninstall.sh" "$repo/"
# shellcheck source=tests/fixtures/platform.sh
source "$REPO_ROOT/tests/fixtures/platform.sh"
install_platform_fixture "$repo" "$temporary"
cat > "$temporary/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KEYBOARD_CALLS"
[[ "$1" != configerrors || ${KEYBOARD_ERRORS:-false} != true ]] || printf 'fixture error\n'
exit 0
MOCK
chmod +x "$temporary/bin/hyprctl"
export PATH="$temporary/bin:$PATH"
printf '%s\n' 'require("hypr.input")' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf '%s\n' '-- user input options' 'hl.config({input={repeat_rate=40}})' > "$XDG_CONFIG_HOME/hypr/input.lua"
cp "$XDG_CONFIG_HOME/hypr/input.lua" "$temporary/original"
bash "$repo/setup/keyboard.sh" skip
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/input.lua"
[[ ! -d "$XDG_CONFIG_HOME/xkb" ]]
# Interactive layout selection installs the saved keyboard after confirmation.
printf 'n\nn\ninvalid\n2\nn\ny\ny\ny\ny\ny\n' | bash "$repo/setup.sh" --profile omarchy
cmp "$repo/config/xkb/symbols/us-altgr-spanish" "$XDG_CONFIG_HOME/xkb/symbols/us-altgr-spanish"
grep -Fq 'kb_layout = "us-altgr-spanish"' "$XDG_CONFIG_HOME/hypr/input.lua"
cp "$XDG_CONFIG_HOME/hypr/input.lua" "$temporary/installed"
# Accepting None must preserve an already installed layout and avoid a reload.
cp "$KEYBOARD_CALLS" "$temporary/calls-before-none"
printf 'n\nn\n\nn\ny\ny\ny\ny\ny\n' | bash "$repo/setup.sh" --profile omarchy
cmp "$temporary/installed" "$XDG_CONFIG_HOME/hypr/input.lua"
cmp "$temporary/calls-before-none" "$KEYBOARD_CALLS"
bash "$repo/setup.sh" --profile omarchy --keyboard
cmp "$temporary/installed" "$XDG_CONFIG_HOME/hypr/input.lua"
[[ $(find "$XDG_CONFIG_HOME/hypr" -name '*.dotfiles-backup.*' | wc -l) -eq 1 ]]
printf 'reload\nconfigerrors\nreload\nconfigerrors\n' > "$temporary/expected-calls"
cmp "$temporary/expected-calls" "$KEYBOARD_CALLS"
# Saving copies local edits to the repo, leaving unrelated Hyprland settings alone.
printf '\n// local customization\n' >> "$XDG_CONFIG_HOME/xkb/symbols/us-altgr-spanish"
bash "$repo/setup.sh" --profile omarchy --save-keyboard
cmp "$repo/config/xkb/symbols/us-altgr-spanish" "$XDG_CONFIG_HOME/xkb/symbols/us-altgr-spanish"
cmp "$temporary/installed" "$XDG_CONFIG_HOME/hypr/input.lua"
printf 'uninstall\n' | bash "$repo/uninstall.sh" --keyboard
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/input.lua"
[[ -f "$XDG_CONFIG_HOME/xkb/symbols/us-altgr-spanish" ]]
# Damaged markers and validation errors are not silently accepted.
printf '%s\n' '-- >>> dotfiles keyboard >>>' 'user content' > "$XDG_CONFIG_HOME/hypr/input.lua"
cp "$XDG_CONFIG_HOME/hypr/input.lua" "$temporary/damaged"
if bash "$repo/setup/keyboard.sh" install >/dev/null 2>&1; then exit 1; fi
cmp "$temporary/damaged" "$XDG_CONFIG_HOME/hypr/input.lua"
cp "$temporary/original" "$XDG_CONFIG_HOME/hypr/input.lua"
if KEYBOARD_ERRORS=true bash "$repo/setup/keyboard.sh" install >/dev/null 2>&1; then exit 1; fi
if XDG_CONFIG_HOME=relative bash "$repo/setup/keyboard.sh" save >/dev/null 2>&1; then exit 1; fi
if command -v luac >/dev/null 2>&1; then
    luac -p "$REPO_ROOT/config/hypr/keyboard.lua"
fi
printf 'ok - saved keyboard install, save, removal, XDG paths, reload and validation\n'
