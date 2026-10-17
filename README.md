# Dotfiles

A modular Zsh environment for macOS, Linux, and WSL, with an additional
Omarchy/Bash profile. Zsh uses Powerlevel10k, Antidote, cached completions,
and mise-managed tools. Omarchy keeps stock Bash, fzf, mise, and its existing integrations,
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

Both profiles offer these independent selections:

- **System dependencies** (`--core`): the selected platform's shell/helper packages,
  Git, curl, fzf where needed, and archive/clipboard support.
- **Mise tools** (`--tools`): Node.js with npm, pnpm, Yarn, Python, RTK OSS,
  Rulesync, pnpm-shell-completion, ShellCheck, GitHub CLI (`gh`), AWS CLI
  (`aws`), and Google Cloud CLI (`gcloud`).
- **Shell configuration** (`--zsh` or `--bash`): startup integration and profile settings.
- **Global AI configuration**: optional synchronization of instructions and skills.

`--all` selects system dependencies, mise tools, and shell configuration. AI,
keyboard, and brightness setup remain opt-in. Declining any component leaves it
unchanged. AI synchronization requires the mise tools selection to have been installed.

Tool versions and backends live in [`tools/mise.toml`](tools/mise.toml).
[`tools/mise.lock`](tools/mise.lock) records SHA-256 checksums and artifact URLs
for Linux and macOS on x64 and ARM64. Linux requires glibc. Setup installs with
`mise --locked`; it does not change the pins. To install just the shared toolset:

```sh
./setup.sh --tools
```

Setup reuses mise 2026.10.11 or newer. If mise is absent, it downloads that pinned
release binary into `~/.local/bin`, verifies SHA-256 before execution, and checks
its version. An existing older or incompatible mise stops setup for review.
Bootstrap requires curl and a SHA-256 utility; install system dependencies first
on a fresh host. Tool extraction requires tar, gzip, xz, and unzip.

Setup links the manifest at
`${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/conf.d/dotfiles.toml`.
It refuses an occupied destination unless it is already the matching symlink.
Personal mise configuration and project tool versions retain precedence over
these defaults. Installation uses the repository manifest and lockfile in
isolation, so unrelated tools in personal/project configuration are not installed.
Zsh activates mise once and exposes its shims before plugin loading; Omarchy
uses its existing mise activation. RTK setup installs only the CLI, without hooks
or services. Cloud CLI setup does not authenticate accounts or change cloud
credentials. Gcloud uses a versioned Google archive through mise's HTTP backend;
it needs no additional mise plugin or installer script. Python helpers and AI
sync resolve their prerequisites from mise.

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

The profile includes the full portable alias catalogs from the pinned Zsh
plugins: Git (`gf`, `gfa`, branch-aware helpers), Docker Compose, npm, Yarn,
history, and base64, plus local shortcuts. Every shortcut also has a `df-` name;
existing user commands keep their meaning. See the
[alias coverage and platform differences](docs/omarchy-parity.md).

Omarchy must already be installed. This profile targets Bash 5 and preserves
Omarchy's mise, zoxide, fzf, Bash completion, editor, and history configuration.
It never changes the login shell. Its `--tools` selection shares the portable
mise toolset.

```sh
./setup.sh --profile omarchy       # Interactive setup and final confirmation
./setup.sh --profile omarchy --help
```

Advanced automation:

```sh
./setup.sh --profile omarchy --bash  # Only install the guarded startup block
./setup.sh --profile omarchy --core  # System helper packages
./setup.sh --profile omarchy --tools # Pinned mise tools
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
Zsh-only flags such as `--zsh` and `--enable-plugins`.

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
Optional tools are checked when invoked. Core setup installs Git, curl, Bash completion, unzip, xz, and Wayland clipboard
support through Omarchy. Mise tools supply Python and Node/package-manager
commands; uncommon archive tools remain optional.

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

- copies the adjustment and restore helpers to `~/.local/bin/`;
- adds a marked block to `${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua`;
- unbinds Omarchy's focused-display 5% brightness actions before installing the
  all-display 10% replacements;
- enables `omarchy-brightness-restore.service` as a user service; and
- backs up changed files, then reloads and validates Hyprland in a live session.

The helper discovers active displays on each invocation, so connector names are
not stored in the dotfiles. It derives one target from the focused display,
applies that absolute value to every active display, and emits one OSD update so
different monitor response times cannot make the slider jump between values.
The 1% hardware floor advances to 10% on the next upward knob step. Turns made
during monitor I/O are coalesced into the next target, making fast knob rotation
responsive without overlapping hardware writes. Omarchy handles internal
panels with `brightnessctl` and external monitors with `ddcutil`; external
displays must have DDC/CI enabled in their on-screen settings.

After every fully successful all-display change, the helper atomically stores
the synchronized percentage in
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/brightness-all`. The user service
silently reapplies it at graphical login and after suspend gaps, DPMS wakeups,
or active-monitor changes. It waits for powered displays and retries failed
writes without overlapping knob activity. If no value has been saved yet, it
captures the focused display's live brightness as the initial target instead of
changing hardware unexpectedly.

The macropad mapping is stored in the device's onboard memory and travels with
the keyboard. Setup deliberately does not flash USB hardware. If the device is
factory-reset or replaced, program its knob to emit the two standard brightness
keys before enabling this component.

Removal deletes only the marked bindings block. It disables the user service
and removes its unit and installed helpers only when their contents still match
the repository, preserving local edits. The last saved brightness value remains
available if the component is installed again.

## Safe removal

Removal is deliberately separate from installation:

```sh
./uninstall.sh
```

The uninstaller asks which components to remove (including managed Omarchy,
keyboard, and brightness-knob blocks when present), defaults every answer to
“no,” shows the removal plan, and requires an explicit confirmation. The
`--tools` option removes only the matching mise configuration symlink.
Mise itself, shared installed tool versions, system packages, projects, and
committed repository files are retained. The explicit `--omarchy` option removes only its marked startup block after backup;
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
df up                       # Apply AI, commit changes and push the current branch
df down                     # Pull with --ff-only and apply AI on this machine

ni / nd / nb / ns           # npm install/dev/build/start
pni / pnd / pnb / pns       # pnpm install/dev/build/start
yi / yd / yb / ys           # Yarn install/dev/build/start

zsh-config                  # Edit the main Zsh configuration and restart
zsh-aliases                 # Edit aliases and restart
zsh-plugins                 # Edit, regenerate, and restart
reload                      # Replace the current process with a fresh Zsh
```

`df up` stages tracked changes plus new files under `ai/`, asks for a commit
message, and pushes the current branch. Other untracked files are excluded.
It refuses detached HEADs, avoids empty commits, and stops on sync, commit,
or push errors. `df down` pulls with `--ff-only` and then regenerates AI.
Both commands apply AI only after it has been installed successfully through
the interactive setup on that machine. Existing AI conflicts stop generation
without overwriting local edits; if generation fails after a pull, the checkout
is already updated and generation can be retried with `./scripts/sync-ai.sh`.
Edit AI sources in `ai/.rulesync/`, run `df up`, then run `df down` on your
other machines. These commands do not install missing tools or run shell setup.
The system disk-usage command remains available as `df -h` (or `command df`).

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

- Mise bootstrap and all mise-managed tool artifacts are pinned and SHA-256 verified.
- Antidote and all shell plugins are pinned to full Git commits.
- Setup stops immediately when a component fails.
- Local `.env` text is not evaluated as shell code; only known boolean flags
  are accepted.


## Global AI instructions and skills (opt-in)

The canonical, portable AI configuration lives in `ai/`:

- `ai/.rulesync/rules/*.md`: global instructions. Use YAML frontmatter
  `root: true` for instructions composed into the global `AGENTS.md`.
- `ai/.rulesync/skills/<name>/SKILL.md`: personal, reusable skills in the
  standard format (frontmatter `name` and `description`, followed by Markdown).
  Keep supporting scripts and references in the same skill directory, using
  relative paths. No sample skills are installed.
- `ai/rulesync.jsonc`: Rulesync configuration. Initially only `codexcli`,
  global mode, `rules` and `skills`, with `delete: false`.

Project-specific instructions and skills remain in their projects; this
repository's `AGENTS.md` is not a global rule. Do not commit credentials,
absolute personal paths, machine settings, or generated harness files here.

The reusable skills adapted from Wire are `writing-for-agents` (agent guidance),
`simplify` (behavior-preserving simplification), `retro` (requested session reviews),
`diagnosing-bugs` (evidence-based diagnosis), `research` (sourced technical research),
and `vulnerability-validation` (security finding validation). They follow the current
project's rules without depending on Wire's paths, stack, or other skills. Wire's
project-specific guidance remains in its checkout; reusable skills are maintained
only in these canonical dotfiles sources and referenced by name from Wire.

Additional reusable workflows are `correct` (requested corrections), `create-pr`
(PR submission), `follow-up-on-pr` (feedback and CI), `security-review` (trust-boundary
audits), `threat-model-generation` (requested threat models), and `domain-modeling`
(product concepts, lifecycle rules, and invariants). `skill-creation` covers portable
skill authoring, canonical source placement, prerequisites, and validation alongside
`writing-for-agents`. Each documents its
prerequisites and missing-tool behavior. PR workflows use Git plus authenticated
GitHub CLI or connector access; review/modeling does not require a scanner.
Project-specific checks still require that project's tools. Skill synchronization
does not install or authenticate these tools.

On a new Linux or macOS machine, clone this repository anywhere and run:

```sh
./setup.sh
```

In interactive setup, answer yes to “Sync global AI instructions and skills?”
(default: no). Both profiles offer this opt-in; `--all` excludes AI. For
automation or subsequent updates, use `./scripts/sync-ai.sh` directly.
It requires the Python and Rulesync versions installed by `./setup.sh --tools`.
The wrapper resolves their absolute executable paths through the pinned mise
manifest before generating into an isolated HOME. It does not install missing
tools: run the tools setup selection first. AI synchronization does not install Codex.

After editing the sources or pulling changes:

```sh
git pull
./scripts/sync-ai.sh --dry-run
./scripts/sync-ai.sh
```

The command works from any directory via its checkout path. It always runs
`rulesync generate --dry-run` before generating into an isolated temporary
HOME. The wrapper then checks every output and copies only approved files to
the real HOME. `--dry-run` performs the same checks without writing any global
files or ownership state. Missing mise tools produce an actionable error.

For Codex, the verified destinations are `~/.codex/AGENTS.md` and
`~/.agents/skills/<name>/`. The latter is shared with other harnesses.
Authentication, sessions, models, `config.toml`, permissions and MCP are outside
this integration. Existing unrelated skills remain untouched. Removed sources
do not delete old outputs: review and remove obsolete skills manually.

### Existing content and conflicts

Before writing anything, the wrapper refuses differing, unowned destinations,
symlinked destinations, duplicate names in legacy `~/.codex/skills/`, and local
edits to previously installed files. An identical existing file can be adopted.
Last installed copies are kept locally in `~/.local/state/dotfiles-ai/` to
recognize safe updates; they are not portable source files. Back up this state
if needed; losing it makes differing destinations require review again.
Run one synchronization at a time, with agents and other installers idle.

The original global Codex instructions referenced an external RTK Markdown
file. Its complete portable text is now in `ai/.rulesync/rules/rtk.md`, without
the personal path. On a machine that still has the old reference, synchronization
reports a conflict. Compare the existing instructions (including referenced
text) with the canonical source, merge any additional instructions into the
source, then move the old file to a private backup outside the checkout and
rerun synchronization. Preserve copies of referenced files as well. Do not
remove or replace files merely to silence a conflict without reviewing them.

Omarchy's skills, omai's project-maintained symlinks, Codex system skills and
plugin-managed skills remain owned by their original installers. Add future
personal skills under the
canonical skills directory; do not copy whole Codex/plugin directories or
machine-specific symlinks into Git. Inspect all skill assets for secrets before
committing them. Make changes in the canonical sources, not generated copies.

Before adding a skill, review required shell tools, optional tools and non-shell
capabilities. Document prerequisites and Linux/macOS support in the skill, and
state what remains unverified when a tool is unavailable. Add approved shared
dependencies through setup rather than installing them implicitly from a skill.

### Adding another harness or updating Rulesync

Add the desired target to `ai/rulesync.jsonc`, keeping global mode, features
limited to rules/skills and deletion disabled. Check its global support and
output paths in the [Rulesync global-mode documentation](https://rulesync.dyoshikawa.com/guide/global-mode)
and [supported tools](https://rulesync.dyoshikawa.com/reference/supported-tools).
Extend the configuration guard and destination allowlist in `scripts/sync-ai.py`
and its preservation tests for those paths, then review a dry run. Sources stay
in the same place. The explicit guard prevents accidentally writing new kinds
of configuration before their destinations have been reviewed.

To update a tool, edit its exact version in `tools/mise.toml`, then refresh
`tools/mise.lock` with `mise -C tools lock --platform linux-x64,linux-arm64,macos-x64,macos-arm64`.
Review all four platform URLs and SHA-256 values. If a release provides no digest,
calculate SHA-256 from its official artifact and record it in the lock entry;
`make check` rejects missing checksums. Keep RTK's `rtk-oss-` asset selection.
Validate Rulesync generation in a temporary HOME when updating it, and run
`make check` before using the new tools on global configuration.
