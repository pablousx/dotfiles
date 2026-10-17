#!/usr/bin/env python3
"""Offline preservation tests; Rulesync itself is validated separately."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sync_ai", ROOT / "scripts/sync-ai.py")
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


class Preservation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.outputs = {".codex/AGENTS.md": b"global rules\n",
                        ".agents/skills/personal/SKILL.md": b"personal skill\n"}
        self.calls = []

    def generate(self, command, *, cwd, env, check):
        self.calls.append(command)
        if "--dry-run" not in command:
            self.assertIn("--dry-run", self.calls[-2])
            for relative, content in self.outputs.items():
                target = Path(env["HOME"]) / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                if target.suffix == ".sh":
                    target.chmod(0o755)

    def run_sync(self, dry=False):
        with patch.object(SYNC.Path, "home", return_value=self.home), \
             patch.object(SYNC.subprocess, "run", side_effect=self.generate), \
             contextlib.redirect_stdout(io.StringIO()):
            SYNC.sync("rulesync", dry)

    def write(self, relative, content):
        target = self.home / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        return target

    def test_dry_run_writes_nothing(self):
        self.run_sync(True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_skill_scripts_keep_executable_permission(self):
        relative = ".agents/skills/personal/scripts/run.sh"
        self.outputs[relative] = b"#!/bin/sh\nexit 0\n"
        self.run_sync()
        self.assertEqual((self.home / relative).stat().st_mode & 0o777, 0o755)

    def test_install_repeat_update_and_preserve_unrelated(self):
        unrelated = self.write(".agents/skills/foreign/SKILL.md", b"keep")
        credentials = self.write(".codex/auth.json", b"untouched")
        self.run_sync()
        self.run_sync()
        self.outputs[".codex/AGENTS.md"] = b"updated rules\n"
        self.run_sync()
        self.assertEqual((self.home / ".codex/AGENTS.md").read_bytes(), b"updated rules\n")
        self.assertEqual(unrelated.read_bytes(), b"keep")
        self.assertEqual(credentials.read_bytes(), b"untouched")

    def test_conflict_prevents_all_writes(self):
        original = self.write(".codex/AGENTS.md", b"unreviewed rules")
        with self.assertRaisesRegex(ValueError, "Content conflict"):
            self.run_sync()
        self.assertEqual(original.read_bytes(), b"unreviewed rules")
        self.assertFalse((self.home / ".agents").exists())
        self.assertFalse((self.home / ".local").exists())

    def test_local_edits_are_preserved(self):
        self.run_sync()
        edited = self.write(".agents/skills/personal/SKILL.md", b"local edits")
        self.outputs[".codex/AGENTS.md"] = b"new rules"
        with self.assertRaisesRegex(ValueError, "Content conflict"):
            self.run_sync()
        self.assertEqual(edited.read_bytes(), b"local edits")
        self.assertEqual((self.home / ".codex/AGENTS.md").read_bytes(), b"global rules\n")

    def test_symlinks_are_not_followed(self):
        external = self.home / "external"
        external.mkdir()
        (self.home / ".agents").symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink conflict"):
            self.run_sync()
        self.assertEqual(list(external.iterdir()), [])

    def test_legacy_skill_duplicate_is_refused(self):
        self.write(".codex/skills/personal/SKILL.md", b"legacy")
        with self.assertRaisesRegex(ValueError, "Legacy skill conflict"):
            self.run_sync()
        self.assertFalse((self.home / ".agents").exists())

    def test_parent_file_conflict_prevents_all_writes(self):
        self.write(".codex", b"file instead of directory")
        with self.assertRaisesRegex(ValueError, "Directory conflict"):
            self.run_sync()
        self.assertFalse((self.home / ".agents").exists())

    def test_unexpected_output_is_refused(self):
        self.outputs[".codex/config.toml"] = b"model config"
        with self.assertRaisesRegex(ValueError, "Unexpected Rulesync output"):
            self.run_sync()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_removed_sources_do_not_delete_installed_skills(self):
        self.run_sync()
        del self.outputs[".agents/skills/personal/SKILL.md"]
        self.run_sync()
        self.assertTrue((self.home / ".agents/skills/personal/SKILL.md").is_file())


class InteractiveSetup(unittest.TestCase):
    def test_ai_prompt_and_removed_flag_in_both_profiles(self):
        for profile in ("zsh", "omarchy"):
            with self.subTest(profile=profile), tempfile.TemporaryDirectory() as temp:
                repo = Path(temp)
                setup = repo / "setup"
                setup.mkdir()
                shutil.copy2(ROOT / "setup/lib.sh", setup / "lib.sh")
                with (setup / "lib.sh").open("a") as lib:
                    lib.write("\ndetect_platform() { DETECTED_PROFILE=omarchy; }\n"
                              "omarchy() { return 0; }\n")
                relative = ("profiles/zsh/setup.sh" if profile == "zsh" else
                            "profiles/omarchy/setup/omarchy.sh")
                script = repo / relative
                script.parent.mkdir(parents=True)
                shutil.copy2(ROOT / relative, script)
                components = (repo / "profiles/zsh/setup" if profile == "zsh" else script.parent)
                components.mkdir(exist_ok=True)
                for name in ("core", "zsh", "modules", "bash-startup", "keyboard", "brightness-knob"):
                    (components / f"{name}.sh").write_text("#!/bin/bash\nexit 0\n")
                (setup / "tools.sh").write_text('printf "%s" "$1" > "$TOOLS_LOG"\n')
                (setup / "ai.sh").write_text('printf "%s" "$1" > "$AI_LOG"\n')
                plugin_log = repo / "plugin-log"
                if profile == "omarchy":
                    (repo / "omasync").mkdir()
                    (repo / "omasync/install.py").write_text(
                        'import os\nfrom pathlib import Path\n'
                        'Path(os.environ["PLUGIN_LOG"]).write_text("install")\n')
                log = repo / "ai-log"
                tools_log = repo / "tools-log"
                env = dict(os.environ, HOME=str(repo), AI_LOG=str(log), TOOLS_LOG=str(tools_log),
                           PLUGIN_LOG=str(plugin_log), XDG_CONFIG_HOME=str(repo / ".config"))
                prefix = ["n", "n", "n"] if profile == "zsh" else ["n", "n", "n", "", "n"]
                modules = ["n"] * 5  # Omarchy also declines the optional plugin.
                for answer, expected in (("y", "install"), ("n", "skip"), ("", "skip")):
                    result = subprocess.run(["bash", str(script)],
                                            input="\n".join(prefix + [answer] + modules + ["y", ""]),
                                            text=True, env=env, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(log.read_text(), expected)
                    self.assertEqual(tools_log.read_text(), "skip")
                    self.assertIn("Global AI configuration:", result.stdout)
                    self.assertFalse(plugin_log.exists())
                log.unlink()
                tools_log.unlink()
                cancelled = subprocess.run(["bash", str(script)],
                                           input="\n".join(prefix + ["y"] + modules + ["n", ""]),
                                           text=True, env=env, capture_output=True)
                self.assertNotEqual(cancelled.returncode, 0)
                self.assertFalse(log.exists())
                self.assertFalse(tools_log.exists())
                self.assertFalse(plugin_log.exists())
                removed = subprocess.run(["bash", str(script), "--ai"], env=env, capture_output=True)
                self.assertNotEqual(removed.returncode, 0)
                self.assertFalse(log.exists())
                self.assertFalse(tools_log.exists())
                for flag, expected in (("--tools", "install"), ("--core", "skip"),
                                       ("--all", "install")):
                    automated = subprocess.run(["bash", str(script), flag], env=env,
                                               capture_output=True, text=True)
                    self.assertEqual(automated.returncode, 0, automated.stderr)
                    self.assertEqual(tools_log.read_text(), expected)
                    self.assertEqual(log.read_text(), "skip")
                    self.assertFalse(plugin_log.exists())
                if profile == "omarchy":
                    explicit = subprocess.run(["bash", str(script), "--omasync"], env=env,
                                              capture_output=True, text=True)
                    self.assertNotEqual(explicit.returncode, 0)
                    self.assertFalse(plugin_log.exists())
                    interactive_plugin = subprocess.run(
                        ["bash", str(script)], env=env, capture_output=True, text=True,
                        input="\n".join(prefix + ["n", "y"] + ["n"] * 4 + ["y", ""]))
                    self.assertEqual(interactive_plugin.returncode, 0, interactive_plugin.stderr)
                    self.assertEqual(plugin_log.read_text(), "install")
                    plugin_log.unlink()
                    installed_plugin = repo / ".config/omarchy/plugins/io.github.pablousx.omasync"
                    installed_plugin.mkdir(parents=True)
                    (installed_plugin / "manifest.json").write_text('{"version": "old"}')
                    for answer in ("n", "", "y"):
                        updated = subprocess.run(
                            ["bash", str(script)], env=env, capture_output=True, text=True,
                            input="\n".join(prefix + ["n", answer] + ["n"] * 4 + ["y", ""]))
                        self.assertEqual(updated.returncode, 0, updated.stderr)
                        self.assertIn("omasync plugin: " + ("update" if answer == "y" else "skip"), updated.stdout)
                        self.assertEqual(plugin_log.exists(), answer == "y")
                    self.assertEqual((installed_plugin / "manifest.json").read_text(), '{"version": "old"}')


if __name__ == "__main__":
    unittest.main()
