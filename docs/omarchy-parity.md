# Omarchy/Bash workflow parity

The Omarchy profile targets Bash 5 on Omarchy. It retains Omarchy's mise,
zoxide, fzf, Bash completion, editor, clipboard environment, and history file.
It does not source Oh My Zsh, Antidote, or ZLE code.

Every helper below has a `df-` spelling, unless explicitly described otherwise.
The short spelling is also registered when no existing alias, function, builtin,
or executable owns it. Neither spelling overwrites a user definition. For
example, stock `c`, `cx`, `h`, and `gcm` remain Omarchy commands; `df-c` opens
VS Code, `df-cx` moves up, `df-h` displays history, and `df-gcm` checks out `main`.
The namespaced Git and Compose shortcuts are a curated subset, not the entire
Oh My Zsh alias catalog. Use the underlying CLI for other operations.

## Local configuration and helpers

| Zsh feature | Omarchy/Bash equivalent or limitation |
| --- | --- |
| `dotfiles`, `upload-dotfiles` | Shared repository Git implementation; `df-dotfiles`, `df-upload-dotfiles` always avoid Omarchy names. Upload stages tracked files only and checks commit/push failures. |
| `ni`, `nd`, `nb`, `ns` | Same npm commands. |
| `pni`, `pnd`, `pnb`, `pns` | Same pnpm commands, using mise's selected runtime. |
| `yi`, `yd`, `yb`, `ys` | Same Yarn commands. |
| `G`, `H`, `L`, `M`, `S`, `T`, `X` global aliases | Bash does not implement these; write `command \| grep pattern`, `\| head`, `\| less`, `\| more`, `\| sort`, `\| tail`, or `\| xargs`. |
| `c` | `df-c`: `code -r`; preserve Omarchy's `c`. |
| `cls`, `move_to_bottom` | Clear screen and/or place cursor on the last terminal row. |
| `cx`, `cz`, `dev` | `df-cx`, `df-cz`, `df-dev`; keep existing commands and zoxide's `cd` integration. |
| `lc` | `eza -la --group-directories-first`, using Omarchy's listing tool instead of colorls. |
| `sql` | Existing `$HOME/sqlcl/bin/sql`, checked at invocation; SQLcl is not installed. |
| `open` | Keep Omarchy's implementation; `df-open` explicitly calls `xdg-open`. |
| `reload` | Replace the current shell with Bash. Open a new terminal to completely discard inherited environment overrides. |
| `zsh-config`, `zsh-aliases` | `bash-config`, `bash-aliases`, with `df-` forms. Additional `bash-settings` and `bash-prompt` edit this profile's settings and preset. |
| `bundle-plugins`, `zsh-plugins` | Not applicable: no Bash plugin manager or generated bundle. |
| `google`, `duck` | URL-encode arguments before opening the search URL. |
| `timezsh` | `timebash`: time four interactive Bash startups. |
| `.env`, five Zsh switches | Independent `.env.omarchy`: aliases, prompt preset, added completions, history synchronization. No expansion/plugin flags with misleading Bash semantics. |
| Zsh completion cache and `fpath` | Leave Bash completion ownership to Omarchy; no shared cache or exported `FPATH`. |
| History and migration | Keep Bash's history file and options; append/read new entries between prompts. Never mix extended Zsh records into Bash history. Concurrent history ordering follows Bash, not Zsh's exact shared-history behavior. |
| Shell options and navigation | Keep Omarchy's Bash options and zoxide. Zsh glob ordering, directory stack options, and automatic URL quoting are not emulated. |
| SSH agent hook | Keep the existing user/Omarchy SSH setup; do not introduce another agent initialization. |
| mise Node switching | Use Omarchy's existing mise activation and project configuration. No Node download or runtime configuration rewrite. Declare project tools in `mise.toml`. |
| PATH, editor, terminal integration | Preserve Omarchy/user settings. Tools are resolved from the existing PATH; no hard-coded runtime or pnpm path. |

## Active plugin inventory

This table corresponds to every active repository entry in `profiles/zsh/modules/plugins.txt`,
plus the conditionally loaded platform plugins.

| Plugin | Bash implementation or deliberate difference |
| --- | --- |
| `romkatv/powerlevel10k` | Repository Starship preset: directory, Git, status, jobs, Node, declared pnpm project version, virtualenv, SSH/root context, second-line prompt. No instant prompt or right-side prompt. |
| `MichaelAquilina/zsh-you-should-use` | `alias-show NAME` explicitly inspects a command; no automatic alias reminders. |
| `ohmyzsh/ohmyzsh: sudo` | Type/edit `sudo` normally; no double-Escape binding. |
| `olets/zsh-window-title` | Keep terminal/Omarchy title behavior; no additional preexec title hook. |
| `ohmyzsh/ohmyzsh: fzf` | Existing Omarchy fzf completion and keybindings, initialized once. |
| `ohmyzsh/ohmyzsh: git` | `gst`, `gco`, `gcm`, `gp`, `gl`, `glog` and their prefixed forms. Other operations use `git` or Omarchy's helpers. |
| `ohmyzsh/ohmyzsh: gh` | Packaged/tool-provided Bash completion, discovered through bash-completion. |
| `ohmyzsh/ohmyzsh: gitignore` | `gi LANGUAGE[,LANGUAGE...]` prints the gitignore.io template through HTTPS; no downloaded text is executed. |
| `Aloxaf/fzf-tab` | Keep stock Bash Tab behavior and Omarchy fzf selectors. Group switching and command-specific Zsh previews are not reproduced. |
| `zsh-users/zsh-completions` | Omarchy's bash-completion package and installed CLI completion providers. |
| `docker/cli` Zsh completion | Installed Docker Bash completion. |
| `ohmyzsh/ohmyzsh: docker-compose` | `dco`, `dcup`, `dcdown`, `dce` use `docker compose`. |
| `ohmyzsh/ohmyzsh: aws` | Installed AWS CLI completion provider; use native `aws configure list-profiles` and `AWS_PROFILE=name aws ...` in place of OMZ profile mutation helpers. No credentials are modified. |
| `ohmyzsh/ohmyzsh: npm` | Local npm shortcuts; packaged completion where available. Other OMZ npm aliases use their explicit npm commands. |
| `g-plane/pnpm-shell-completion` | Installed Bash completion where available, otherwise local script completion. `df-run pnpm SCRIPT` guarantees script-name completion; advanced Zsh workspace/filter previews are not ported. |
| `ohmyzsh/ohmyzsh: yarn` | Local Yarn shortcuts and installed Bash completion, with script-name fallback. |
| `ohmyzsh/ohmyzsh: copyfile` | `copyfile FILE` using Wayland `wl-copy`. |
| `ohmyzsh/ohmyzsh: copypath` | `copypath` copies the current directory using `wl-copy`. |
| `ohmyzsh/ohmyzsh: extract` | `x ARCHIVE`: tar variants, zip, 7z, rar, gzip, bzip2, xz, zstd. Uses installed tools; does not install uncommon extractors. |
| `ohmyzsh/ohmyzsh: colored-man-pages` | Omarchy's existing bat-based man pager. |
| `ohmyzsh/ohmyzsh: encode64` | `e64`, `d64` accept text arguments or stdin; UTF-8 text helpers, not arbitrary binary-file conversion. |
| `ohmyzsh/ohmyzsh: jsontools` | `pp_json`, `is_json`, `urlencode_json`, `urldecode_json`; JSON quoting/unquoting operates on strings. |
| `ohmyzsh/ohmyzsh: urltools` | `urlencode`, `urldecode`, accepting arguments or stdin. |
| `ohmyzsh/ohmyzsh: history` | `df-h`, `hs`, `hsi`; preserves Omarchy's `h`. |
| `ohmyzsh/ohmyzsh: aliases` | `als PATTERN`, literal alias search, plus `alias-show NAME`. |
| `hlissner/zsh-autopair` | No automatic delimiter insertion in stock Bash. |
| `zsh-users/zsh-autosuggestions` | Use history search and fzf Ctrl-R; no inline suggestions. |
| `zsh-users/zsh-syntax-highlighting` | No live command highlighting in stock Bash. |
| Conditional `macos`, `ubuntu`, `command-not-found` | Not loaded on Omarchy. Keep its native commands/package workflow, including `omarchy pkg add`. No APT alias remapping. |
| Local print-alias-completion hook | Explicit `alias-show NAME`; no output before every command. |
| Local expand-alias accept-line hook | Native Bash alias execution; no line rewriting on Enter. |

The pnpm prompt segment reads `packageManager` metadata from the project or its
workspace ancestors; it does not execute pnpm. Without a declared version, a
lockfile/workspace marker produces a plain `pnpm` label.

The optional Spanish AltGr keyboard preset is documented in the README. It is
independent of shell setup and is not selected by `--all`.

No new remote Bash plugins are installed. Any future plugin must have a concrete
missing capability, a pinned and verified source, and compatibility tests for
Omarchy's startup and existing keybindings.

## Validation contract

`make check` includes an isolated behavioral fixture of Omarchy `4.0.0.alpha`
startup ownership and order. It is intentionally not a complete Omarchy install.
The Arch CI job checks Bash 5, real Starship rendering, existing Zsh behavior,
and a temporary PTY exercising Tab and fzf Ctrl-R/Ctrl-T/Alt-C with space-containing
paths and cancellation.
Ubuntu/macOS retain their existing Zsh checks; Bash 3.2 runs setup tests but skips
the Omarchy-only runtime tests. Starship rendering skips when the binary is absent.

For a terminal acceptance check after installing on a test account:

1. Open Bash and verify directory/Git context and the two-line prompt.
2. Run a failing command and a background job; check status and jobs indicators.
3. Enter a mise-configured Node/pnpm project and a Python virtualenv; check context.
4. Exercise Tab and fzf Ctrl-R/Ctrl-T/Alt-C; confirm selection, cancellation,
   paths containing spaces, and the existing Omarchy bindings.
5. Confirm `c`, `cx`, `h`, `gcm`, `cd`, and `open` retain their original meanings.
6. Open two shells and check newly written history appears after a prompt.
7. Select the stock prompt, open a fresh terminal, then remove the managed block
   through the confirmed uninstaller and verify the original shell still works.
