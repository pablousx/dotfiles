# Compatibility entrypoint for existing Bash startup files.
# shellcheck source=profiles/omarchy/bash/helpers.bash
source "$(builtin cd -- "$(command dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/profiles/omarchy/bash/helpers.bash"
