#!/usr/bin/env python3
"""Exercise repository commands with local remotes and a mocked AI generator."""
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepositoryCommands(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-repository-")
        self.addCleanup(self.temp.cleanup)
        # Use physical paths: macOS TMPDIR may pass through /var -> /private/var.
        base = Path(self.temp.name).resolve()
        self.repo = base / "repo with spaces"
        self.home = base / "home"
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), DOTFILES_DIR=str(self.repo),
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        self.git("init", "--bare", str(base / "remote.git"), cwd=base)
        self.git("clone", str(base / "remote.git"), str(self.repo), cwd=base)
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        (self.repo / "ai").mkdir()
        (self.repo / "ai/rule.md").write_text("initial\n")
        (self.repo / "tracked").write_text("initial\n")
        self.git("add", ".")
        self.git("commit", "-m", "initial")
        self.git("push", "-u", "origin", "HEAD")
        (self.repo / "omasync").mkdir()
        shutil.copyfile(ROOT / "omasync/sync.py", self.repo / "omasync/sync.py")
        (self.repo / "scripts").mkdir()
        (self.repo / ".git/info/exclude").write_text("omasync/\nscripts/\n")
        (self.repo / "scripts/sync-ai.sh").write_text(
            'printf "synced\\n" >> "$HOME/sync-log"\nexit "${SYNC_EXIT:-0}"\n')

    def git(self, *args, cwd=None):
        return subprocess.run(["git", "-C", str(cwd or self.repo), *args],
                              env=self.env, text=True, capture_output=True, check=True).stdout

    def run_df(self, args, **env):
        return subprocess.run(
            ["bash", "-c", 'source "$1"; shift; df "$@"', "_",
             str(ROOT / "shared/repository.sh"), *args],
            input="test update\n", env=dict(self.env, **env), text=True, capture_output=True)

    def enable_ai(self):
        marker = self.home / ".local/state/dotfiles-ai/.codex/AGENTS.md"
        marker.parent.mkdir(parents=True)
        marker.write_text("managed")

    def test_git_helper_uses_repository_and_preserves_arguments(self):
        # macOS temporary directories also have symlinked paths (/var -> /private/var).
        alias = self.repo.parent / "repository link"
        alias.symlink_to(self.repo, target_is_directory=True)
        self.repo = alias
        self.env["DOTFILES_DIR"] = str(alias)
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; shift; _dotfiles_git "$@"', "_",
             str(ROOT / "shared/repository.sh"), "rev-parse", "--show-toplevel"],
            cwd=self.home, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).resolve(), self.repo.resolve())
        (self.repo / "file with spaces").write_text("tracked")
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; shift; _dotfiles_git "$@"', "_",
             str(ROOT / "shared/repository.sh"), "add", "--", "file with spaces"],
            cwd=self.home, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("diff", "--cached", "--name-only").strip(), "file with spaces")

    def test_upload_includes_new_ai_only(self):
        self.enable_ai()
        (self.repo / "ai/new-skill.md").write_text("new")
        (self.repo / "private").write_text("untracked")
        result = self.run_df(["up"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ai/new-skill.md", self.git("ls-tree", "-r", "--name-only", "HEAD"))
        self.assertNotIn("private", self.git("ls-tree", "-r", "--name-only", "HEAD"))
        self.assertEqual(self.git("rev-parse", "HEAD"), self.git("rev-parse", "@{upstream}"))
        self.assertEqual((self.home / "sync-log").read_text(), "synced\n")

    def test_ai_conflict_stops_upload_before_staging(self):
        self.enable_ai()
        (self.repo / "tracked").write_text("changed")
        before = self.git("rev-parse", "HEAD")
        self.assertNotEqual(self.run_df(["up"], SYNC_EXIT="1").returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        self.assertEqual(self.git("diff", "--cached"), "")

    def test_unconfigured_machine_skips_ai(self):
        result = self.run_df(["down"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "sync-log").exists())

    def test_download_applies_pulled_sources(self):
        self.enable_ai()
        old = self.git("rev-parse", "HEAD").strip()
        (self.repo / "ai/rule.md").write_text("updated")
        self.git("add", "ai")
        self.git("commit", "-m", "remote update")
        self.git("push")
        # Only this disposable checkout is reset to simulate a second machine.
        self.git("reset", "--hard", old)
        result = self.run_df(["down"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "ai/rule.md").read_text(), "updated")
        self.assertTrue((self.home / "sync-log").exists())

    def test_pull_conflict_stops_ai(self):
        self.enable_ai()
        self.git("remote", "remove", "origin")
        self.assertNotEqual(self.run_df(["down"]).returncode, 0)
        self.assertFalse((self.home / "sync-log").exists())

    def test_disk_usage_and_argument_validation(self):
        self.assertEqual(self.run_df(["-h", str(self.home)]).returncode, 0)
        self.assertEqual(self.run_df(["up", "extra"]).returncode, 2)


if __name__ == "__main__":
    unittest.main()
