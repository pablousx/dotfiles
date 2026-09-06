# Portable distro profiles

The Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE/SUSE, and macOS profiles share
this Zsh implementation. Package installation follows the detected distribution.
WSL follows its Linux distribution.

Run `./setup.sh` from the repository root for automatic selection, or
`./setup.sh --profile zsh` to select this implementation explicitly.
See the [repository guide](../../README.md) for setup flags and settings.

This directory owns startup files, Powerlevel10k configuration, pinned Antidote
plugins, completions, and component installers. Settings remain in the root
`.env`; cache and Antidote state remain at their existing paths. The root Zsh
startup files are compatibility links to this directory.

Change plugin pins with the root `scripts/update-plugin-pin.sh` command, which
updates `modules/plugins.txt` and regenerates `modules/plugins.zsh` here.
