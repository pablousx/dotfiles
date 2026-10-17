#!/usr/bin/env python3
"""Opt-in local plugin installer; no dependencies are installed."""
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import tempfile


class ShellUnavailable(RuntimeError):
    pass


def confirm_shell(command, stage):
    # Writing plugin files can trigger a hot reload before our explicit rescan.
    # Allow it to finish, and retry boundedly without restarting the desktop.
    env = dict(os.environ, OMARCHY_SHELL_IPC_TIMEOUT="10s")
    for attempt in range(3):
        try:
            subprocess.run(command, check=True, env=env, timeout=15,
                           capture_output=True, text=True)
            return
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            if attempt == 2:
                raise ShellUnavailable(
                    f"omasync: plugin files were copied, but Omarchy did not confirm {stage}. "
                    "Retry: python3 ./omasync/install.py install") from error
            time.sleep(0.5)


def atomic_text(destination, content):
    # Stage outside the watched plugin directory; publish complete files only.
    fd, name = tempfile.mkstemp(prefix=".omasync-", dir=destination.parent.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.replace(name, destination)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def publish_ui(target, contents):
    revision = hashlib.sha256(json.dumps(contents, sort_keys=True).encode()).hexdigest()[:20]
    runtime = target / "runtime"
    version = runtime / revision
    for directory in (runtime, version):
        if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
            raise ValueError("Plugin runtime conflict; left unchanged")
    if version.exists():
        for name, content in contents.items():
            path = version / name
            if not path.is_file() or path.is_symlink() or path.read_text() != content:
                raise ValueError("Installed UI revision was modified; left unchanged")
        return revision
    runtime.mkdir(exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".omasync-ui-", dir=target.parent))
    try:
        for name, content in contents.items():
            (staging / name).write_text(content)
        os.replace(staging, version)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return revision


def install(repo):
    for command in ("git", "python3", "omarchy", "omarchy-shell"):
        if not shutil.which(command):
            raise ValueError("Missing prerequisite: " + command)
    plugin_id = "io.github.pablousx.omasync"
    target = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "omarchy/plugins" / plugin_id
    for parent in (target, *target.parents):
        if parent.is_symlink():
            raise ValueError("Plugin destination must not contain symlinks")
    # Only update a plugin previously installed by this installer.
    marker = target / ".dotfiles-managed"
    if target.exists() and not marker.is_file():
        raise ValueError("Unmanaged plugin directory; left unchanged")
    installed = marker.is_file()
    pending = target / ".dotfiles-enable-pending"
    files = ("manifest.json", "BarWidget.qml", "Panel.qml", "UiText.qml", "UiAction.qml")
    for name in (".dotfiles-managed", ".dotfiles-enable-pending", *files):
        destination = target / name
        if destination.is_symlink() or (destination.exists() and not destination.is_file()):
            raise ValueError("Plugin file conflict; left unchanged: " + name)
    if target.exists() and any(path.is_symlink() for path in target.rglob("*")):
        raise ValueError("Plugin directory contains symlinks; left unchanged")
    source = repo / "omasync"
    subprocess.run(["omarchy", "plugin", "validate", str(source)], check=True)
    contents = {name: (source / name).read_text() for name in files if name != "manifest.json"}
    contents["BarWidget.qml"] = contents["BarWidget.qml"].replace(
        'property string repository: ""', "property string repository: " + json.dumps(str(repo)))
    manifest = json.loads((source / "manifest.json").read_text())
    target.mkdir(parents=True, exist_ok=True)
    if not installed:
        pending.write_text("initial activation pending\n")
    marker.write_text(str(repo) + "\n")
    revision = publish_ui(target, contents)
    manifest["entryPoints"]["barWidget"] = f"runtime/{revision}/BarWidget.qml"
    content = json.dumps(manifest, indent=2) + "\n"
    if not (target / "manifest.json").is_file() or (target / "manifest.json").read_text() != content:
        atomic_text(target / "manifest.json", content)
    confirm_shell(["omarchy-shell", "shell", "rescanPlugins"], "plugin reload")
    if pending.is_file():
        confirm_shell(["omarchy", "plugin", "enable", plugin_id, "--section", "right"], "initial activation")
        pending.unlink()
    return revision


if __name__ == "__main__":
    if sys.argv[1:] == ["skip"]:
        sys.exit(0)
    if sys.argv[1:] != ["install"]:
        sys.exit("usage: python3 omasync/install.py install|skip")
    try:
        revision = install(Path(__file__).resolve().parents[1])
    except (OSError, ValueError, subprocess.CalledProcessError, ShellUnavailable) as error:
        sys.exit(str(error))
    print(f"omasync: UI revision {revision} published; shell rescan requested.")
