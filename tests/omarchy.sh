#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
# macOS temporary paths may contain symlinks; match installer physical paths.
TEMP_ROOT="$(cd "$TEMP_ROOT" && pwd -P)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
export HOME="$TEMP_ROOT/home"
unset STARSHIP_CONFIG
mkdir -p "$HOME" "$TEMP_ROOT/repo space" "$TEMP_ROOT/bin"
repo="$TEMP_ROOT/repo space"
cp -R "$REPO_ROOT/setup" "$REPO_ROOT/modules" "$REPO_ROOT/config" \
    "$REPO_ROOT/profiles" "$REPO_ROOT/shared" "$REPO_ROOT/tests" "$repo/"
cp "$REPO_ROOT/setup.sh" "$REPO_ROOT/uninstall.sh" "$repo/"
# shellcheck source=tests/fixtures/platform.sh
source "$REPO_ROOT/tests/fixtures/platform.sh"
install_platform_fixture "$repo" "$TEMP_ROOT"
printf 'DISABLE_ALIASES=true\n' > "$repo/.env"
printf '# user content\nalias personal=true\n' > "$HOME/.bashrc"
printf '# login profile content\nexport LOGIN_MARKER=true\n' > "$HOME/.bash_profile"
cp "$HOME/.bashrc" "$TEMP_ROOT/original"
cp "$HOME/.bash_profile" "$TEMP_ROOT/original-profile"

bash "$repo/setup/bash-startup.sh" skip "$repo"
cmp "$TEMP_ROOT/original" "$HOME/.bashrc"
cmp "$TEMP_ROOT/original-profile" "$HOME/.bash_profile"
bash "$repo/setup/bash-startup.sh" install "$repo"
cp "$HOME/.bashrc" "$TEMP_ROOT/installed"
cp "$HOME/.bash_profile" "$TEMP_ROOT/installed-profile"
bash "$repo/setup/bash-startup.sh" install "$repo"
cmp "$TEMP_ROOT/installed" "$HOME/.bashrc"
cmp "$TEMP_ROOT/installed-profile" "$HOME/.bash_profile"
[[ $(find "$HOME" -name '.bashrc.dotfiles-backup.*' | wc -l) -eq 1 ]]
[[ $(find "$HOME" -name '.bash_profile.dotfiles-backup.*' | wc -l) -eq 1 ]]
grep -q 'alias personal=true' "$HOME/.bashrc"
grep -q 'environment.bash' "$HOME/.bash_profile"
[[ $(bash --noprofile --norc -c 'source "$HOME/.bash_profile"; printf "%s" "$SWC_NATIVE_BINDING_CACHE"') == "$HOME/.cache/swc-native" ]]
printf 'uninstall\n' | bash "$repo/uninstall.sh" --omarchy
cmp "$TEMP_ROOT/original" "$HOME/.bashrc"
cmp "$TEMP_ROOT/original-profile" "$HOME/.bash_profile"
# Preserve symlink ownership and file mode through install/removal.
mv "$HOME/.bashrc" "$HOME/bashrc-target"
chmod 0600 "$HOME/bashrc-target"
ln -s "$HOME/bashrc-target" "$HOME/.bashrc"
bash "$repo/setup/bash-startup.sh" install "$repo" >/dev/null
[[ -L "$HOME/.bashrc" ]]
bash "$repo/setup/bash-startup.sh" remove "$repo" >/dev/null
cmp "$TEMP_ROOT/original" "$HOME/bashrc-target"
[[ $(ls -l "$HOME/bashrc-target") == -rw-------* ]]
rm "$HOME/.bashrc"
mv "$HOME/bashrc-target" "$HOME/.bashrc"
# Preserve the selected login profile's symlink and mode through install/removal.
mv "$HOME/.bash_profile" "$HOME/bash-profile-target"
chmod 0600 "$HOME/bash-profile-target"
ln -s "$HOME/bash-profile-target" "$HOME/.bash_profile"
bash "$repo/setup/bash-startup.sh" install "$repo" >/dev/null
[[ -L "$HOME/.bash_profile" ]]
bash "$repo/setup/bash-startup.sh" remove "$repo" >/dev/null
cmp "$TEMP_ROOT/original-profile" "$HOME/bash-profile-target"
[[ $(ls -l "$HOME/bash-profile-target") == -rw-------* ]]
rm "$HOME/.bash_profile"
mv "$HOME/bash-profile-target" "$HOME/.bash_profile"
# Fall back to .profile when no Bash-specific login profile exists.
mv "$HOME/.bash_profile" "$HOME/bash-profile-saved"
printf '# portable login profile\n' > "$HOME/.profile"
cp "$HOME/.profile" "$TEMP_ROOT/original-dot-profile"
bash "$repo/setup/bash-startup.sh" install "$repo" >/dev/null
[[ ! -e "$HOME/.bash_profile" ]]
grep -q 'environment.bash' "$HOME/.profile"
[[ $(sh -c '. "$HOME/.profile"; printf "%s" "$SWC_NATIVE_BINDING_CACHE"') == "$HOME/.cache/swc-native" ]]
bash "$repo/setup/bash-startup.sh" remove "$repo" >/dev/null
cmp "$TEMP_ROOT/original-dot-profile" "$HOME/.profile"
rm "$HOME/.profile"
mv "$HOME/bash-profile-saved" "$HOME/.bash_profile"
# Malformed blocks must not swallow unrelated user content.
printf '# >>> dotfiles omarchy >>>\nuser-data\n' > "$HOME/.bashrc"
cp "$HOME/.bashrc" "$TEMP_ROOT/damaged"
if bash "$repo/setup/bash-startup.sh" install "$repo" 2>/dev/null; then exit 1; fi
cmp "$TEMP_ROOT/damaged" "$HOME/.bashrc"
cp "$TEMP_ROOT/original" "$HOME/.bashrc"
printf '# >>> dotfiles omarchy environment >>>\nuser-data\n' > "$HOME/.bash_profile"
cp "$HOME/.bash_profile" "$TEMP_ROOT/damaged-profile"
if bash "$repo/setup/bash-startup.sh" install "$repo" 2>/dev/null; then exit 1; fi
cmp "$TEMP_ROOT/original" "$HOME/.bashrc"
cmp "$TEMP_ROOT/damaged-profile" "$HOME/.bash_profile"
cp "$TEMP_ROOT/original-profile" "$HOME/.bash_profile"

# Mock package and tool installation separately.
cat > "$TEMP_ROOT/bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALL_LOG"
MOCK
for tool in chsh mise pacman sudo git curl zsh; do
    # The generated mock expands CALL_LOG when executed.
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\nprintf "forbidden: %%s\\n" "%s" >> "$CALL_LOG"\nexit 99\n' "$tool" > "$TEMP_ROOT/bin/$tool"
done
chmod +x "$TEMP_ROOT/bin/"*
export CALL_LOG="$TEMP_ROOT/calls"
# Mise tool installation is mocked separately from the system package manager.
cat > "$repo/setup/tools.sh" <<'MOCK'
[[ "$1" == install ]] || exit 0
printf 'tools %s\n'  "$1" >> "$CALL_LOG"
MOCK
PATH="$TEMP_ROOT/bin:$PATH" bash "$repo/setup.sh" --profile omarchy --all --disable-prompt
[[ $(cat "$CALL_LOG") == $'pkg add git curl bash-completion unzip xz wl-clipboard\ntools install' ]]
grep -qx 'DISABLE_PROMPT=true' "$repo/.env.omarchy"
grep -qx 'DISABLE_ALIASES=true' "$repo/.env"
if bash "$repo/setup.sh" --profile omarchy --zsh >/dev/null 2>&1; then exit 1; fi
if bash "$repo/setup.sh" --profile wrong >/dev/null 2>&1; then exit 1; fi
if bash "$repo/setup.sh" --profile >/dev/null 2>&1; then exit 1; fi
# EOF must abort rather than select defaults and perform changes.
cp "$HOME/.bashrc" "$TEMP_ROOT/before-eof"
cp "$CALL_LOG" "$TEMP_ROOT/calls-before-eof"
if PATH="$TEMP_ROOT/bin:$PATH" bash "$repo/setup.sh" --profile omarchy < /dev/null >/dev/null 2>&1; then exit 1; fi
cmp "$TEMP_ROOT/before-eof" "$HOME/.bashrc"
cmp "$TEMP_ROOT/calls-before-eof" "$CALL_LOG"
# Cancelled interactive changes preserve both startup and settings.
cp "$repo/.env.omarchy" "$TEMP_ROOT/settings"
cp "$HOME/.bashrc" "$TEMP_ROOT/installed"
printf 'n\nn\nn\nNone\nn\nn\nn\ny\ny\ny\ny\nn\n' > "$TEMP_ROOT/input"
if bash "$repo/setup.sh" --profile omarchy < "$TEMP_ROOT/input" >/dev/null 2>&1; then exit 1; fi
cmp "$TEMP_ROOT/settings" "$repo/.env.omarchy"
cmp "$TEMP_ROOT/installed" "$HOME/.bashrc"
# Zero-argument profile discovery; declining both components still permits explicit settings.
mkdir -p "$TEMP_ROOT/omarchy/default/bash"
touch "$TEMP_ROOT/omarchy/default/bash/rc"
printf 'n\nn\nn\n\nn\nn\nn\ny\ny\ny\ny\ny\n' > "$TEMP_ROOT/input"
OMARCHY_PATH="$TEMP_ROOT/omarchy" bash "$repo/setup.sh" < "$TEMP_ROOT/input" >/dev/null
cmp "$TEMP_ROOT/installed" "$HOME/.bashrc"

# Bash runtime needs Bash 5 on Omarchy; macOS installer syntax remains Bash 3.2.
if (( BASH_VERSINFO[0] < 5 )); then
    printf 'skip - Omarchy runtime requires Bash 5 (covered by Arch CI)\n'
    exit 0
fi
export TEST_REPO="$repo"
# Source a block from a path containing shell metacharacters, without evaluation.
quoted_repo="$TEMP_ROOT/repo \$(not-a-command) 'quoted'"
cp -R "$repo" "$quoted_repo"
bash "$repo/setup/bash-startup.sh" install "$quoted_repo" >/dev/null
EXPECTED_REPO="$quoted_repo" bash --noprofile --norc -i -c 'source "$HOME/.bashrc"; [[ "$DOTFILES_DIR" == "$EXPECTED_REPO" ]]' \
    2> "$TEMP_ROOT/quoted-errors"

# Noninteractive sourcing is silent and leaves all interactive state alone.
bash --noprofile --norc -c 'source "$TEST_REPO/modules/bash/rc.bash"; [[ ! -v _DOTFILES_BASH_LOADED ]]'
cat > "$TEMP_ROOT/runtime.bash" <<'RUNTIME'
set -e
source "$TEST_REPO/tests/fixtures/omarchy-4.0.0-alpha.bash"
source "$TEST_REPO/modules/bash/rc.bash"
[[ $OMARCHY_FIXTURE_LOADS == 1 ]]
[[ $(alias c) == "alias c='opencode --auto'" ]]
[[ $(alias cx) == "alias cx='claude --permission-mode auto'" ]]
[[ $(alias df-cx) == "alias df-cx='_dotfiles_helper up'" ]]
[[ $(open hello) == omarchy-open:hello ]]
[[ $(alias df-pni) == "alias df-pni='pnpm install'" ]]
pnpm() { printf '<%s>\n' "$@"; }
[[ $(df-pni 'package with spaces' '--save-dev') == $'<install>\n<package with spaces>\n<--save-dev>' ]]
unset -f pnpm
[[ $(complete -p npm) == *'_omarchy_fixture_complete npm' ]]
[[ $(complete -p omarchy) == *'_omarchy_fixture_complete omarchy' ]]
[[ $PROMPT_COMMAND == *': mise; : starship'* ]]
[[ ${PROMPT_COMMAND[1]} == _dotfiles_history_sync ]]
[[ $STARSHIP_CONFIG == "$TEST_REPO/profiles/omarchy/config/starship-omarchy.toml" ]]
before="${PROMPT_COMMAND[*]}"
source "$TEST_REPO/modules/bash/rc.bash"
[[ $before == "${PROMPT_COMMAND[*]}" ]]
[[ $HISTCONTROL == ignoreboth && $HISTSIZE == 32768 ]]
[[ $(df-urlencode 'a b&c') == 'a%20b%26c' ]]
[[ $(df-d64 'aGVsbG8=') == hello ]]
[[ $(df-urldecode_json '"hello"') == hello ]]
if df-is_json '{broken}' 2>/dev/null; then exit 1; fi
mkdir -p "$HOME/project space"
cd "$HOME/project space"
printf '%s\n' '{"scripts":{"build":"echo yes","bad;touch-pwned":"echo no"}}' > package.json
COMP_WORDS=(df-run npm b); COMP_CWORD=2
_dotfiles_scripts_complete
[[ ${COMPREPLY[0]} == build && ${COMPREPLY[1]} == 'bad;touch-pwned' ]]
[[ ! -f touch-pwned ]]
HISTFILE="$HOME/bash-history"
history -s 'echo shared-history'
_dotfiles_history_sync
[[ -s $HISTFILE ]]
RUNTIME
bash --noprofile --norc -i "$TEMP_ROOT/runtime.bash" 2> "$TEMP_ROOT/runtime-errors"
# Runtime stderr should contain only no-PTY Bash job-control notices.
if grep -vE 'cannot set terminal process group|no job control in this shell' "$TEMP_ROOT/runtime-errors" | grep -q .; then
    cat "$TEMP_ROOT/runtime-errors" >&2; exit 1
fi
cat > "$TEMP_ROOT/overrides.bash" <<'RUNTIME'
set -e
PROMPT_COMMAND=(': first' ': second')
source "$TEST_REPO/modules/bash/rc.bash"
[[ $STARSHIP_CONFIG == /explicit/user.toml ]]
[[ ${PROMPT_COMMAND[0]} == ': first' && ${PROMPT_COMMAND[2]} == _dotfiles_history_sync ]]
! alias df-ni &>/dev/null
RUNTIME
STARSHIP_CONFIG=/explicit/user.toml DISABLE_ALIASES=true bash --noprofile --norc -i "$TEMP_ROOT/overrides.bash" 2>/dev/null
# Explicitly empty environment values remain protected from persisted settings.
STARSHIP_CONFIG='' DISABLE_ALIASES='' bash --noprofile --norc -ic 'source "$TEST_REPO/modules/bash/rc.bash"; [[ -v STARSHIP_CONFIG && -z $STARSHIP_CONFIG && $DISABLE_ALIASES == true ]]' 2>/dev/null
# Deliberate unevaluated payload to verify the settings parser.
# shellcheck disable=SC2016
printf 'DISABLE_ALIASES=$(touch malicious)\nDISABLE_PROMPT=true\nUNKNOWN=true\n' > "$repo/.env.omarchy"
DISABLE_ALIASES=false bash --noprofile --norc -ic 'source "$TEST_REPO/modules/bash/rc.bash"; alias df-ni >/dev/null; [[ ! -v STARSHIP_CONFIG ]]' 2>/dev/null
[[ ! -f malicious ]]
printf 'ok - Omarchy setup, preservation, runtime, completion, history, and helpers\n'
