# Omarchy profile

This profile extends an existing Omarchy installation with Bash helpers,
completions, history synchronization, a Starship prompt, an optional saved
Spanish AltGr keyboard layout, and optional all-display brightness bindings.

Run `./setup.sh` from the repository root for automatic selection on Omarchy,
or `./setup.sh --profile omarchy`. See the [repository guide](../../README.md)
for component flags, keyboard save/restore, brightness setup, and removal commands.

This directory owns setup scripts, Bash runtime code, Python helper programs,
and Starship/Hyprland/XKB assets. Settings remain in the root `.env.omarchy`.
Existing startup paths continue through compatibility entrypoints. The default
interactive keyboard choice is None, which leaves the current layout unchanged.
