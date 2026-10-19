# omasync

Small native Omarchy Quattro bar widget for this dotfiles repository. Shared
Git/AI logic lives in `sync.py`; `shared/repository.sh` delegates `df up/down`
to that executable. The plugin never loads shell functions. Python 3 stdlib,
Git and Bash are required on Linux/macOS; only the desktop UI/installer needs
Omarchy Quattro, its running shell and configured terminal. Rulesync remains
the existing pinned mise tool, enabled independently on each machine by the
existing AI setup. Installation does not install prerequisites.

## Install and configure

Run `./setup.sh` on Omarchy and accept **Install omasync bar plugin** (default
no). This component is selected only through the interactive prompt; `--all`
excludes omasync. Installation runs at the end of successful setup, after AI
configuration and before the completion message. When the plugin manifest is
already present, setup offers **Update installed omasync bar plugin** instead
of installation, also defaulting to no.
Declining leaves an existing installation unchanged. Installation prepares the
four QML files as a complete immutable snapshot under
`~/.config/omarchy/plugins/io.github.pablousx.omasync/runtime/<content-hash>/`,
records the actual repo path, then atomically switches the installed manifest
to that snapshot and rescans plugins. New installations are enabled on the right. Updating an
existing installation refreshes its UI without enabling a disabled widget or
changing its placement/settings. It refuses unmanaged directories and symlinks.
Each changed UI gets a new entry-point URL, avoiding stale QML component caches.
Previous snapshots and legacy flat files remain available for in-flight loaders
until the plugin is removed. Repeat opt-in setup to refresh the UI after updates;
the backend always runs directly from this checkout. Moving the checkout
requires repeating setup. Configuration and state are local, never committed.

The rescan request uses a 10-second shell IPC timeout and up to three attempts
to tolerate a shell hot reload. If confirmation still fails, the installer
reports that the files were copied and can be retried with
`python3 ./omasync/install.py install`. An incomplete first installation keeps
activation pending so a retry also enables it; updates keep existing enabled
or disabled state and placement. The installer never restarts the shell.

The **Settings** tab offers check intervals and an opt-in automatic-download
button, persisted through Omarchy's host API while preserving other settings.
You can also edit the widget's existing `shell.json` bar layout entry:

```json
{"id":"io.github.pablousx.omasync", "intervalSeconds":300, "autoDownload":false}
```

Keep the surrounding layout and other settings. The interval is in seconds,
clamped to 30–86400. Only JSON boolean `true` enables automatic download.
Optional `repository` overrides the recorded absolute checkout path. The
lightweight local status reader runs every two seconds; remote fetches occur
at startup and at the configured interval. Multiple monitors share a Git
common-directory lock, so overlapping checks skip safely.
Local status readers share a read lock and can run concurrently across monitors;
only a writer reports an active synchronization. The UI keeps the last known
commit counts while a writer holds the lock and refreshes status immediately
after an operation completes. Remote checks, uploads and downloads have distinct
busy labels. A failed status reader becomes a retryable error instead of leaving
the UI marked as synchronizing.

## Behavior

The interface is entirely in English. The plugin and `df up` / `df down` use
the same shared Git backend; neither uses GitHub CLI (`gh`) to synchronize.
The optional `gh` commands below are manual GitHub authentication setup only.

Icons distinguish updated, local changes, remote changes, synchronizing and
error. Counts in the panel reveal when local and remote commits both exist.
**Upload** creates its commit message automatically with a UTC timestamp, e.g.
`dotfiles updated 2026-10-17T18:42:03Z`, without opening a terminal or requesting
text. `df up` keeps its interactive message and date fallback. Both apply
opted-in AI first, stage tracked files
and new `ai/` sources, commit when necessary, then push `origin` and the
current branch, as before. No timer ever uploads.

When a normal push is rejected specifically because the remote branch advanced,
both upload entry points make one reconciliation attempt: fetch that branch,
retain the original local HEAD under a unique `refs/omasync/pre-rebase/` ref,
rebase local commits onto the fetched commit, reapply opted-in AI to the final
sources, then retry a normal push once. Merge structure and other local branch
refs are preserved; Git's autostash, autosquash, updateRefs and rerere automation
are disabled for the rebase. Empty and equivalent local commits are retained.
No Git configuration is persisted. Network/authentication failures and server
hook rejections do not trigger a rebase. A dirty checkout, rewritten remote
history or unrelated histories require user review. Rebase conflicts remain in
place for review, with both histories preserved; there is no automatic abort,
reset, force push or conflict resolution. A second remote race also stops for
a later explicit retry. Existing merges/rebases are never cancelled or adopted
by this process. Downloads remain fast-forward-only.

**Download** requires a clean checkout (including untracked files), an attached
branch and upstream, fetches, performs a fast-forward-only merge, then applies
AI through the unchanged `scripts/sync-ai.sh`. `df down` uses the same checks.
Automatic download additionally rejects local commits. An active merge,
rebase, cherry-pick, revert or bisect blocks synchronization. No stash, reset,
force push or automatic conflict resolution is used. The per-repository
`flock` lock also covers CLI usage, subprocesses and commit-message input;
kernel locks are released on exit without stale PID recovery or deleting lock
files. This does not serialize unrelated Git clients or a separately invoked
`scripts/sync-ai.sh`.

State is atomically saved in the checkout's Git directory as
`omasync-state.json` with owner-only permissions. A successful Git update
followed by a Rulesync failure stays visibly marked **Repository updated;
AI configuration could not be applied**. Download retries AI even if Git is
already current. Checks preserve operation errors; a successful sync clears
them. AI generation pending after an interruption is also an error. AI output
is never imported back into source or overwritten outside existing Rulesync
guards. Machines without the existing AI opt-in marker skip generation.

Background commands use noninteractive Git authentication and BatchMode SSH by
default. Passive checks and local status commands have a 15-second timeout per
subprocess; explicit synchronization and opted-in automatic downloads retain
the 90-second timeout. Timeout terminates the
background process group before releasing the lock. Errors retain only stage,
safe category and exit code; no dialogs or notifications recur. Later checks
retry connectivity. Existing SSH command overrides still apply. Configure
authentication separately in a terminal; omasync never edits credentials.
Missing HTTPS username/password or rejected authentication is reported as
**authentication required**, with the Git stage and exit code, instead of an
unexplained exit 128. Network failures retain a separate category; exit 128
alone does not prove an authentication failure. Only safe categories are
saved or passed to AI, never Git stderr, remote URLs or tokens.

For GitHub HTTPS remotes, if GitHub CLI is already installed and `gh auth status`
confirms a valid login, you can explicitly connect Git to that login in your
terminal with `rtk gh auth setup-git --hostname github.com`. This user-run
command changes Git's credential-helper configuration; omasync never runs it.
For other hosts or SSH, configure the appropriate Git authentication yourself
using the host's instructions. No tool is installed or configured by the plugin.
Then retry **Upload**. A successful fetch (for example, from a public repository)
does not establish permission to push and does not clear an unresolved upload
or AI failure. Successful synchronization clears its saved error metadata.

If GitHub refuses to create or update a workflow because the login lacks
workflow access, omasync reports **GitHub workflow permission required** and
keeps the local commits for retry. With an existing GitHub CLI OAuth login,
run `rtk gh auth refresh --hostname github.com --scopes workflow` yourself in
a terminal, approve the requested access, then retry **Upload**. Personal access
tokens and GitHub Apps require the corresponding workflow permission through
their own authorization settings. The plugin never changes credentials or
requests additional scopes. This category applies only to GitHub's explicit
workflow-permission refusal; unrelated exit 1 failures retain their own error.
A push dry-run cannot verify GitHub's server-side workflow authorization.
The local-changes label describes the checkout; the failure appears under
**Needs attention**. Untracked files outside `ai/` are left untouched by upload.

The read-only `io.github.pablousx.omasync` IPC target exposes `diagnostics` for
all live monitor instances: busy/checking flags, process-running flags, status
and active action. It contains no paths, error text, logs or credentials and
does not run synchronization or alter state.

## Resolve with AI

Uses the official `omarchy agent prompt` route and its configured default
agent, with the repository as working directory. It does not select or install
an agent. Omarchy itself controls the terminal and agent approval flags.
Both direct and fallback diagnostic prompts are in English. The prompt asks to
diagnose, preserve both machines' changes, repair and retry,
consulting the user on ambiguity. It forbids discarding changes, stash/reset,
force push and credential modifications. Evidence is explicitly untrusted:
operation, sanitized error category/exit code, dirty/in-progress flags,
upstream availability, ahead/behind counts, and AI application status.
No diffs, file contents, remote URLs, credentials, environment dumps or raw
logs are included. More detailed diagnostics must be inspected locally in the
visible session. These prompt instructions guide the agent; they are not a
technical sandbox for the external AI.

On older Omarchy without `agent prompt`, omasync opens a visible terminal,
prints the same small prompt, and asks you to copy it before opening the
default agent inline. Paste it manually into that session. No provider-specific
CLI flags are guessed. Opening AI does not clear the failure; local status is
polled again and you must repair/retry synchronization to clear it.

## Disable/remove

Use `omarchy plugin disable io.github.pablousx.omasync` to stop checks, or
`omarchy plugin remove io.github.pablousx.omasync` to remove the UI. Neither
removes the repository or AI configuration. Existing dotfiles uninstaller
actions do not remove this separately managed plugin. No background daemon,
system service, macOS automation or scheduler is installed.

## Validation

`python3 omasync/test_sync.py` uses temporary homes, real disposable local Git
remotes and mocked Omarchy/Rulesync commands. `make check` includes it alongside
the existing AI conflict-protection tests. Never install or activate the actual
plugin to run tests. When Qt's `qmltestrunner` is available, an offscreen fixture
executes the widget's production status-update functions with fake processes
to check counts and reader recovery; otherwise this test is explicitly skipped.
The fixture does not validate live Process signals, rendering or multi-monitor IPC.
Manifest validation is read-only:
`omarchy plugin validate ./omasync`. QML can be checked with Qt's `qmllint`
and an import root exposing the installed shell as `qs`; dynamic shell/Loader
properties may produce type warnings. Live rendering, keyboard navigation,
actual terminal/agent launches, real authentication, macOS execution and Bash
3.2 need validation on their corresponding environments.

Reviewed references (2026-10-17): [official plugin manual](https://omarchy.org/manual/shell-plugins/),
[development guide](https://plugins.omarchy.org/develop.html),
[shell contracts](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md),
[official agent launcher](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-agent),
[prompt route](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-agent-prompt).
The UI follows `BarWidget`, `WidgetButton`, `Panel`, `KeyboardPanel`,
`PanelKeyCatcher`, `PanelSeparator` and theme tokens, with compact native
Qt Quick Controls buttons and typography following omadocs. No second shell
process is started.
