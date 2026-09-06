# Dotfiles

A modular Zsh environment for macOS, Linux, and WSL, with an additional
Omarchy/Bash profile. Zsh uses Powerlevel10k, Antidote, cached completions,
and FNM. Omarchy keeps stock Bash, fzf, mise, and its existing integrations,
adding shared helpers and a two-line Starship prompt.

> [!TIP]
> **Using native Windows terminals?**
>
> See [`winfiles`](https://github.com/pablousx/winfiles) for the PowerShell-based
> counterpart to this macOS, Linux, and WSL configuration.

## Installation

Clone the repository anywhere; setup records the actual checkout path.

```sh
git clone https://github.com/pablousx/dotfiles.git
cd dotfiles
./setup.sh
```

The interactive installer only installs selected components. Answering “no”
leaves the existing system untouched.

The normal workflow is simply:

```sh
./setup.sh
```

It detects your distribution and selects the matching shell profile automatically
(Omarchy/Bash on Omarchy, Zsh on other supported platforms).
For Zsh it prompts for each installation component, all five shell-module settings,
shows a final summary, and asks for confirmation before changing anything.
Advanced non-interactive flags remain available through `./setup.sh --help`,
but they are not needed for normal setup.

The default Node.js version is `24.12.0`. Override pinned tool versions when
needed:

```sh
NODE_VERSION=24.12.0 FNM_VERSION=1.39.0 ./setup.sh --fnm
```

Homebrew must already be installed for core setup on macOS. Linux detection reads
`ID` and `ID_LIKE` from `/etc/os-release` (or `/usr/lib/os-release` when needed),
without executing its contents. WSL follows its installed Linux distribution.

| Detected platform or family | Default profile | Package manager |
| --- | --- | --- |
| Omarchy | Omarchy/Bash | Omarchy package commands (Pacman) |
| Debian / Ubuntu | Zsh | APT |
| Fedora / RHEL / CentOS / Rocky / AlmaLinux | Zsh | DNF |
| Arch and compatible derivatives | Zsh | Pacman |
| openSUSE / SUSE | Zsh | Zypper |
| macOS | Zsh | Homebrew |

Derivatives match the first supported family in `ID_LIKE` when their own `ID`
is not recognized. Older Omarchy installs reporting Arch are recognized by the
Omarchy Bash defaults under `${OMARCHY_PATH:-/usr/share/omarchy}`. Package-manager
selection follows the distro; installing a different manager does not change it.

Unknown distributions, unsupported operating systems, and unreadable/invalid
distro metadata cause setup to exit with an error **before prompts or changes**.
Selecting `--profile omarchy` on another distribution also fails. A missing native
package manager fails when core installation is selected; there is no fallback
to whichever other manager happens to be on `PATH`. Help remains available.

`--profile auto` is the default, including for automation. Use `--profile zsh`
to explicitly configure Zsh on a supported platform, including Omarchy.

## Omarchy / Bash

Omarchy must already be installed. This profile targets Bash 5 and preserves
Omarchy's mise, zoxide, fzf, Bash completion, editor, and history configuration.
It adds no Zsh or FNM installation and never changes the login shell.

```sh
./setup.sh --profile omarchy       # Interactive setup and final confirmation
./setup.sh --profile omarchy --help
```

Advanced automation:

```sh
./setup.sh --profile omarchy --bash  # Only install the guarded startup block
./setup.sh --profile omarchy --core  # Helper dependencies via omarchy pkg add
./setup.sh --profile omarchy --brightness-knob
./setup.sh --profile omarchy --enable-prompt
./setup.sh --profile omarchy --disable-prompt  # Keep existing Omarchy prompt
./uninstall.sh --omarchy            # Confirm removal of the managed block
```

`--all` selects the shell components of the chosen profile. Keyboard and
brightness-knob setup are separate and opt-in. Without `--profile`,
noninteractive commands also use
the automatically detected profile. Existing automation that needs Zsh on
Omarchy must pass `--profile zsh` explicitly. The Omarchy profile rejects
Zsh-only flags such as `--fnm`, `--zsh`, and `--enable-plugins`.

Setup backs up `.bashrc` and appends a guarded block after existing configuration.
Repeated setup does not duplicate it. Keep subsequent personal overrides below
the block. The repository does not rewrite Omarchy's packaged defaults or your
Starship configuration. The uninstaller backs up `.bashrc` and removes only the
marked block; local settings remain. If an Omarchy refresh replaces `.bashrc`,
rerun `--profile omarchy --bash` to restore the integration.

Omarchy settings live in ignored `.env.omarchy`, independently of Zsh's `.env`:

| Variable | Setup options | Default |
| --- | --- | --- |
| `DISABLE_ALIASES` | `--enable-aliases` / `--disable-aliases` | `false` |
| `DISABLE_PROMPT` | `--enable-prompt` / `--disable-prompt` | `false` |
| `DISABLE_COMPLETIONS` | `--enable-completions` / `--disable-completions` | `false` |
| `DISABLE_HISTORY_SYNC` | `--enable-history-sync` / `--disable-history-sync` | `false` |

`--configure-modules` prompts for all four settings. Module questions explicitly
state that “no” disables an addition; declining an installation component leaves
it unchanged. Only literal `true` and `false` are valid. Runtime environment
variables win over the settings file. Invalid file entries are ignored; an
invalid environment boolean disables that addition. Settings are never evaluated
as shell code. Changes take effect in a new Bash session.

The default Starship preset lives in `config/starship-omarchy.toml`. It selects
`STARSHIP_CONFIG` only when you have not already supplied one; it does not
initialize Starship again. It displays directory/Git context, relevant runtime
and status information, and a second-line prompt, all on the left. Disabling
this option keeps Omarchy's existing prompt, rather than disabling Starship.
The pnpm segment reads the project's declared `packageManager` version from
`package.json`, including parent workspace directories. It never launches pnpm
or downloads a runtime to render the prompt. When a pnpm project has no declared
version, it shows `pnpm` without a version; this is project context, not a probe
of the installed executable.
Open a fresh terminal after changing prompt selection to discard an inherited
`STARSHIP_CONFIG` override.

Helpers preserve existing command names. Use the `df-` form when a name conflicts:

```sh
df-c                       # code -r; Omarchy's c remains untouched
df-cx                      # cd ..; Omarchy's cx remains untouched
df-dotfiles status
df-run pnpm build           # Tab completes scripts from package.json
bash-config / bash-aliases / bash-settings / bash-prompt
alias-show ni              # Inspect the alias instead of rewriting the input line
```

Editors are read from `EDITOR` as a command followed by whitespace-separated
options; shell expressions and quoting within `EDITOR` are not evaluated.
Optional tools are checked when invoked. Core setup installs Git, curl, Python,
Bash completion, unzip, and Wayland clipboard support through Omarchy; it leaves
Node versions and uncommon archive tools to your existing tool management.

See the [complete feature and plugin parity table](docs/omarchy-parity.md) for
command mappings and intentional differences, including live highlighting,
inline suggestions, Zsh global aliases, and fzf-tab previews.

## Saved Spanish AltGr keyboard

The repository includes your `us-altgr-spanish` XKB layout and its Hyprland Lua
settings (`kb_layout = "us-altgr-spanish"`, `kb_variant = "basic"`, empty keyboard
options). It keeps normal US typing and adds Right Alt combinations:

| Right Alt + key | Character | With Shift |
| --- | --- | --- |
| A / E / I / O / U | á / é / í / ó / ú | Á / É / Í / Ó / Ú |
| N / Y | ñ / ü | Ñ / Ü |
| 1 / slash | ¡ / ¿ | Same |
| 5 / 0 / minus | € / ° / — | Same |
| left / right bracket | « / » | Same |

```sh
./setup.sh --profile omarchy --keyboard       # Restore the saved layout
./setup.sh --profile omarchy --save-keyboard  # Save future local keymap edits
./uninstall.sh --keyboard                    # Remove only the managed activation
```

Interactive Omarchy setup asks for a keyboard configuration: **None** (the
default, which leaves the current configuration unchanged) or **US with Spanish
AltGr**. Press Enter to keep the keyboard unchanged; `--all` still selects only shell components.
Keyboard installation requires the existing Omarchy `hyprland.lua` configuration.
It copies the saved symbols to `${XDG_CONFIG_HOME:-$HOME/.config}/xkb/symbols/`
and adds a marked block to `hypr/input.lua`, preserving other input settings and
backing up changed files. It uses `xkbcli` to validate the keymap when available,
then reloads and checks Hyprland when run from an active session.

`--save-keyboard` copies only the local `us-altgr-spanish` symbols file back to
`config/xkb/symbols/us-altgr-spanish`; it does not copy unrelated device settings
or commit changes. The associated activation preset is `config/hypr/keyboard.lua`.
Backups are ignored by Git. Removal deletes only the marked activation block;
any earlier keyboard settings, installed symbols, and repository copy remain.
No system XKB files or packaged Omarchy files are edited.

## All-monitor brightness knob

The optional Omarchy brightness component makes the standard monitor-brightness
keys adjust every active Hyprland display in 10% steps. This supports a macro
pad knob programmed to emit `XF86MonBrightnessDown` counter-clockwise and
`XF86MonBrightnessUp` clockwise:

```sh
./setup.sh --profile omarchy --brightness-knob
./uninstall.sh --brightness-knob
```

Zero-argument interactive Omarchy setup asks whether to enable this behavior
and defaults to **no**, which leaves existing bindings unchanged. Installation:

- copies the repository helper to `~/.local/bin/omarchy-brightness-all`;
- adds a marked block to `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua`;
- unbinds Omarchy's focused-display 5% brightness actions before installing the
  all-display 10% replacements; and
- backs up changed files, then reloads and validates Hyprland in a live session.

The helper discovers active displays on each invocation, so connector names are
not stored in the dotfiles. Omarchy handles internal panels with `brightnessctl`
and external monitors with `ddcutil`; external displays must have DDC/CI enabled
in their on-screen settings.

The macropad mapping is stored in the device's onboard memory and travels with
the keyboard. Setup deliberately does not flash USB hardware. If the device is
factory-reset or replaced, program its knob to emit the two standard brightness
keys before enabling this component.

Removal deletes only the marked bindings block. It removes the installed helper
only when its contents still match the repository, preserving local edits.

## Safe removal

Removal is deliberately separate from installation:

```sh
./uninstall.sh
```

The uninstaller asks which components to remove (including managed Omarchy,
keyboard, and brightness-knob blocks when present), defaults every answer to
“no,” shows the removal plan, and requires an explicit confirmation. It only
removes tool directories marked as created by this repository. It does not
remove system packages, Node projects, or committed repository files. The
explicit `--omarchy` option removes only its marked startup block after backup;
other startup content is preserved.

## Configuration layout

- `.zshrc` — main startup sequence, completion cache, history, and module loading
- `.zshenv` — login-shell settings installed through `~/.zshenv`
- `.p10k.zsh` — Powerlevel10k configuration
- `.env` — local feature flags copied from `.env.example`
- `modules/aliases.zsh` — local aliases and helper functions
- `modules/plugins.txt` — pinned Antidote plugin manifest
- `modules/plugins.zsh` — generated, committed plugin loader
- `modules/platform.zsh` — macOS and distribution-specific integrations
- `setup/` — component installers and shared platform helpers
- `profiles/omarchy/config/hypr/` — saved keyboard and brightness binding presets
- `profiles/omarchy/config/omarchy/bin/` — user-local Omarchy helper commands
- `tests/run.sh` — syntax and clean-startup smoke tests

Supported `.env` flags are:

```sh
DISABLE_ALIASES=false
DISABLE_PROMPT=false
DISABLE_PLUGINS=false
DISABLE_PRINT_ALIAS_COMPLETION=false
DISABLE_EXPAND_ALIAS=false
```

They correspond to these setup options:

| Environment variable | Enable option | Disable option |
| --- | --- | --- |
| `DISABLE_ALIASES` | `--enable-aliases` | `--disable-aliases` |
| `DISABLE_PROMPT` | `--enable-prompt` | `--disable-prompt` |
| `DISABLE_PLUGINS` | `--enable-plugins` | `--disable-plugins` |
| `DISABLE_PRINT_ALIAS_COMPLETION` | `--enable-print-alias-completion` | `--disable-print-alias-completion` |
| `DISABLE_EXPAND_ALIAS` | `--enable-expand-alias` | `--disable-expand-alias` |

Environment variables override `.env`, allowing temporary minimal shells:

```sh
DISABLE_PLUGINS=true DISABLE_PROMPT=true zsh
```

History is stored at `${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history`. The
old repository-local history is copied there automatically on first startup.

## Common commands

```sh
dotfiles status             # Run Git against this repository
bundle-plugins              # Regenerate the pinned plugin loader and restart
upload-dotfiles             # Commit tracked changes and push the current branch

ni / nd / nb / ns           # npm install/dev/build/start
pni / pnd / pnb / pns       # pnpm install/dev/build/start
yi / yd / yb / ys           # Yarn install/dev/build/start

zsh-config                  # Edit the main Zsh configuration and restart
zsh-aliases                 # Edit aliases and restart
zsh-plugins                 # Edit, regenerate, and restart
reload                      # Replace the current process with a fresh Zsh
```

`upload-dotfiles` stages tracked files only. It refuses detached HEADs, does
not create empty commits, and stops if commit or push fails.

## Plugin updates

Plugins and Antidote are pinned to full commits for reproducible installs.
Update one plugin deliberately:

```sh
./scripts/update-plugin-pin.sh owner/repository 40-character-commit
```

The command fetches the requested commit, updates every matching manifest
entry, and regenerates `modules/plugins.zsh`.

## Validation

Run all local checks:

```sh
make check
```

The checks cover Bash and Zsh syntax, setup argument handling, clean startup,
environment overrides, third-party completion discovery, the Git helper,
completion caching, whitespace, and ShellCheck when it is installed. CI runs
the suite on Ubuntu and macOS, plus an Arch job for Omarchy/Bash and Starship.
Omarchy tests use temporary homes and mocked installers; no system packages or
user configuration are modified. See the parity document for terminal checks.

## Security and reproducibility

- FNM and pnpm completion binaries use pinned release URLs and SHA-256 hashes.
- Antidote and all shell plugins are pinned to full Git commits.
- Setup stops immediately when a component fails.
- Local `.env` text is not evaluated as shell code; only known boolean flags
  are accepted.
