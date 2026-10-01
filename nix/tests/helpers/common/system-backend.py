"""Exercise the distro-independent journal and its read-only inspection API."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

directory = Path(sys.argv.pop(1))
sys.path.insert(0, str(directory))
spec = importlib.util.spec_from_file_location("backend", directory / "system-backend.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.plan = {"version": 1, "owner": "test", "host": "UbuntuPrototype",
                     "resources": {"packages": {"desired": {"apt": ["example"]}, "check": None}},
                     "stages": {"install": {}}}
        self.backend = helper.Backend(self.plan, self.root / "state")
        self.pid = os.getpid()

    def finish(self):
        for action in ["stage-start", "stage-end"]:
            self.backend.record(action, self.pid, "install")
        self.backend.record("stage-start", self.pid, "verification")
        self.backend.record("complete", self.pid)

    def test_read_only_before_first_apply(self):
        self.assertIsNone(self.backend.status()["attempt"])
        self.assertEqual(self.backend.diff()["packages"]["change"], "added")
        self.assertEqual(self.backend.verify()["packages"]["status"], "unchecked")
        self.assertFalse((self.root / "state").exists())

    def test_success_failure_retry_and_previous_plan(self):
        self.backend.record("begin", self.pid)
        self.finish()
        self.assertEqual(self.backend.diff(), {})
        changed = copy.deepcopy(self.plan)
        changed["resources"]["packages"]["desired"] = {"apt": ["other"]}
        self.backend = helper.Backend(changed, self.root / "state")
        self.assertEqual(self.backend.diff()["packages"]["change"], "changed")
        self.backend.record("begin", self.pid)
        self.backend.record("stage-start", self.pid, "install")
        self.backend.record("failed", self.pid, "install", 42)
        state = self.backend.status()
        self.assertEqual(state["attempt"]["exitCode"], 42)
        self.assertEqual(state["successful"]["desired"], helper.desired(self.plan))
        self.backend.record("begin", self.pid)
        self.finish()
        self.assertEqual(self.backend.diff(), {})

    def test_reject_concurrent_and_incomplete_completion(self):
        self.backend.record("begin", self.pid)
        with self.assertRaises(RuntimeError):
            self.backend.record("begin", self.pid)
        with self.assertRaises(RuntimeError):
            self.backend.record("complete", self.pid)
        other = copy.deepcopy(self.plan)
        other["host"] = "Other"
        with self.assertRaises(RuntimeError):
            helper.Backend(other, self.root / "state").record("stage-start", self.pid, "install")

    def test_interrupted_process_and_retry(self):
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        self.backend.record("begin", process.pid)
        process.terminate()
        process.wait()
        self.assertEqual(self.backend.status()["attempt"]["status"], "interrupted")
        self.backend.record("begin", self.pid)
        self.finish()

    def test_checks_and_removal_diff(self):
        self.plan["resources"]["packages"]["check"] = "/missing-check"
        self.assertEqual(self.backend.verify()["packages"]["status"], "failed")
        self.backend.record("begin", self.pid)
        self.finish()
        other = copy.deepcopy(self.plan)
        other["resources"] = {}
        self.assertEqual(helper.Backend(other, self.root / "state").diff()["packages"]["change"], "removed")

    def test_live_stage_blocks_retry_after_parent_exits(self):
        processes = [subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"]) for _ in range(2)]
        parent, worker = processes
        try:
            self.backend.record("begin", parent.pid)
            self.backend.record("stage-start", parent.pid, "install", worker=worker.pid)
            parent.terminate()
            parent.wait()
            self.assertEqual(self.backend.status()["attempt"]["status"], "running")
            with self.assertRaises(RuntimeError):
                self.backend.record("begin", self.pid)
            worker.terminate()
            worker.wait()
            self.assertEqual(self.backend.status()["attempt"]["status"], "interrupted")
            self.backend.record("begin", self.pid)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                process.wait()

    def test_do_not_follow_journal_symlinks(self):
        victim = self.root / "victim"
        victim.write_text("unrelated")
        (self.root / "state").mkdir()
        (self.root / "state/state.json").symlink_to(victim)
        with self.assertRaises(OSError):
            self.backend.record("begin", self.pid)
        self.assertEqual(victim.read_text(), "unrelated")


unittest.main()
