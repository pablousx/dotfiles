#!/usr/bin/env bash
# Compatibility entrypoint; implementation belongs to its profile.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/profiles/omarchy/setup/omarchy.sh" "$@"
