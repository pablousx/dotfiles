# AGENTS.md

## Project purpose

This repository provides a portable, modular Zsh environment for macOS,
Linux, and WSL. It manages shell startup, pinned Antidote plugins, verified
tool installers, and cross-platform shell helpers.

## Working rules

- Preserve user-owned and ignored state such as `.env`, `.zsh_history`,
  `.cache/`, `.antidote/`, and generated module build directories.
- Never run `setup.sh --all`, component installers, or `uninstall.sh` merely
  to test a change. Use `skip` actions, temporary homes, and mocked commands.
- A “no” response during setup must always mean “leave unchanged.” Removal
  belongs only in the explicit, confirmed uninstaller.
- Keep installation paths derived from the repository location. Do not
  reintroduce `$HOME/dotfiles` assumptions.
- Keep Bash scripts compatible with the Bash version shipped by macOS unless
  CI is deliberately changed to install a newer Bash.
- Support macOS and the Linux package managers implemented in `setup/lib.sh`:
  APT, DNF, Pacman, and Zypper. Treat WSL as Linux with Windows integration.
- Quote paths and validate every value crossing from CLI arguments or `.env`.
- Do not execute downloaded scripts directly. Pin external versions and verify
  release artifacts with SHA-256 before extraction or execution.

## Important architecture

The order in `.zshrc` is intentional:

1. Powerlevel10k instant prompt.
2. Repository and environment configuration.
3. `path` and pre-completion `fpath` entries.
4. Cached `compinit`.
5. shell options and history.
6. third-party plugins.
7. local aliases/hooks so local definitions win.
8. prompt configuration and mise initialization.

Do not move plugin completion paths below `compinit`, source both
Powerlevel10k compatibility themes, export `FPATH`, or restore the old literal
completion-age test.

## Generated and pinned files

- `modules/plugins.txt` is the pinned plugin source of truth.
- `modules/plugins.zsh` is generated and committed. Regenerate it whenever the
  manifest changes.
- Use `./scripts/update-plugin-pin.sh owner/repository FULL_COMMIT_SHA` for
  plugin updates. Do not replace pins with floating branches or tags.
- Antidote, mise, and pnpm-shell-completion versions are intentionally pinned
  in setup scripts.

## Module configuration

Setup owns these persisted boolean values:

- `DISABLE_ALIASES`
- `DISABLE_PROMPT`
- `DISABLE_PLUGINS`
- `DISABLE_PRINT_ALIAS_COMPLETION`
- `DISABLE_EXPAND_ALIAS`

The primary workflow is zero-argument `./setup.sh`, which prompts for every
module and writes the result through `setup/modules.sh`. Advanced CLI
`--enable-*`/`--disable-*` flags remain available for automation. Existing
environment variables override `.env` at runtime. Only literal `true` and
`false` are valid.

## Validation

Run before handing off any change:

```sh
make check
```

When ShellCheck is not installed locally, state that clearly; CI installs it
on Ubuntu and macOS. Do not weaken or disable checks just to get a green run.

## Installed skills

Future agents should use the globally installed skills when relevant:

- `shell-bash` for Bash structure, argument parsing, quoting, and safe command
  execution.
- `configuring-zsh` for startup-file ordering, `fpath`/`compinit`, plugins,
  Powerlevel10k, and startup profiling.
- `bash-lint` for ShellCheck interpretation and shell formatting guidance.

Repository rules in this file take precedence over generic examples in those
skills, especially the requirements to pin dependencies and preserve macOS
Bash compatibility.

## Documentation expectations

Update `README.md` whenever setup flags, supported platforms, environment
variables, installation behavior, or common commands change.

## Handoff checklist

- `git diff --check` passes.
- Bash and Zsh syntax checks pass.
- `make check` passes.
- Generated plugin output matches `modules/plugins.txt`.
- No system packages or user data were modified during validation.
- The final report calls out any deliberately untested platform or installer.

## Omarchy / Bash profile

- `setup.sh` defaults to `--profile auto` for interactive and automated use.
  Detect distro families from os-release without sourcing it; select Omarchy
  only for Omarchy, otherwise Zsh on supported platforms. Unsupported hosts
  fail before any changes. `--profile zsh` remains an explicit override.
- Package-manager selection follows the detected distro, never PATH order.
  Keep installer code compatible with Bash 3.2. Tests override host-read
  functions only inside temporary repository copies.
- Runtime `modules/bash/` targets Omarchy Bash 5. Use stock Bash and existing
  Omarchy fzf/mise/zoxide/Starship initialization; do not add a shell framework.
- `.env.omarchy` is user-owned and ignored. Its settings must not alter `.env`.
- Only the marked `.bashrc` block belongs to the Bash installer/uninstaller.
  Preserve other content, symlink targets, permissions, and backups.
- Preserve existing user/Omarchy commands and completions. New helpers have
  `df-` names; register short forms only if unused.
- Keep `docs/omarchy-parity.md` aligned with the Zsh plugin manifest and helpers.
- The Starship preset is selected with `STARSHIP_CONFIG`; explicit user
  overrides win. Never rewrite Omarchy's own Starship file or packaged defaults.
- Arch CI validates the versioned Omarchy startup fixture and Starship. Never
  run a real installer for testing; use temporary homes and mocked commands.

- The optional `--keyboard` component restores `us-altgr-spanish` through
  user-local XKB symbols and a marked block in `hypr/input.lua`; `--all` remains
  shell-only. `--save-keyboard` captures only the local symbols file.
- The optional `--brightness-knob` component installs a user-local helper and
  a marked block in `hypr/bindings.lua`; interactive setup defaults to leaving
  it unchanged, and `--all` must not select it.
- Brightness-knob setup never flashes input hardware. Preserve non-managed
  bindings, discover active monitors at runtime, and test through mocked
  `hyprctl` and `omarchy` commands.
- Keyboard tests must use temporary XDG homes and a mocked `hyprctl`. Real
  activation must reload Hyprland and check configuration errors.
- Prompt pnpm context comes from project metadata. Never execute pnpm on the
  prompt path: version-manager bootstrap can exceed Starship's timeout.
- Setup prompts describe the selected profile directly; avoid comparisons to
  another profile's prompt engine or plugin manager.

- Zsh setup includes mise and Node automatically; there is no separate runtime
  component flag. Enable Node idiomatic version files during setup so `.nvmrc`
  and `.node-version` select the runtime through mise activation on directory changes.
