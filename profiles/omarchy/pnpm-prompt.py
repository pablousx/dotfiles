#!/usr/bin/env python3
"""Print pnpm project context without running a package manager or project code."""
import json
from pathlib import Path
import re


def context(directory):
    pnpm_project = False
    for root in (directory, *directory.parents):
        pnpm_project |= (root / "pnpm-lock.yaml").is_file() or (root / "pnpm-workspace.yaml").is_file()
        manifest = root / "package.json"
        try:
            # Avoid parsing unexpectedly large files on the prompt path.
            with manifest.open() as stream:
                data = stream.read(256 * 1024 + 1)
            if len(data) > 256 * 1024:
                continue
            package = json.loads(data)
            manager = package.get("packageManager", "") if isinstance(package, dict) else ""
        except (OSError, ValueError):
            continue
        if isinstance(manager, str) and manager:
            # Only emit a version, never arbitrary manifest text or escape sequences.
            match = re.fullmatch(r"pnpm@(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+[0-9A-Za-z.-]+)?", manager)
            if match:
                return "pnpm " + match[1]
            return "pnpm" if pnpm_project else ""
    return "pnpm" if pnpm_project else ""


if __name__ == "__main__":
    try:
        value = context(Path.cwd())
        if value:
            print(value)
    except OSError:
        pass  # An unavailable working directory must not break the prompt.
