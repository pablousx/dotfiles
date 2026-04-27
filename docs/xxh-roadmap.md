# xxh Portable Shell: Future Improvements Roadmap

Our current implementation successfully ports aliases, core Zsh options, and the Powerlevel10k theme to remote hosts. Below are potential enhancements to make this even more powerful and seamless.

## 1. Automated Plugin Porting
Currently, we manually bundle `zsh-autosuggestions` and `zsh-syntax-highlighting` in `build.sh`.
- **Improvement**: Parse `modules/plugins.txt` during the build process and automatically download/bundle any plugin that doesn't require a compiled binary.
- **Goal**: True 1:1 parity between local and remote plugins.

## 2. Remote-Only Setup Hook
Some remote hosts might need a "lite" version of your setup script.
- **Improvement**: Add a `remote-setup.sh` that `pluginrc.zsh` runs only on the first connection.
- **Use Case**: Automatically setting up `git config --global user.email` or creating a specific directory structure on the remote host without affecting the local machine.

## 3. Smarter Binary Fallbacks
Many of your local aliases rely on tools like `fnm`, `pnpm`, or `fzf` which might be missing on remote hosts.
- **Improvement**: Implement "Safe Aliases" that check for the existence of a command before defining the alias.
- **Example**:
  ```zsh
  if command -v fzf >/dev/null; then
    # define fzf-related aliases
  else
    # define fallback grep-based aliases
  fi
  ```

## 4. SSH Agent Forwarding Optimization
- **Improvement**: Explicitly verify and handle SSH agent forwarding in the `xxhh` function to ensure your local keys (via Bitwarden or otherwise) are always available for git operations on the remote.

## 5. Build Performance & Caching
The current build clones P10k and plugins on the first run.
- **Improvement**: Use a local cache directory for these clones so they aren't deleted if you wipe the `build/` folder, making the first-time setup for a new machine much faster.

## 6. Terminal Integration
- **Improvement**: Automatically detect if the user is in VS Code or Windows Terminal and pass the `TERM_PROGRAM` variables to the remote so P10k can enable its shell integration features (like clickable paths and status marks).
