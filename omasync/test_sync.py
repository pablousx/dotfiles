#!/usr/bin/env python3
"""No real installers, network services, agents, or desktop activation."""
import fcntl
from datetime import datetime, timezone
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest
from unittest import mock

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from repository import RepositoryCommands, ROOT

spec = importlib.util.spec_from_file_location("omasync_install", ROOT / "omasync/install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
sync_spec = importlib.util.spec_from_file_location("omasync_engine", ROOT / "omasync/sync.py")
sync_module = importlib.util.module_from_spec(sync_spec)
sync_spec.loader.exec_module(sync_module)


class SyncTests(RepositoryCommands):
    def sync(self, action, *args, **env):
        return subprocess.run([sys.executable, str(self.repo / "omasync/sync.py"),
                               "--repo", str(self.repo), action, *args],
                              env=dict(self.env, **env), stdin=subprocess.DEVNULL,
                              text=True, capture_output=True)

    def state(self):
        result = self.sync("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def remote_update(self):
        other = self.repo.parent / "other"
        self.git("clone", str(self.repo.parent / "remote.git"), str(other))
        self.git("config", "user.name", "Other", cwd=other)
        self.git("config", "user.email", "other@example.invalid", cwd=other)
        (other / "tracked").write_text("from other machine\n")
        self.git("add", ".", cwd=other)
        self.git("commit", "-m", "remote", cwd=other)
        self.git("push", cwd=other)

    def test_check_never_downloads_or_uploads(self):
        before = self.git("rev-parse", "HEAD")
        self.remote_update()
        result = self.sync("tick")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "remote")
        self.assertEqual(self.git("rev-parse", "HEAD"), before)

    def test_auto_fast_forward_and_ai_opt_in(self):
        self.remote_update()
        result = self.sync("tick", "--auto-download")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.repo / "tracked").read_text(), "from other machine\n")
        self.assertEqual(self.state()["ai"], "disabled")
        self.assertFalse((self.home / "sync-log").exists())

    def test_auto_preserves_dirty_and_untracked_files(self):
        self.remote_update()
        for name in ("tracked", "untracked"):
            with self.subTest(name=name):
                path = self.repo / name
                path.write_text("local changes")
                before = self.git("rev-parse", "HEAD")
                self.assertNotEqual(self.sync("tick", "--auto-download").returncode, 0)
                self.assertEqual(self.git("rev-parse", "HEAD"), before)
                self.assertEqual(path.read_text(), "local changes")
                if name == "tracked":
                    path.write_text("initial\n")

    def test_divergence_never_merges_or_discards(self):
        self.remote_update()
        (self.repo / "tracked").write_text("local committed")
        self.git("add", "tracked")
        self.git("commit", "-m", "local")
        before = self.git("rev-parse", "HEAD")
        self.assertNotEqual(self.sync("tick", "--auto-download").returncode, 0)
        self.assertNotEqual(self.run_df(["down"]).returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        self.assertFalse((self.repo / ".git/MERGE_HEAD").exists())

    def test_detached_or_no_upstream_refused(self):
        self.remote_update()
        self.git("branch", "--unset-upstream")
        self.assertNotEqual(self.sync("download").returncode, 0)
        self.git("checkout", "--detach")
        self.assertNotEqual(self.sync("download").returncode, 0)
        self.assertNotEqual(self.run_df(["up"]).returncode, 0)

    def test_ai_failure_after_pull_persists_until_successful_retry(self):
        self.enable_ai()
        self.remote_update()
        result = self.sync("tick", "--auto-download", SYNC_EXIT="1")
        self.assertNotEqual(result.returncode, 0)
        state = self.state()
        self.assertTrue(state["repo_updated"])
        self.assertEqual(state["ai"], "failed")
        self.assertEqual(state["operation"], "auto-down")
        self.assertEqual(self.sync("check").returncode, 0)
        self.assertEqual(self.state()["status"], "error")
        self.assertEqual(self.sync("download").returncode, 0)
        self.assertEqual(self.state()["ai"], "applied")
        self.assertFalse(self.state()["repo_updated"])
        self.assertEqual(self.state()["status"], "updated")

    def test_shared_lock_refuses_cli_and_reports_syncing(self):
        with (self.repo / ".git/omasync.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_df(["up"]).returncode, 0)
            self.assertNotEqual(self.sync("upload").returncode, 0)
            self.assertNotEqual(self.run_df(["down"]).returncode, 0)
            self.assertEqual(self.state()["status"], "syncing")
            self.assertEqual(json.loads(self.sync("tick", "--auto-download").stdout)["status"], "syncing")
        self.assertEqual(self.sync("download").returncode, 0)

    def test_status_readers_share_lock_without_false_syncing_or_writes(self):
        self.sync("download")
        state_path = self.repo / ".git/omasync-state.json"
        before = state_path.read_bytes()
        with (self.repo / ".git/omasync.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
            readers = [subprocess.Popen(
                [sys.executable, str(self.repo / "omasync/sync.py"), "--repo", str(self.repo), "status"],
                env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
            for reader in readers:
                stdout, stderr = reader.communicate(timeout=5)
                self.assertEqual(reader.returncode, 0, stderr)
                self.assertEqual(json.loads(stdout)["status"], "updated")
            self.assertEqual(json.loads(self.sync("tick").stdout)["status"], "syncing")
            self.assertNotEqual(self.sync("upload").returncode, 0)
            self.assertEqual(state_path.read_bytes(), before)

    def test_passive_fetch_timeout_kills_group_releases_lock_and_can_retry(self):
        binary = self.repo.parent / "bin"
        binary.mkdir()
        child = ('import os, time; from pathlib import Path; '
                 'time.sleep(0.8); Path(os.environ["HOME"], "child-survived").touch()')
        (binary / "git").write_text(
            '#!' + sys.executable + '\nimport os, subprocess, sys, time\n'
            'from pathlib import Path\nargs = sys.argv[1:]\n'
            'if args[:1] == ["-C"] and args[2] == "fetch":\n'
            f'    subprocess.Popen([sys.executable, "-c", {child!r}])\n'
            '    Path(os.environ["HOME"], "fetch-started").touch()\n'
            '    time.sleep(60)\n'
            f'os.execv({shutil.which("git")!r}, ["git", *args])\n')
        (binary / "git").chmod(0o755)
        output = io.StringIO()
        with mock.patch.dict(os.environ, dict(self.env, PATH=str(binary) + os.pathsep + os.environ["PATH"])), \
                mock.patch.object(sys, "argv", ["sync.py", "--repo", str(self.repo), "check"]), \
                mock.patch.object(sync_module, "PASSIVE_TIMEOUT", 0.3), \
                mock.patch.object(sys, "stdout", output):
            started = time.monotonic()
            self.assertEqual(sync_module.main(), 1)
            self.assertLess(time.monotonic() - started, 3)
        self.assertTrue((self.home / "fetch-started").exists())
        self.assertIn("git fetch: timeout", json.loads(output.getvalue())["error"])
        with (self.repo / ".git/omasync.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        time.sleep(0.9)
        self.assertFalse((self.home / "child-survived").exists())
        self.assertEqual(self.sync("check").returncode, 0)
        self.assertEqual(self.state()["status"], "updated")

    def test_manual_operations_keep_normal_timeout(self):
        with mock.patch.dict(os.environ, self.env):
            self.assertEqual(sync_module.Engine(self.repo).command_timeout, 90)

    def test_qml_status_updates_keep_counts_and_recover_from_reader_failure(self):
        runner = shutil.which("qmltestrunner") or \
            ("/usr/lib/qt6/bin/qmltestrunner" if Path("/usr/lib/qt6/bin/qmltestrunner").exists() else None)
        if runner is None:
            self.skipTest("Qt qmltestrunner unavailable; live shell validation still required")
        source = (ROOT / "omasync/BarWidget.qml").read_text()
        functions = []
        for name in ("acceptSnapshot", "readStatus", "finishStatus"):
            start = source.index("    function " + name + "(")
            end = source.index("\n    }", start) + len("\n    }")
            functions.append(source[start:end])
        tests = self.repo.parent / "qmltests"
        tests.mkdir()
        # Execute the production QML functions using fake process objects, never
        # the actual widget/timers/shell or any real Git operation.
        (tests / "tst_Status.qml").write_text('''import QtQuick
import QtTest
TestCase {
    id: tests
    name: "StatusSnapshots"
    when: true
    Item {
        id: root
        property var snapshot: ({status: "unknown"})
        property string launcherError: ""
        property string repo: "fixture"
        property bool refreshPending: false
        function argv(action) { return ["mock", action] }
        QtObject { id: reader; property bool running: false; property var command: [] }
''' + "\n".join(functions) + '''
    }
    function init() {
        root.launcherError = ""
        root.refreshPending = false
        root.snapshot = {status: "local", ahead: 7, behind: 2, dirty: true}
        reader.running = false
    }
    function test_busy_keeps_counts_then_full_snapshot_replaces_them() {
        root.acceptSnapshot({status: "syncing", busy_operation: "check"})
        compare(root.snapshot.ahead, 7)
        compare(root.snapshot.behind, 2)
        root.finishStatus(0, JSON.stringify({status: "updated", ahead: 0, behind: 0, dirty: false}))
        compare(root.snapshot.status, "updated")
        compare(root.snapshot.ahead, 0)
        compare(root.snapshot.behind, 0)
    }
    function test_reader_failure_unsticks_syncing_and_recovers() {
        root.snapshot = {status: "syncing", ahead: 7}
        root.finishStatus(1, "")
        compare(root.snapshot.status, "error")
        compare(root.snapshot.ahead, 7)
        root.finishStatus(0, "broken JSON")
        compare(root.snapshot.status, "error")
        root.snapshot = {status: "syncing"}
        root.finishStatus(0, "{}")
        compare(root.snapshot.status, "error")
        root.finishStatus(0, JSON.stringify({status: "local", ahead: 7, error: ""}))
        compare(root.snapshot.status, "local")
        compare(root.snapshot.error, "")
    }
    function test_worker_completion_during_read_queues_immediate_refresh() {
        reader.running = true
        root.readStatus()
        verify(root.refreshPending)
        reader.running = false
        root.finishStatus(0, JSON.stringify({status: "syncing"}))
        tryCompare(reader, "running", true)
        compare(root.refreshPending, false)
        compare(reader.command[1], "status")
    }
}
''')
        result = subprocess.run([runner, "-input", str(tests), "-platform", "offscreen"],
                                env=dict(self.env, QSG_RHI_BACKEND="software", QML_DISABLE_DISK_CACHE="1",
                                         QT_QPA_PLATFORMTHEME="", QT_QUICK_CONTROLS_STYLE="Basic"),
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_interactive_upload_holds_lock_while_waiting_for_message(self):
        import time
        process = subprocess.Popen(
            [sys.executable, str(self.repo / "omasync/sync.py"), "--repo", str(self.repo), "up"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=self.env, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.repo / ".git/omasync-state.json").exists():
                self.assertIsNone(process.poll())
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.01)
            self.assertEqual(self.state()["status"], "syncing")
            self.assertNotEqual(self.run_df(["down"]).returncode, 0)
            self.assertIsNone(process.poll())
            stdout, stderr = process.communicate("manual message\n", timeout=5)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertIn("Commit message", stdout)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream:
                    stream.close()

    def test_active_git_operation_blocks_sync_before_ai(self):
        self.enable_ai()
        (self.repo / ".git/rebase-merge").mkdir()
        self.assertTrue(self.state()["in_progress"])
        self.assertNotEqual(self.run_df(["up"]).returncode, 0)
        self.assertNotEqual(self.sync("download").returncode, 0)
        self.assertFalse((self.home / "sync-log").exists())

    def test_network_error_retries_without_prompt_or_raw_secrets(self):
        remote = str(self.repo.parent / "remote.git")
        self.git("remote", "set-url", "origin", str(self.repo.parent / "SECRET-does-not-exist"))
        result = self.sync("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("SECRET", result.stdout + result.stderr)
        self.git("remote", "set-url", "origin", remote)
        self.assertEqual(self.sync("check").returncode, 0)
        self.assertEqual(self.state()["status"], "updated")

    def mock_git_failure(self):
        """Real local Git except one selected operation, with realistic stderr."""
        binary = self.repo.parent / "bin"
        binary.mkdir(exist_ok=True)
        (binary / "git").write_text(
            '#!' + sys.executable + '\nimport os, sys\nfrom pathlib import Path\n'
            'args = sys.argv[1:]\n'
            'action = args[2] if args[:1] == ["-C"] else args[0]\n'
            'with Path(os.environ["HOME"], "git-calls").open("a") as log:\n'
            '    log.write(action + "\\n")\n'
            'if action == os.environ.get("GIT_FAILURE_ACTION"):\n'
            '    print(os.environ["GIT_FAILURE_DIAGNOSTIC"], file=sys.stderr)\n'
            '    print(os.environ.get("GIT_FAILURE_OUTPUT", ""))\n'
            '    sys.exit(int(os.environ.get("GIT_FAILURE_EXIT", "128")))\n'
            f'os.execv({shutil.which("git")!r}, ["git", *args])\n')
        (binary / "git").chmod(0o755)
        return str(binary) + os.pathsep + os.environ["PATH"]

    def test_workflow_permission_refusal_preserves_commits_until_successful_retry(self):
        path = self.mock_git_failure()
        for actor, permission in (("an OAuth App", "`workflow` scope"),
                                  ("a Personal Access Token", "`workflow` scope"),
                                  ("a GitHub App", "`workflows` permission")):
            for source in ("stderr", "porcelain"):
                with self.subTest(actor=actor, source=source):
                    (self.home / "git-calls").write_text("")
                    remote_before = self.git("rev-parse", "@{upstream}")
                    content = actor + source
                    (self.repo / "tracked").write_text(content)
                    refusal = (f"refusing to allow {actor} to create or update workflow "
                               f"`.github/workflows/SECRET.yml` without {permission}")
                    output = ("!\tHEAD:refs/heads/SECRET\t[remote rejected] (" + refusal + ")"
                              if source == "porcelain" else "")
                    diagnostic = ("remote: " + refusal + "\n" if source == "stderr" else "")
                    diagnostic += "error: failed to push some refs to 'https://TOKEN_SECRET@example.invalid'"
                    result = self.sync("upload", PATH=path, GIT_FAILURE_ACTION="push",
                                       GIT_FAILURE_DIAGNOSTIC=diagnostic,
                                       GIT_FAILURE_OUTPUT=output, GIT_FAILURE_EXIT="1")
                    self.assertEqual(result.returncode, 1, result.stderr)
                    state = self.state()
                    self.assertEqual(state["error_reason"], "workflow_permission")
                    self.assertIn("git push: GitHub workflow permission required (exit 1)", state["error"])
                    self.assertIn("terminal, then retry", state["error"])
                    self.assertEqual(state["operation"], "up")
                    self.assertEqual(self.git("show", "HEAD:tracked"), content)
                    head = self.git("rev-parse", "HEAD")
                    self.assertEqual(self.git("rev-parse", "@{upstream}"), remote_before)
                    self.assertEqual(self.git("status", "--porcelain"), "")
                    calls = (self.home / "git-calls").read_text().splitlines()
                    self.assertEqual(calls.count("push"), 1)
                    self.assertNotIn("fetch", calls)
                    self.assertNotIn("rebase", calls)
                    self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")
                    self.assertEqual(self.sync("check").returncode, 0)
                    self.assertEqual(self.state()["error"], state["error"])
                    self.assertEqual(self.state()["error_reason"], "workflow_permission")
                    self.assertEqual(self.git("rev-parse", "HEAD"), head)
                    with mock.patch.dict(os.environ, self.env):
                        prompt = sync_module.Engine(self.repo).prompt()
                    persisted = (self.repo / ".git/omasync-state.json").read_text()
                    for evidence in (persisted, prompt, result.stdout, result.stderr):
                        for secret in ("SECRET", "https://", ".github/workflows/"):
                            self.assertNotIn(secret, evidence)
                    self.assertEqual(self.sync("upload").returncode, 0)
                    state = self.state()
                    self.assertEqual(state["error"], "")
                    self.assertEqual(state["error_reason"], "")
                    self.assertEqual(self.git("rev-parse", "HEAD"), head)
                    self.assertEqual(self.git("rev-parse", "@{upstream}"), head)

    def test_workflow_mentions_and_generic_exit1_do_not_imply_permission_refusal(self):
        path = self.mock_git_failure()
        for diagnostic in ("remote: workflow validation failed: SECRET",
                           "remote: permission denied for workflow SECRET",
                           "remote: refusing to allow an OAuth App to update branch SECRET",
                           "error: failed to push some refs to SECRET"):
            with self.subTest(diagnostic=diagnostic):
                (self.home / "git-calls").write_text("")
                result = self.sync("upload", PATH=path, GIT_FAILURE_ACTION="push",
                                   GIT_FAILURE_DIAGNOSTIC=diagnostic, GIT_FAILURE_EXIT="1")
                self.assertEqual(result.returncode, 1)
                state = self.state()
                self.assertNotEqual(state["error_reason"], "workflow_permission")
                self.assertIn("exit 1", state["error"])
                self.assertNotIn("SECRET", result.stdout + result.stderr)
                calls = (self.home / "git-calls").read_text().splitlines()
                self.assertEqual(calls.count("push"), 1)
                self.assertNotIn("fetch", calls)
                self.assertNotIn("rebase", calls)

    def test_workflow_refusal_is_classified_only_for_push(self):
        result = self.sync("check", PATH=self.mock_git_failure(), GIT_FAILURE_ACTION="fetch",
                           GIT_FAILURE_DIAGNOSTIC=("remote: refusing to allow an OAuth App to create "
                                                   "or update workflow `SECRET` without `workflow` scope"),
                           GIT_FAILURE_EXIT="1")
        self.assertEqual(result.returncode, 1)
        self.assertNotEqual(json.loads(result.stdout)["error_reason"], "workflow_permission")
        self.assertNotIn("SECRET", result.stdout + result.stderr)

    def test_noninteractive_auth_diagnostics_preserve_push_failure_until_retry(self):
        path = self.mock_git_failure()
        diagnostics = (
            "fatal: could not read Username for 'https://SECRET@example.invalid': terminal prompts disabled",
            "fatal: could not read Password for 'https://SECRET@example.invalid': No such device or address",
            "fatal: Authentication failed for 'https://SECRET@example.invalid/repo'",
            "remote: HTTP Basic: Access denied. SECRET",
            "remote: Invalid username or token. SECRET",
        )
        for diagnostic in diagnostics:
            with self.subTest(diagnostic=diagnostic):
                (self.home / "git-calls").write_text("")
                before = self.git("rev-parse", "HEAD")
                result = self.sync("upload", PATH=path, GIT_FAILURE_ACTION="push",
                                   GIT_FAILURE_DIAGNOSTIC=diagnostic)
                self.assertEqual(result.returncode, 1, result.stderr)
                state = self.state()
                self.assertEqual(state["error_reason"], "authentication")
                self.assertIn("git push: authentication required (exit 128)", state["error"])
                self.assertIn("terminal", state["error"])
                calls = (self.home / "git-calls").read_text().splitlines()
                self.assertEqual(calls.count("push"), 1)
                self.assertNotIn("fetch", calls)
                self.assertNotIn("rebase", calls)
                self.assertEqual(self.git("rev-parse", "HEAD"), before)
                self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")
                self.assertEqual(self.sync("check").returncode, 0)
                self.assertEqual(self.state()["error"], state["error"])
                self.assertEqual(self.state()["error_reason"], "authentication")
                with mock.patch.dict(os.environ, self.env):
                    prompt = sync_module.Engine(self.repo).prompt()
                persisted = (self.repo / ".git/omasync-state.json").read_text()
                for evidence in (persisted, prompt, result.stdout, result.stderr):
                    self.assertNotIn("SECRET", evidence)
                    self.assertNotIn("https://", evidence)
                self.assertEqual(self.sync("upload").returncode, 0)
                state = self.state()
                self.assertEqual(state["error"], "")
                self.assertEqual(state["error_reason"], "")
                persisted = json.loads((self.repo / ".git/omasync-state.json").read_text())
                self.assertEqual(persisted["check_error_reason"], "")

    def test_network_and_generic_exit128_are_not_authentication(self):
        path = self.mock_git_failure()
        for diagnostic, reason in (
                ("fatal: unable to access 'https://SECRET': Could not resolve host: example.invalid", "network"),
                ("fatal: unable to access 'https://SECRET': Failed to connect to server", "network"),
                ("fatal: unable to access 'https://SECRET': server returned error: 500", "network_access"),
                ("fatal: bad object SECRET", "")):
            with self.subTest(reason=reason):
                result = self.sync("check", PATH=path, GIT_FAILURE_ACTION="fetch",
                                   GIT_FAILURE_DIAGNOSTIC=diagnostic)
                self.assertEqual(result.returncode, 1)
                state = json.loads(result.stdout)
                self.assertEqual(state["error_reason"], reason)
                self.assertNotIn("authentication", state["error"])
                self.assertIn("git fetch:", state["error"])
                self.assertIn("exit 128", state["error"])
                self.assertNotIn("SECRET", result.stdout + result.stderr)
                self.assertEqual(self.sync("check").returncode, 0)
                self.assertEqual(self.state()["error_reason"], "")
                self.assertEqual(self.state()["error"], "")

    def test_fetch_auth_failure_and_successful_download_clear_metadata(self):
        result = self.sync("check", PATH=self.mock_git_failure(), GIT_FAILURE_ACTION="fetch",
                           GIT_FAILURE_DIAGNOSTIC="fatal: could not read Username: terminal prompts disabled")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["error_reason"], "authentication")
        self.assertEqual(self.sync("download").returncode, 0)
        persisted = json.loads((self.repo / ".git/omasync-state.json").read_text())
        for key in ("error", "error_reason", "check_error", "check_error_reason"):
            self.assertEqual(persisted[key], "")

    def test_legacy_state_without_reason_remains_visible_after_check(self):
        (self.repo / ".git/omasync-state.json").write_text(json.dumps(
            {"operation": "up", "error": "git push: command failed (exit 128); inspect locally, then retry",
             "ai": "failed", "repo_updated": True}))
        self.assertEqual(self.sync("check").returncode, 0)
        state = self.state()
        self.assertEqual(state["status"], "error")
        self.assertEqual(state["operation"], "up")
        self.assertEqual(state["error_reason"], "")
        self.assertEqual(state["ai"], "failed")
        self.assertTrue(state["repo_updated"])

    def mock_omarchy(self, supports_prompt=True):
        binary = self.repo.parent / "bin"
        binary.mkdir(exist_ok=True)
        (binary / "omarchy").write_text(
            '#!' + sys.executable + '\nimport json, os, sys\n'
            'from pathlib import Path\n'
            'if sys.argv[1:] == ["agent", "prompt", "--help"]:\n'
            f'    sys.exit({0 if supports_prompt else 1})\n'
            'Path(os.environ["HOME"], "launch.json").write_text(json.dumps('
            '{"argv": sys.argv[1:], "cwd": os.getcwd()}))\n')
        (binary / "omarchy").chmod(0o755)
        return str(binary) + os.pathsep + os.environ["PATH"]

    def test_official_ai_launcher_context_and_recheck(self):
        self.enable_ai()
        self.assertNotEqual(self.run_df(["up"], SYNC_EXIT="1").returncode, 0)
        result = self.sync("resolve", PATH=self.mock_omarchy())
        self.assertEqual(result.returncode, 0, result.stderr)
        launch = json.loads((self.home / "launch.json").read_text())
        self.assertEqual(launch["cwd"], str(self.repo))
        self.assertEqual(launch["argv"][:2], ["agent", "prompt"])
        prompt = launch["argv"][2]
        for phrase in ("Rulesync", "untrusted evidence", "ambiguous", "force push", "credentials"):
            self.assertIn(phrase, prompt)
        self.assertNotIn("Diagnostica", prompt)
        self.assertIn('"operation": "up"', prompt)
        self.assertEqual(self.state()["status"], "error")

    def test_older_omarchy_uses_visible_terminal_fallback(self):
        result = self.sync("resolve", PATH=self.mock_omarchy(False))
        self.assertEqual(result.returncode, 0, result.stderr)
        launch = json.loads((self.home / "launch.json").read_text())
        self.assertEqual(launch["argv"][:2], ["launch", "tui"])
        self.assertEqual(launch["argv"][-1], "resolve-inline")

    def test_plugin_upload_uses_timestamp_without_input_or_terminal(self):
        self.enable_ai()
        (self.repo / "tracked").write_text("local update")
        (self.repo / "ai/new.md").write_text("new canonical rule")
        (self.repo / "private").write_text("untracked, preserve")
        before = datetime.now(timezone.utc).replace(microsecond=0)
        result = self.sync("upload", PATH=self.mock_omarchy())
        self.assertEqual(result.returncode, 0, result.stderr)
        message = self.git("log", "-1", "--format=%s").strip()
        self.assertTrue(message.startswith("dotfiles updated "))
        timestamp = datetime.strptime(message.removeprefix("dotfiles updated "),
                                      "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        self.assertGreaterEqual(timestamp, before)
        self.assertLessEqual(timestamp, datetime.now(timezone.utc))
        self.assertNotIn("Commit message", result.stdout)
        self.assertFalse((self.home / "launch.json").exists())
        self.assertEqual(self.git("rev-parse", "HEAD"), self.git("rev-parse", "@{upstream}"))
        self.assertNotIn("private", self.git("ls-tree", "-r", "--name-only", "HEAD"))
        self.assertIn("ai/new.md", self.git("ls-tree", "-r", "--name-only", "HEAD"))
        self.assertEqual(self.state()["ai"], "applied")

    def test_plugin_upload_skips_empty_commits_and_stops_on_ai_failure(self):
        before = self.git("rev-parse", "HEAD")
        self.assertEqual(self.sync("upload").returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        self.enable_ai()
        (self.repo / "tracked").write_text("preserve")
        self.assertNotEqual(self.sync("upload", SYNC_EXIT="1").returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        self.assertEqual(self.git("diff", "--cached"), "")

    def test_plugin_upload_rebases_remote_advance_and_applies_final_ai(self):
        self.enable_ai()
        self.remote_update()
        (self.repo / "ai/rule.md").write_text("local rule update\n")
        result = self.sync("upload")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual((self.repo / "tracked").read_text(), "from other machine\n")
        self.assertEqual((self.repo / "ai/rule.md").read_text(), "local rule update\n")
        self.assertEqual(self.git("rev-parse", "HEAD"), self.git("rev-parse", "@{upstream}"))
        self.assertEqual(self.git("rev-list", "--count", "HEAD").strip(), "3")
        refs = self.git("for-each-ref", "--format=%(refname)", "refs/omasync/pre-rebase/").splitlines()
        self.assertEqual(len(refs), 1)
        self.assertEqual(self.git("show", refs[0] + ":ai/rule.md"), "local rule update\n")
        self.assertEqual((self.home / "sync-log").read_text(), "synced\nsynced\n")
        self.assertEqual(self.state()["ai"], "applied")

    def test_cli_upload_uses_same_reconciliation_and_keeps_message(self):
        self.remote_update()
        (self.repo / "ai/rule.md").write_text("local rule update\n")
        result = self.run_df(["up"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("log", "-1", "--format=%s").strip(), "test update")
        self.assertEqual(self.git("rev-parse", "HEAD"), self.git("rev-parse", "@{upstream}"))
        self.assertEqual((self.repo / "tracked").read_text(), "from other machine\n")

    def test_upload_rebase_conflict_preserves_both_histories_for_review(self):
        self.remote_update()
        remote = self.git("rev-parse", "HEAD", cwd=self.repo.parent / "other").strip()
        (self.repo / "tracked").write_text("local conflicting change\n")
        self.git("config", "rerere.enabled", "true")
        result = self.sync("upload")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.repo / ".git/rebase-merge").is_dir())
        self.assertTrue(self.state()["in_progress"])
        text = (self.repo / "tracked").read_text()
        self.assertIn("local conflicting change", text)
        self.assertIn("from other machine", text)
        refs = self.git("for-each-ref", "--format=%(refname)", "refs/omasync/pre-rebase/").splitlines()
        self.assertEqual(self.git("show", refs[0] + ":tracked"), "local conflicting change\n")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.repo.parent / "remote.git").strip(), remote)
        self.assertFalse(any(p.is_file() for p in (self.repo / ".git/rr-cache").rglob("*")))
        self.assertIn("rebase stopped", self.state()["error"])

    def test_upload_does_not_reconcile_auth_network_or_hook_failures(self):
        hook = self.repo.parent / "remote.git/hooks/pre-receive"
        hook.write_text("#!/bin/sh\nprintf '%s\\n' '(fetch first) authentication failed' >&2\nexit 1\n")
        hook.chmod(0o755)
        (self.repo / "tracked").write_text("preserve local commit\n")
        self.assertNotEqual(self.sync("upload").returncode, 0)
        self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")
        self.assertFalse(self.state()["in_progress"])
        self.assertEqual((self.repo / "tracked").read_text(), "preserve local commit\n")
        self.git("remote", "set-url", "origin", str(self.repo.parent / "missing.git"))
        self.assertNotEqual(self.sync("upload").returncode, 0)
        self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")

    def test_upload_reconciliation_refuses_untracked_content(self):
        self.remote_update()
        (self.repo / "private").write_text("keep this local file")
        (self.repo / "ai/rule.md").write_text("local rule update\n")
        self.assertNotEqual(self.sync("upload").returncode, 0)
        self.assertFalse(self.state()["in_progress"])
        self.assertEqual((self.repo / "private").read_text(), "keep this local file")
        self.assertIn("checkout must be clean", self.state()["error"])
        self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")

    def test_reconciliation_refuses_remote_history_rewrites(self):
        self.remote_update()
        other = self.repo.parent / "other"
        branch = self.git("symbolic-ref", "--short", "HEAD").strip()
        # Only this disposable remote is rewritten to exercise the guard.
        self.git("checkout", "--orphan", "replacement", cwd=other)
        self.git("commit", "-m", "unrelated replacement", cwd=other)
        self.git("push", "--force", "origin", "HEAD:" + branch, cwd=other)
        (self.repo / "ai/rule.md").write_text("preserve local rule\n")
        self.assertNotEqual(self.sync("upload").returncode, 0)
        self.assertIn("remote history was rewritten", self.state()["error"])
        self.assertEqual(self.git("for-each-ref", "refs/omasync/pre-rebase/"), "")
        self.assertFalse(self.state()["in_progress"])
        self.assertEqual((self.repo / "ai/rule.md").read_text(), "preserve local rule\n")

    def test_ai_failure_after_rebase_prevents_push_and_records_partial_success(self):
        self.enable_ai()
        self.remote_update()
        remote = self.git("rev-parse", "HEAD", cwd=self.repo.parent / "other").strip()
        (self.repo / "ai/rule.md").write_text("local rule update\n")
        (self.repo / "scripts/sync-ai.sh").write_text(
            'printf "synced\\n" >> "$HOME/sync-log"\n'
            '[ "$(wc -l < "$HOME/sync-log")" -lt 2 ]\n')
        self.assertNotEqual(self.sync("upload").returncode, 0)
        self.assertTrue(self.state()["repo_updated"])
        self.assertEqual(self.state()["ai"], "failed")
        self.assertEqual(self.git("rev-parse", "@{upstream}").strip(), remote)
        self.assertNotEqual(self.git("rev-parse", "HEAD").strip(), remote)
        self.assertFalse(self.state()["in_progress"])

    def test_reconciliation_stops_after_one_retry_when_remote_advances_again(self):
        self.remote_update()
        (self.repo / "ai/rule.md").write_text("local rule update\n")
        with mock.patch.dict(os.environ, self.env):
            engine = sync_module.Engine(self.repo)
            original_run = engine.run
            pushes = []

            def racing_run(args, stage, *a, **kw):
                if stage == "git push":
                    pushes.append(args)
                    if len(pushes) == 2:
                        other = self.repo.parent / "other"
                        (other / "remote-only").write_text("arrived during reconciliation\n")
                        self.git("add", ".", cwd=other)
                        self.git("commit", "-m", "another remote update", cwd=other)
                        self.git("push", cwd=other)
                return original_run(args, stage, *a, **kw)

            with mock.patch.object(engine, "run", side_effect=racing_run):
                with self.assertRaises(sync_module.SyncError):
                    engine.upload(interactive=False)
        self.assertEqual(len(pushes), 2)
        self.assertFalse(self.state()["in_progress"])
        self.assertNotEqual(self.git("rev-parse", "HEAD"),
                            self.git("rev-parse", "HEAD", cwd=self.repo.parent / "remote.git"))

    def test_reconciliation_preserves_merge_structure_and_other_local_refs(self):
        branch = self.git("symbolic-ref", "--short", "HEAD").strip()
        self.git("checkout", "-b", "local-side")
        (self.repo / "ai/side.md").write_text("side change\n")
        self.git("add", ".")
        self.git("commit", "-m", "side")
        self.git("checkout", branch)
        (self.repo / "ai/main.md").write_text("main change\n")
        self.git("add", ".")
        self.git("commit", "-m", "main")
        self.git("merge", "--no-ff", "-m", "keep merge", "local-side")
        original_side = self.git("rev-parse", "local-side")
        self.git("config", "rebase.updateRefs", "true")
        self.git("config", "rebase.autoStash", "true")
        self.remote_update()
        result = self.sync("upload")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.git("rev-list", "--parents", "-1", "HEAD").split()), 3)
        self.assertEqual(self.git("rev-parse", "local-side"), original_side)
        self.assertEqual((self.repo / "ai/side.md").read_text(), "side change\n")
        self.assertEqual((self.repo / "ai/main.md").read_text(), "main change\n")

    def test_installer_only_changes_temporary_config_with_mocked_commands(self):
        config = self.home / ".config"
        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run") as run:
            installer.install(ROOT)
            target = config / "omarchy/plugins/io.github.pablousx.omasync"
            entry = json.loads((target / "manifest.json").read_text())["entryPoints"]["barWidget"]
            runtime = (target / entry).parent
            self.assertIn(json.dumps(str(ROOT)), (runtime / "BarWidget.qml").read_text())
            self.assertTrue((runtime / "UiAction.qml").is_file())
            self.assertTrue((runtime / "UiText.qml").is_file())
            self.assertEqual(run.call_args_list[-1].args[0],
                             ["omarchy", "plugin", "enable", "io.github.pablousx.omasync", "--section", "right"])
            run.reset_mock()
            (config / "omarchy/shell.json").write_text('{"keep": "disabled and in left section"}')
            installer.install(ROOT)
            self.assertEqual(json.loads((target / "manifest.json").read_text())["entryPoints"]["barWidget"], entry)
            self.assertEqual([call.args[0][:3] for call in run.call_args_list],
                             [["omarchy", "plugin", "validate"], ["omarchy-shell", "shell", "rescanPlugins"]])
            self.assertEqual((config / "omarchy/shell.json").read_text(),
                             '{"keep": "disabled and in left section"}')
            (target / ".dotfiles-managed").unlink()
            with self.assertRaises(ValueError):
                installer.install(ROOT)

    def test_update_changes_entrypoint_only_after_complete_ui_is_available(self):
        config = self.home / ".config"
        target = config / "omarchy/plugins/io.github.pablousx.omasync"
        files = ("manifest.json", "Panel.qml", "BarWidget.qml", "UiText.qml", "UiAction.qml")
        for name in files:
            shutil.copyfile(ROOT / "omasync" / name, self.repo / "omasync" / name)
        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run") as run:
            installer.install(self.repo)
            old_entry = json.loads((target / "manifest.json").read_text())["entryPoints"]["barWidget"]
            old_panel = (target / old_entry).with_name("Panel.qml").read_text()
            source = self.repo / "omasync/Panel.qml"
            source.write_text(source.read_text() + "\n// new interface revision\n")
            def inspect_publication(command, **options):
                if command[:3] == ["omarchy-shell", "shell", "rescanPlugins"]:
                    new_entry = json.loads((target / "manifest.json").read_text())["entryPoints"]["barWidget"]
                    self.assertNotEqual(old_entry, new_entry)
                    for name in files[1:]:
                        self.assertTrue((target / new_entry).with_name(name).is_file())
            run.side_effect = inspect_publication
            installer.install(self.repo)
            self.assertEqual((target / old_entry).with_name("Panel.qml").read_text(), old_panel)

    def test_legacy_flat_install_migrates_without_reenabling_or_deleting_files(self):
        config = self.home / ".config"
        target = config / "omarchy/plugins/io.github.pablousx.omasync"
        target.mkdir(parents=True)
        (target / ".dotfiles-managed").write_text(str(ROOT))
        (target / "manifest.json").write_text((ROOT / "omasync/manifest.json").read_text())
        (target / "Panel.qml").write_text("// previous flat UI\n")
        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run") as run:
            installer.install(ROOT)
            entry = json.loads((target / "manifest.json").read_text())["entryPoints"]["barWidget"]
            self.assertTrue(entry.startswith("runtime/"))
            self.assertTrue((target / entry).is_file())
            self.assertEqual((target / "Panel.qml").read_text(), "// previous flat UI\n")
            self.assertFalse(any(c.args[0][:3] == ["omarchy", "plugin", "enable"] for c in run.call_args_list))

    def test_installer_preflights_symlinks_and_missing_dependencies(self):
        config = self.home / ".config"
        target = config / "omarchy/plugins/io.github.pablousx.omasync"
        target.mkdir(parents=True)
        marker = target / ".dotfiles-managed"
        victim = self.home / "keep"
        victim.write_text("preserve")
        marker.symlink_to(victim)
        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                installer.install(ROOT)
            run.assert_not_called()
        self.assertEqual(victim.read_text(), "preserve")
        with mock.patch.object(shutil, "which", return_value=None):
            with self.assertRaisesRegex(ValueError, "Missing prerequisite"):
                installer.install(ROOT)

    def test_installer_retries_reload_when_shell_times_out_once(self):
        config = self.home / ".config"
        attempts = []

        def run(command, **options):
            if command[:3] == ["omarchy-shell", "shell", "rescanPlugins"]:
                attempts.append(options)
                if len(attempts) == 1:
                    raise subprocess.CalledProcessError(1, command, stderr="omarchy-shell is not responding")

        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run", side_effect=run), \
                mock.patch("time.sleep"):
            installer.install(ROOT)
        self.assertEqual(len(attempts), 2)
        self.assertEqual(attempts[-1]["env"]["OMARCHY_SHELL_IPC_TIMEOUT"], "10s")

    def test_partial_install_keeps_activation_pending_for_retry(self):
        config = self.home / ".config"
        target = config / "omarchy/plugins/io.github.pablousx.omasync"
        blocked = True

        def run(command, **options):
            if command[:3] == ["omarchy-shell", "shell", "rescanPlugins"] and blocked:
                raise subprocess.CalledProcessError(1, command)

        with mock.patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(config)), \
                mock.patch.object(shutil, "which", return_value="/mock/tool"), \
                mock.patch.object(installer.subprocess, "run", side_effect=run) as calls, \
                mock.patch("time.sleep"):
            with self.assertRaisesRegex(RuntimeError, "files were copied"):
                installer.install(ROOT)
            self.assertTrue((target / ".dotfiles-enable-pending").is_file())
            self.assertEqual(sum(c.args[0][:3] == ["omarchy-shell", "shell", "rescanPlugins"]
                                 for c in calls.call_args_list), 3)
            self.assertFalse(any(c.args[0][:3] == ["omarchy", "plugin", "enable"] for c in calls.call_args_list))
            blocked = False
            calls.reset_mock()
            installer.install(ROOT)
            self.assertTrue(any(c.args[0][:3] == ["omarchy", "plugin", "enable"] for c in calls.call_args_list))
            self.assertFalse((target / ".dotfiles-enable-pending").exists())


if __name__ == "__main__":
    unittest.main()
