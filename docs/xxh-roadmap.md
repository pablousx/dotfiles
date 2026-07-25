# XXH portable-shell status and roadmap

## Implemented

- Powerlevel10k, autosuggestions, and syntax highlighting are pinned to full
  commits.
- Builds use a reusable source cache under `.cache/xxh-sources`.
- The remote payload contains runtime files only and no nested `.git`
  directories.
- General remote aliases are curated in `portable-aliases.zsh` instead of being
  scraped from local-only helpers.
- The manifest name is consistent and its version is derived from payload
  content, making repeated builds deterministic.
- Shell options, completion styles, Git aliases, and the local P10k
  configuration are incorporated during the build.

## Remaining opportunities

### Remote capability-aware aliases

Conditionally expose aliases for npm, pnpm, Yarn, and optional utilities based
on commands installed on the remote host. Avoid installing tools implicitly.

### SSH forwarding diagnostics

Add an opt-in diagnostic command that reports whether `SSH_AUTH_SOCK` is
available remotely. It should explain forwarding configuration without
changing SSH server or client settings.

### Automated payload tests

Run the generated plugin in minimal Debian, Fedora, and Alpine containers and
verify prompt startup, aliases, completion initialization, and operation
without network access.

### Terminal metadata

Document optional forwarding for terminal variables used by VS Code and
Windows Terminal. Keep it opt-in because forwarding arbitrary environment
variables depends on SSH server policy.
