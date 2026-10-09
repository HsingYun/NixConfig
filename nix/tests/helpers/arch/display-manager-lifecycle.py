import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys
sys.dont_write_bytecode = True

helpers = Path(sys.argv.pop(1))
sys.path.insert(0, str(helpers))
spec = importlib.util.spec_from_file_location("display_manager", helpers / "display-manager.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Systemd:
    def __init__(self):
        self.selected = ""
        self.units = set()
        self.actions = []
        self.fail = False
        self.target = "graphical.target"

    def current(self): return self.selected
    def enabled(self, unit): return "enabled" if unit in self.units else "disabled"
    def default_target(self): return self.target

    def change(self, *args):
        if self.fail:
            raise RuntimeError("interrupted activation")
        self.actions.append(args)
        if args[0] == "enable":
            self.selected = args[-1]
            self.units.add(args[-1])
        if args[0] == "disable":
            self.units.discard(args[-1])
            if self.selected == args[-1]: self.selected = ""
        if args[0] == "set-default": self.target = args[-1]


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        # Resolve /var on macOS: safe_files intentionally rejects symlink parents.
        self.path = Path(self.temp.name).resolve() / "state.json"
        self.systemd = Systemd()

    def tearDown(self): self.temp.cleanup()

    def apply(self, service, owner="host"):
        module.reconcile(self.path, owner, service, [], self.systemd)

    def test_absent_state_does_not_touch_existing_manager(self):
        self.systemd.selected = "gdm.service"
        self.systemd.units.add("gdm.service")
        self.apply(None)
        self.assertEqual(self.systemd.actions, [])

    def test_disable_retires_boot_without_stopping_session(self):
        self.apply("gdm.service")
        self.apply(None)
        self.assertEqual(self.systemd.units, set())
        self.assertTrue(all(action[0] != "stop" for action in self.systemd.actions))
        self.apply(None)

    def test_adopted_manager_is_preserved(self):
        self.systemd.selected = "gdm.service"
        self.systemd.units.add("gdm.service")
        self.apply("gdm.service")
        self.apply(None)
        self.assertEqual(self.systemd.selected, "gdm.service")
        self.assertEqual(self.systemd.units, {"gdm.service"})

    def test_previous_manager_and_boot_target_are_restored(self):
        self.systemd.selected = "gdm.service"
        self.systemd.units.add("gdm.service")
        self.systemd.target = "multi-user.target"
        self.apply("greetd.service")
        self.assertEqual(self.systemd.selected, "greetd.service")
        self.apply(None)
        self.assertEqual(self.systemd.selected, "gdm.service")
        self.assertEqual(self.systemd.units, {"gdm.service"})
        self.assertEqual(self.systemd.target, "multi-user.target")

    def test_unknown_legacy_ownership_cannot_disable_host_manager(self):
        self.systemd.selected = "gdm.service"
        self.systemd.units.add("gdm.service")
        self.path.write_text(json.dumps({"version": 1, "owners": {"host": "gdm.service"},
                                       "managed": ["gdm.service"], "files": {}, "reload": False}))
        with self.assertRaisesRegex(RuntimeError, "original state was not recorded"):
            self.apply(None)
        self.assertEqual(self.systemd.units, {"gdm.service"})

    def test_interrupted_restoration_retires_the_replacement_on_retry(self):
        self.systemd.selected = "gdm.service"
        self.systemd.units.add("gdm.service")
        self.apply("greetd.service")
        change = self.systemd.change
        def fail_disable(*args):
            if args[0] == "disable": raise RuntimeError("interrupted restoration")
            change(*args)
        self.systemd.change = fail_disable
        with self.assertRaisesRegex(RuntimeError, "interrupted"):
            self.apply(None)
        self.assertEqual(self.systemd.selected, "gdm.service")
        self.systemd.change = change
        self.apply(None)
        self.assertEqual(self.systemd.units, {"gdm.service"})

    def test_shared_owner_retains_manager(self):
        self.apply("greetd.service")
        self.apply("greetd.service", "second")
        self.apply(None)
        self.assertEqual(self.systemd.selected, "greetd.service")
        with self.assertRaisesRegex(RuntimeError, "Conflicting"):
            self.apply("gdm.service")
        self.apply(None, "second")
        self.assertEqual(self.systemd.selected, "")

    def test_interrupted_retirement_restores_text_boot_on_retry(self):
        self.systemd.target = "multi-user.target"
        self.apply("greetd.service")
        change = self.systemd.change
        def fail_target(*args):
            if args[0] == "set-default": raise RuntimeError("interrupted restoration")
            change(*args)
        self.systemd.change = fail_target
        with self.assertRaisesRegex(RuntimeError, "interrupted"):
            self.apply(None)
        self.assertEqual(self.systemd.selected, "")
        self.systemd.change = change
        self.apply(None)
        self.assertEqual(self.systemd.target, "multi-user.target")
        self.assertEqual(self.systemd.units, set())

    def test_switch_failure_can_be_retried(self):
        self.apply("gdm.service")
        self.systemd.fail = True
        with self.assertRaisesRegex(RuntimeError, "interrupted"):
            self.apply("greetd.service")
        self.systemd.fail = False
        self.apply("greetd.service")
        self.assertEqual(self.systemd.units, {"greetd.service"})
        self.apply(None)
        self.assertEqual(self.systemd.units, set())

    def test_disable_preserves_foreign_alias(self):
        self.apply("gdm.service")
        self.systemd.selected = "other.service"
        self.systemd.actions.clear()
        self.apply(None)
        self.assertEqual(self.systemd.actions, [])

    def test_owned_files_are_removed_after_last_consumer(self):
        root = self.path.parent
        source, dest = root / "source", root / "config"
        source.write_text("managed")
        files = [{"source": str(source), "destination": str(dest), "stateFile": str(root / "file-state")}]
        module.reconcile(self.path, "host", "greetd.service", files, self.systemd)
        self.assertEqual(dest.read_text(), "managed")
        self.apply(None)
        self.assertFalse(dest.exists())

    def test_gdm_session_update_and_unset_preserve_running_manager(self):
        root = self.path.parent
        source, dest = root / "session-unit", root / "gdm.service.d/nixconfig.conf"
        files = [{"source": str(source), "destination": str(dest), "stateFile": str(root / "session-state")}]
        for session in ("gnome", "niri"):
            source.write_text(f"[Service]\nExecStartPre=/set-session {session}\n")
            module.reconcile(self.path, "host", "gdm.service", files, self.systemd)
            self.assertEqual(dest.read_text(), source.read_text())
        self.systemd.actions.clear()
        module.reconcile(self.path, "host", "gdm.service", [], self.systemd)
        self.assertFalse(dest.exists())
        self.assertEqual(self.systemd.selected, "gdm.service")
        self.assertEqual(self.systemd.actions, [("daemon-reload",)])


unittest.main()
