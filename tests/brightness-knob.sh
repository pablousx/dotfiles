#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home"
export XDG_CONFIG_HOME="$HOME/custom config"
export HYPRLAND_INSTANCE_SIGNATURE=brightness-test
export BRIGHTNESS_HYPR_CALLS="$temporary/hypr-calls"
export BRIGHTNESS_OMARCHY_CALLS="$temporary/omarchy-calls"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$temporary/bin" "$temporary/repo"
repo="$temporary/repo"
cp -R "$REPO_ROOT/setup" "$REPO_ROOT/config" "$REPO_ROOT/profiles" "$repo/"
cp "$REPO_ROOT/setup.sh" "$REPO_ROOT/uninstall.sh" "$repo/"
# shellcheck source=tests/fixtures/platform.sh
source "$REPO_ROOT/tests/fixtures/platform.sh"
install_platform_fixture "$repo" "$temporary"

cat > "$temporary/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == "monitors -j" ]]; then
    printf '%s\n' '[{"name":"DP-1","disabled":false},{"name":"HDMI-A-1","disabled":false},{"name":"DP-9","disabled":true}]'
else
    printf '%s\n' "$*" >> "$BRIGHTNESS_HYPR_CALLS"
    [[ "$1" != configerrors || ${BRIGHTNESS_ERRORS:-false} != true ]] ||
        printf 'fixture error\n'
fi
MOCK
cat > "$temporary/bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BRIGHTNESS_OMARCHY_CALLS"
[[ "${FAIL_MONITOR:-}" != "$4" ]]
MOCK
chmod +x "$temporary/bin/hyprctl" "$temporary/bin/omarchy"
export PATH="$temporary/bin:$PATH"

printf '%s\n' 'require("hypr.bindings")' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf '%s\n' '-- user bindings' 'o.bind("SUPER + T", "Terminal", "alacritty")' > "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/original"

bash "$repo/setup/brightness-knob.sh" skip "$repo"
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]
"$repo/setup.sh" --profile omarchy --help | grep -q -- '--brightness-knob'

# Cancelling after selecting the component must leave both targets untouched.
printf 'n\nn\n\ny\ny\ny\ny\ny\nn\n' |
    bash "$repo/setup.sh" --profile omarchy >/dev/null 2>&1 && exit 1
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]

# Interactive Omarchy setup exposes the component and installs it after consent.
printf 'n\nn\n\ny\ny\ny\ny\ny\ny\n' |
    bash "$repo/setup.sh" --profile omarchy >/dev/null 2>&1
grep -Fxq -- '-- >>> dotfiles brightness knob >>>' "$XDG_CONFIG_HOME/hypr/bindings.lua"
grep -Fq 'o.bind("SUPER + T"' "$XDG_CONFIG_HOME/hypr/bindings.lua"
cmp "$repo/profiles/omarchy/config/omarchy/bin/omarchy-brightness-all" \
    "$HOME/.local/bin/omarchy-brightness-all"
[[ -x "$HOME/.local/bin/omarchy-brightness-all" ]]
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/installed"

# Explicit setup is idempotent and creates only the initial bindings backup.
bash "$repo/setup.sh" --profile omarchy --brightness-knob >/dev/null
cmp "$temporary/installed" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ $(grep -Fxc -- '-- >>> dotfiles brightness knob >>>' "$XDG_CONFIG_HOME/hypr/bindings.lua") -eq 1 ]]
[[ $(find "$XDG_CONFIG_HOME/hypr" -name '*.dotfiles-backup.*' | wc -l) -eq 1 ]]
printf 'reload\nconfigerrors\nreload\nconfigerrors\n' > "$temporary/expected-hypr-calls"
cmp "$temporary/expected-hypr-calls" "$BRIGHTNESS_HYPR_CALLS"

# The installed helper targets every active monitor exactly once with the given step.
"$HOME/.local/bin/omarchy-brightness-all" 10%-
printf '%s\n' 'brightness display --monitor DP-1 10%-' 'brightness display --monitor HDMI-A-1 10%-' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"
cp "$BRIGHTNESS_OMARCHY_CALLS" "$temporary/calls-before-invalid"
if "$HOME/.local/bin/omarchy-brightness-all" bad-step >/dev/null 2>&1; then
    exit 1
fi
if "$HOME/.local/bin/omarchy-brightness-all" +10junk% >/dev/null 2>&1; then
    exit 1
fi
cmp "$temporary/calls-before-invalid" "$BRIGHTNESS_OMARCHY_CALLS"
if FAIL_MONITOR=HDMI-A-1 "$HOME/.local/bin/omarchy-brightness-all" +10%; then
    exit 1
fi

# Removal strips only the managed block and removes an unmodified helper.
printf 'uninstall\n' | bash "$repo/uninstall.sh" --brightness-knob >/dev/null
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]

# A user-modified helper is retained, while the bindings block is still removable.
bash "$repo/setup.sh" --profile omarchy --brightness-knob >/dev/null
printf '%s\n' '# local customization' >> "$HOME/.local/bin/omarchy-brightness-all"
bash "$repo/setup/brightness-knob.sh" remove "$repo" >/dev/null
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
grep -Fq '# local customization' "$HOME/.local/bin/omarchy-brightness-all"

# Damaged markers and compositor validation errors are never silently accepted.
printf '%s\n' '-- >>> dotfiles brightness knob >>>' 'user content' > "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/damaged"
if bash "$repo/setup/brightness-knob.sh" install "$repo" >/dev/null 2>&1; then
    exit 1
fi
cmp "$temporary/damaged" "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
if BRIGHTNESS_ERRORS=true bash "$repo/setup/brightness-knob.sh" install "$repo" >/dev/null 2>&1; then
    exit 1
fi
if XDG_CONFIG_HOME=relative bash "$repo/setup/brightness-knob.sh" install "$repo" >/dev/null 2>&1; then
    exit 1
fi

if command -v luac >/dev/null 2>&1; then
    luac -p "$REPO_ROOT/profiles/omarchy/config/hypr/brightness-knob.lua"
fi
printf 'ok - prompted all-monitor brightness install, runtime, removal and validation\n'
