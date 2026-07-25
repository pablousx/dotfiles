# Dotfiles

A modular Zsh environment for macOS, Linux, and WSL. It includes a
Powerlevel10k prompt, Antidote-managed plugins, cached completions, FNM-based
Node.js switching, and an optional portable XXH shell.

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

It prompts for each installation component, all five shell-module settings,
shows a final summary, and asks for confirmation before changing anything.
Advanced non-interactive flags remain available through `./setup.sh --help`,
but they are not needed for normal setup.

The default Node.js version is `24.12.0`. Override pinned tool versions when
needed:

```sh
NODE_VERSION=24.12.0 FNM_VERSION=1.39.0 ./setup.sh --fnm
```

Homebrew must already be installed on macOS. On Linux, core setup supports
APT, DNF, Pacman, and Zypper. WSL uses the detected Linux package manager.

## Safe removal

Removal is deliberately separate from installation:

```sh
./uninstall.sh
```

The uninstaller asks which components to remove, defaults every answer to
“no,” shows the removal plan, and requires an explicit confirmation. It only
removes tool directories marked as created by this repository. It does not
remove system packages, shell startup files, Node projects, XXH connection
state, or committed repository files.

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

## Portable XXH shell

Install XXH support:

```sh
./setup.sh --xxh
```

Connect with the portable Zsh environment:

```sh
xxhh user@host
xxhh user@host +if   # force XXH to reinstall the local plugin
```

The XXH payload uses pinned Powerlevel10k, autosuggestion, and highlighting
sources. Its build excludes nested Git repositories, tests, documentation,
and images, and derives its manifest version from a content hash.

Rebuild it with:

```sh
make xxh-build
```

## Validation

Run all local checks:

```sh
make check
```

The checks cover Bash and Zsh syntax, setup argument handling, clean startup,
environment overrides, third-party completion discovery, the Git helper,
completion caching, XXH payload hygiene, whitespace, and ShellCheck when it is
installed. CI runs the suite on Ubuntu and macOS.

## Security and reproducibility

- FNM and pnpm completion binaries use pinned release URLs and SHA-256 hashes.
- Antidote and all shell plugins are pinned to full Git commits.
- XXH is installed at a fixed version in an isolated virtual environment.
- Setup stops immediately when a component fails.
- Local `.env` text is not evaluated as shell code; only known boolean flags
  are accepted.
