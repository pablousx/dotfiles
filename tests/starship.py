#!/usr/bin/env python3
"""Render the real preset in isolated project contexts; no tool installations."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
starship = shutil.which("starship")
if not starship:
    print("skip - Starship rendering (not installed; required by Arch CI)")
    raise SystemExit(0)
with tempfile.TemporaryDirectory() as temporary:
    home = Path(temporary)
    project = home / "project"
    project.mkdir()
    binaries = home / "bin"
    binaries.mkdir()
    for name, output in (("node", "v24.12.0"), ("pnpm", "10.0.0")):
        script = binaries / name
        script.write_text(f"#!/bin/sh\nprintf '%s\\n' '{output}'\n")
        script.chmod(0o755)
    env = {key: value for key, value in os.environ.items()
           if key in ("PATH", "USER", "LOGNAME", "LANG", "SYSTEMROOT")}
    env.update(DOTFILES_DIR=str(ROOT), HOME=str(home), STARSHIP_CONFIG=str(ROOT / "config/starship-omarchy.toml"),
               STARSHIP_CACHE=str(home / "cache"), STARSHIP_SHELL="bash", TERM="xterm-256color")
    env["PATH"] = str(binaries) + os.pathsep + env["PATH"]

    def render(*args, extra=None):
        result = subprocess.run([starship, "prompt", *args], cwd=project,
                                env=env | (extra or {}), text=True, capture_output=True, check=True)
        assert not result.stderr, result.stderr
        return result.stdout

    plain = render()
    assert "❯" in plain and "node " not in plain and "pnpm " not in plain
    assert "exit 7" in render("--status", "7")
    assert "jobs:2" in render("--jobs", "2")
    subprocess.run(["git", "init", "-q", "-b", "prompt-test", str(project)], check=True)
    assert "prompt-test" in render()
    (project / "package.json").write_text('{"name":"fixture","packageManager":"pnpm@10.0.0"}')
    (project / "pnpm-lock.yaml").touch()
    # pnpm must never be launched, even if it is slow, broken or would bootstrap tools.
    marker = home / "pnpm-was-executed"
    (binaries / "pnpm").write_text(f"#!/bin/sh\ntouch '{marker}'\nsleep 2\nexit 99\n")
    node = render()
    assert "node v24.12.0" in node and "pnpm 10.0.0" in node, repr(node)
    assert not marker.exists()
    # Workspace children inherit the declared version without spawning pnpm.
    workspace = project / "packages" / "child"
    workspace.mkdir(parents=True)
    (workspace / "package.json").write_text('{"name":"child"}')
    rendered = subprocess.run([starship, "prompt"], cwd=workspace, env=env,
                              text=True, capture_output=True, check=True)
    assert "pnpm 10.0.0" in rendered.stdout and not rendered.stderr
    (project / "package.json").write_text('{"name":"fixture"}')
    no_pin = render()
    assert "pnpm" in no_pin and "pnpm 10.0.0" not in no_pin
    assert not marker.exists()
    virtualenv = home / "test-venv"
    virtualenv.mkdir()
    assert "test-venv" in render(extra={"VIRTUAL_ENV": str(virtualenv)})
    assert "@" in render(extra={"SSH_CONNECTION": "127.0.0.1 22 127.0.0.1 22"})
    assert "@" in render(extra={"DOTFILES_ROOT_CONTEXT": "1"})
print("ok - Starship directory, Git, status, jobs, runtimes, virtualenv and host contexts")
