#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
# macOS temporary paths may contain symlinks; match installer physical paths.
temporary="$(cd "$temporary" && pwd -P)"
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home"
export XDG_CONFIG_HOME="$HOME/custom config"
export XDG_STATE_HOME="$HOME/custom state"
export XDG_RUNTIME_DIR="$temporary/runtime"
export HYPRLAND_INSTANCE_SIGNATURE=brightness-test
export BRIGHTNESS_HYPR_CALLS="$temporary/hypr-calls"
export BRIGHTNESS_OMARCHY_CALLS="$temporary/omarchy-calls"
export BRIGHTNESS_SYSTEMCTL_CALLS="$temporary/systemctl-calls"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_RUNTIME_DIR" "$temporary/bin" "$temporary/repo"
repo="$temporary/repo"
cp -R "$REPO_ROOT/setup" "$REPO_ROOT/config" "$REPO_ROOT/profiles" "$repo/"
cp "$REPO_ROOT/setup.sh" "$REPO_ROOT/uninstall.sh" "$repo/"
# shellcheck source=tests/fixtures/platform.sh
source "$REPO_ROOT/tests/fixtures/platform.sh"
install_platform_fixture "$repo" "$temporary"

cat > "$temporary/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == "monitors -j" ]]; then
    printf '%s\n' '[{"name":"DP-1","disabled":false,"dpmsStatus":true},{"name":"HDMI-A-1","disabled":false,"dpmsStatus":true},{"name":"DP-9","disabled":true,"dpmsStatus":false}]'
else
    printf '%s\n' "$*" >> "$BRIGHTNESS_HYPR_CALLS"
    [[ "$1" != configerrors || ${BRIGHTNESS_ERRORS:-false} != true ]] ||
        printf 'fixture error\n'
fi
MOCK
cat > "$temporary/bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BRIGHTNESS_OMARCHY_CALLS"
if [[ "$*" == "brightness display --monitor "* ]]; then
    [[ "${FAIL_READ_MONITOR:-}" != "$4" ]] || exit 1
    printf '%s\n' "${CURRENT_BRIGHTNESS:-50}"
elif [[ "$*" == "brightness display --no-osd --monitor "* ]]; then
    if [[ -n "${SLOW_MONITOR:-}" && "$5" == "$SLOW_MONITOR" && "$6" == "${SLOW_TARGET:-}" ]]; then
        : > "$SLOW_MARKER"
        sleep 0.2
    fi
    [[ "${FAIL_MONITOR:-}" != "$5" ]]
fi
MOCK
cat > "$temporary/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BRIGHTNESS_SYSTEMCTL_CALLS"
MOCK
chmod +x "$temporary/bin/hyprctl" "$temporary/bin/omarchy"
chmod +x "$temporary/bin/systemctl"
export PATH="$temporary/bin:$PATH"

printf '%s\n' 'require("hypr.bindings")' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf '%s\n' '-- user bindings' 'o.bind("SUPER + T", "Terminal", "alacritty")' > "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/original"

bash "$repo/setup/brightness-knob.sh" skip "$repo"
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]
"$repo/setup.sh" --profile omarchy --help | grep -q -- '--brightness-knob'

# Cancelling after selecting the component must leave both targets untouched.
printf 'n\nn\nn\n\ny\nn\nn\ny\ny\ny\ny\nn\n' |
    bash "$repo/setup.sh" --profile omarchy >/dev/null 2>&1 && exit 1
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]

# Interactive Omarchy setup exposes the component and installs it after consent.
printf 'n\nn\nn\n\ny\nn\nn\ny\ny\ny\ny\ny\n' |
    bash "$repo/setup.sh" --profile omarchy >/dev/null 2>&1
grep -Fxq -- '-- >>> dotfiles brightness knob >>>' "$XDG_CONFIG_HOME/hypr/bindings.lua"
grep -Fq 'o.bind("SUPER + T"' "$XDG_CONFIG_HOME/hypr/bindings.lua"
cmp "$repo/profiles/omarchy/config/omarchy/bin/omarchy-brightness-all" \
    "$HOME/.local/bin/omarchy-brightness-all"
[[ -x "$HOME/.local/bin/omarchy-brightness-all" ]]
cmp "$repo/profiles/omarchy/config/omarchy/bin/omarchy-brightness-restore" \
    "$HOME/.local/bin/omarchy-brightness-restore"
[[ -x "$HOME/.local/bin/omarchy-brightness-restore" ]]
cmp "$repo/profiles/omarchy/config/systemd/user/omarchy-brightness-restore.service" \
    "$XDG_CONFIG_HOME/systemd/user/omarchy-brightness-restore.service"
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/installed"

# Refreshing an existing managed block preserves user content after the block.
printf '%s\n' '-- trailing user include' >> "$XDG_CONFIG_HOME/hypr/bindings.lua"
cp "$XDG_CONFIG_HOME/hypr/bindings.lua" "$temporary/installed"

# Explicit setup is idempotent and creates only the initial bindings backup.
bash "$repo/setup.sh" --profile omarchy --brightness-knob >/dev/null
cmp "$temporary/installed" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ $(grep -Fxc -- '-- >>> dotfiles brightness knob >>>' "$XDG_CONFIG_HOME/hypr/bindings.lua") -eq 1 ]]
[[ $(find "$XDG_CONFIG_HOME/hypr" -name '*.dotfiles-backup.*' | wc -l) -eq 1 ]]
awk '$0 != "-- trailing user include"' "$XDG_CONFIG_HOME/hypr/bindings.lua" > "$temporary/without-tail"
cp "$temporary/without-tail" "$XDG_CONFIG_HOME/hypr/bindings.lua"
printf 'reload\nconfigerrors\nreload\nconfigerrors\n' > "$temporary/expected-hypr-calls"
cmp "$temporary/expected-hypr-calls" "$BRIGHTNESS_HYPR_CALLS"

# The installed helper derives one target and publishes it to the OSD before
# potentially slow monitor I/O, then applies it silently to every active monitor.
"$HOME/.local/bin/omarchy-brightness-all" 10%-
printf '%s\n' \
    'brightness display --monitor DP-1' \
    'osd -i brightness -p 40' \
    'brightness display --no-osd --monitor DP-1 40%' \
    'brightness display --no-osd --monitor HDMI-A-1 40%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"

# The 1% safety floor joins the regular grid on the next upward step, instead
# of producing 11%, and both displays still receive one identical target.
: > "$BRIGHTNESS_OMARCHY_CALLS"
CURRENT_BRIGHTNESS=1 "$HOME/.local/bin/omarchy-brightness-all" +10%
printf '%s\n' \
    'brightness display --monitor DP-1' \
    'osd -i brightness -p 10' \
    'brightness display --no-osd --monitor DP-1 10%' \
    'brightness display --no-osd --monitor HDMI-A-1 10%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"

# A downward step that arithmetically reaches zero still clamps and applies the
# supported 1% floor; errexit must not mistake an arithmetic zero for failure.
: > "$BRIGHTNESS_OMARCHY_CALLS"
CURRENT_BRIGHTNESS=10 "$HOME/.local/bin/omarchy-brightness-all" 10%-
printf '%s\n' \
    'brightness display --monitor DP-1' \
    'osd -i brightness -p 1' \
    'brightness display --no-osd --monitor DP-1 1%' \
    'brightness display --no-osd --monitor HDMI-A-1 1%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"

# Turns received during slow monitor I/O are coalesced rather than discarded.
# The worker performs one serialized +10% pass, then one combined +20% pass.
: > "$BRIGHTNESS_OMARCHY_CALLS"
slow_marker="$temporary/slow-brightness-write"
SLOW_MONITOR=DP-1 SLOW_TARGET=60% SLOW_MARKER="$slow_marker" \
    "$HOME/.local/bin/omarchy-brightness-all" +10% &
brightness_worker=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [[ -e "$slow_marker" ]] && break
    sleep 0.01
done
[[ -e "$slow_marker" ]]
"$HOME/.local/bin/omarchy-brightness-all" +10%
"$HOME/.local/bin/omarchy-brightness-all" +10%
wait "$brightness_worker"
printf '%s\n' \
    'brightness display --monitor DP-1' \
    'osd -i brightness -p 60' \
    'brightness display --no-osd --monitor DP-1 60%' \
    'brightness display --no-osd --monitor HDMI-A-1 60%' \
    'osd -i brightness -p 80' \
    'brightness display --no-osd --monitor DP-1 80%' \
    'brightness display --no-osd --monitor HDMI-A-1 80%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"
[[ "$(cat "$XDG_STATE_HOME/dotfiles/brightness-all")" == 80 ]]

# Persistence can also capture the current focused hardware value, and a
# silent restore applies the saved target to every active, powered display.
: > "$BRIGHTNESS_OMARCHY_CALLS"
CURRENT_BRIGHTNESS=35 "$HOME/.local/bin/omarchy-brightness-restore" capture
[[ "$(cat "$XDG_STATE_HOME/dotfiles/brightness-all")" == 35 ]]
OMARCHY_BRIGHTNESS_RESTORE_ATTEMPTS=1 OMARCHY_BRIGHTNESS_RESTORE_RETRY_DELAY=0 \
    "$HOME/.local/bin/omarchy-brightness-restore" once
printf '%s\n' \
    'brightness display --monitor DP-1' \
    'brightness display --no-osd --monitor DP-1 35%' \
    'brightness display --no-osd --monitor HDMI-A-1 35%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"

# A turn received while the restore worker owns the hardware lock is handed
# off after restore, rather than remaining stranded in the runtime queue.
: > "$BRIGHTNESS_OMARCHY_CALLS"
printf '35\n' > "$XDG_STATE_HOME/dotfiles/brightness-all"
slow_marker="$temporary/slow-brightness-restore"
SLOW_MONITOR=DP-1 SLOW_TARGET=35% SLOW_MARKER="$slow_marker" \
    CURRENT_BRIGHTNESS=35 OMARCHY_BRIGHTNESS_RESTORE_ATTEMPTS=1 \
    OMARCHY_BRIGHTNESS_RESTORE_RETRY_DELAY=0 \
    "$HOME/.local/bin/omarchy-brightness-restore" once &
restore_worker=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [[ -e "$slow_marker" ]] && break
    sleep 0.01
done
[[ -e "$slow_marker" ]]
"$HOME/.local/bin/omarchy-brightness-all" +10%
wait "$restore_worker"
printf '%s\n' \
    'brightness display --no-osd --monitor DP-1 35%' \
    'brightness display --no-osd --monitor HDMI-A-1 35%' \
    'brightness display --monitor DP-1' \
    'osd -i brightness -p 45' \
    'brightness display --no-osd --monitor DP-1 45%' \
    'brightness display --no-osd --monitor HDMI-A-1 45%' > "$temporary/expected-omarchy-calls"
cmp "$temporary/expected-omarchy-calls" "$BRIGHTNESS_OMARCHY_CALLS"
[[ "$(cat "$XDG_RUNTIME_DIR/omarchy-brightness-all.queue")" == 0 ]]
[[ "$(cat "$XDG_STATE_HOME/dotfiles/brightness-all")" == 45 ]]

cp "$BRIGHTNESS_OMARCHY_CALLS" "$temporary/calls-before-invalid"
if "$HOME/.local/bin/omarchy-brightness-all" bad-step >/dev/null 2>&1; then
    exit 1
fi
if "$HOME/.local/bin/omarchy-brightness-all" +10junk% >/dev/null 2>&1; then
    exit 1
fi
if "$HOME/.local/bin/omarchy-brightness-all" +0% >/dev/null 2>&1; then
    exit 1
fi
cmp "$temporary/calls-before-invalid" "$BRIGHTNESS_OMARCHY_CALLS"
state_before_failure="$(cat "$XDG_STATE_HOME/dotfiles/brightness-all")"
if FAIL_MONITOR=HDMI-A-1 "$HOME/.local/bin/omarchy-brightness-all" +10%; then
    exit 1
fi
[[ "$(cat "$XDG_STATE_HOME/dotfiles/brightness-all")" == "$state_before_failure" ]]

# Removal strips only the managed block and removes unmodified helpers/service.
printf 'uninstall\n' | bash "$repo/uninstall.sh" --brightness-knob >/dev/null
cmp "$temporary/original" "$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ ! -e "$HOME/.local/bin/omarchy-brightness-all" ]]
[[ ! -e "$HOME/.local/bin/omarchy-brightness-restore" ]]
[[ ! -e "$XDG_CONFIG_HOME/systemd/user/omarchy-brightness-restore.service" ]]
grep -Fxq -- '--user disable --now omarchy-brightness-restore.service' "$BRIGHTNESS_SYSTEMCTL_CALLS"

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
