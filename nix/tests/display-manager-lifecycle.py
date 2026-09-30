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

    def current(self): return self.selected
    def enabled(self, unit): return "enabled" if unit in self.units else "disabled"
    def default_target(self): return "graphical.target"

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

    def test_shared_owner_retains_manager(self):
        self.apply("greetd.service")
        self.apply("greetd.service", "second")
        self.apply(None)
        self.assertEqual(self.systemd.selected, "greetd.service")
        with self.assertRaisesRegex(RuntimeError, "Conflicting"):
            self.apply("gdm.service")
        self.apply(None, "second")
        self.assertEqual(self.systemd.selected, "")

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


unittest.main()
