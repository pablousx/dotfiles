#!/usr/bin/env bash
# Entry point for the Zsh profile mise installer.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/profiles/zsh/setup/mise.sh" "$@"
