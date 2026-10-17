#!/usr/bin/env python3
"""Stage Rulesync output and refuse to overwrite unreviewed global content."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def require_plain_path(path):
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise ValueError(f"Symlink conflict: {parent}; left unchanged")
        if parent != path and parent.exists() and not parent.is_dir():
            raise ValueError(f"Directory conflict: {parent}; left unchanged")


def sync(binary, dry_run):
    source = Path(__file__).resolve().parents[1] / "ai"
    config = json.loads((source / "rulesync.jsonc").read_text())
    # Extend the output allowlist and tests when adding another target.
    if config != {"global": True, "targets": ["codexcli"],
                  "features": ["rules", "skills"], "delete": False}:
        raise ValueError("Review sync-ai.py output paths before changing Rulesync targets/features")
    home = Path.home().resolve()
    state = home / ".local/state/dotfiles-ai"
    require_plain_path(state)
    # Copy only canonical inputs: no local config overlays, plugins or credentials.
    with tempfile.TemporaryDirectory(prefix="dotfiles-ai-") as temp:
        work = Path(temp) / "source"
        staged = Path(temp) / "home"
        staged.mkdir()
        for path in source.rglob("*"):
            if path.is_symlink():
                raise ValueError(f"Canonical AI sources must not be symlinks: {path}")
        shutil.copytree(source / ".rulesync", work / ".rulesync")
        shutil.copyfile(source / "rulesync.jsonc", work / "rulesync.jsonc")
        env = dict(os.environ, HOME=str(staged), XDG_CONFIG_HOME=str(staged / ".config"),
                   XDG_CACHE_HOME=str(staged / ".cache"), XDG_STATE_HOME=str(staged / ".local/state"),
                   CODEX_HOME=str(staged / ".codex"))
        command = [binary, "generate"]
        subprocess.run(command + ["--dry-run"], cwd=work, env=env, check=True)
        subprocess.run(command, cwd=work, env=env, check=True)
        outputs = []
        for generated in sorted(staged.rglob("*")):
            if generated.is_dir():
                continue
            relative = generated.relative_to(staged)
            if (generated.is_symlink() or not generated.is_file() or
                not (relative == Path(".codex/AGENTS.md") or
                     (relative.parts[:2] == (".agents", "skills") and len(relative.parts) >= 4))):
                raise ValueError(f"Unexpected Rulesync output: {relative}; nothing installed")
            if relative.parts[:2] == (".agents", "skills"):
                legacy = home / ".codex/skills" / relative.parts[2]
                if legacy.exists() or legacy.is_symlink():
                    raise ValueError(f"Legacy skill conflict: {legacy}; review before creating a duplicate")
            target = home / relative
            previous = state / relative
            require_plain_path(target)
            require_plain_path(previous)
            if previous.exists() and not previous.is_file():
                raise ValueError(f"State conflict: {previous}; nothing installed")
            content = generated.read_bytes()
            if target.exists() and (not target.is_file() or
                (target.read_bytes() != content and
                 (not previous.is_file() or target.read_bytes() != previous.read_bytes()))):
                raise ValueError(f"Content conflict: {target}; preserve/reconcile it with ai/.rulesync first. Nothing installed")
            outputs.append((generated, target, previous, content))
        for generated, target, previous, content in outputs:
            print(f"{'Would sync' if dry_run else 'Sync'}: {target}", flush=True)
            if not dry_run:
                target.parent.mkdir(parents=True, exist_ok=True)
                if not target.exists() or target.read_bytes() != content:
                    shutil.copy2(generated, target)
                previous.parent.mkdir(parents=True, exist_ok=True)
                previous.write_bytes(content)


if __name__ == "__main__":
    try:
        sync(sys.argv[1], sys.argv[2:] == ["--dry-run"])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"error: {error}")
