"""Exercise input startup handoff, retirement and file ownership without a desktop."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("autostart", sys.argv.pop(1))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class AutostartTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.destination = self.root / "autostart/fcitx.desktop"
        self.state = self.root / "state/owned"

    def apply(self, mode):
        helper.reconcile(self.destination, self.state, mode)

    def test_never_managed_entries_are_untouched(self):
        self.apply("disabled")
        self.assertFalse(self.destination.exists())
        self.assertFalse(self.state.exists())
        self.destination.parent.mkdir()
        self.destination.write_text("user entry")
        self.apply("disabled")
        self.apply("autostart")
        self.apply("autostart")
        self.assertEqual(self.destination.read_text(), "user entry")
        self.assertEqual(self.state.read_bytes(), b"")
        for mode in ["systemd", "disabled"]:
            with self.assertRaises(RuntimeError):
                self.apply(mode)
            self.assertEqual(self.destination.read_text(), "user entry")

    def test_first_autostart_can_be_retired(self):
        self.apply("autostart")
        self.assertFalse(self.destination.exists())
        self.assertEqual(self.state.read_bytes(), b"")
        self.apply("disabled")
        self.assertIn("Hidden=true", self.destination.read_text())
        self.apply("autostart")
        self.assertFalse(self.destination.exists())

    def test_released_file_is_not_reclaimed_by_matching_bytes(self):
        self.apply("systemd")
        content = self.destination.read_bytes()
        self.apply("autostart")
        self.destination.write_bytes(content)
        self.apply("autostart")
        for mode in ["disabled", "systemd"]:
            with self.assertRaises(RuntimeError):
                self.apply(mode)
        self.assertEqual(self.destination.read_bytes(), content)

    def test_desktop_autostart_converges_after_handoff(self):
        self.apply("autostart")
        self.assertFalse(self.destination.exists())
        for _ in range(2):
            self.apply("systemd")
            self.assertIn("Hidden=true", self.destination.read_text())
            self.apply("autostart")
            self.apply("autostart")
            self.assertFalse(self.destination.exists())

    def test_retirement_suppresses_retained_package(self):
        self.apply("systemd")
        stamp = self.destination.stat().st_mtime_ns
        for mode in ["systemd", "disabled", "systemd"]:
            self.apply(mode)
            self.assertEqual(self.destination.stat().st_mtime_ns, stamp)
        self.apply("autostart")
        self.apply("disabled")
        self.assertIn("Hidden=true", self.destination.read_text())
        self.apply("autostart")
        self.assertFalse(self.destination.exists())

    def test_modified_owned_entry_is_preserved(self):
        self.apply("systemd")
        self.destination.write_text("user edit")
        for mode in ["systemd", "autostart", "disabled"]:
            with self.assertRaises(RuntimeError):
                self.apply(mode)
            self.assertEqual(self.destination.read_text(), "user edit")

    def test_interrupted_release_can_retry(self):
        self.apply("systemd")
        remove = helper.remove

        def interrupted(*args):
            remove(*args)
            raise OSError("interrupted after removal")

        with patch.object(helper, "remove", side_effect=interrupted):
            with self.assertRaises(OSError):
                self.apply("autostart")
        self.apply("autostart")
        self.assertFalse(self.destination.exists())
        self.apply("disabled")
        self.assertIn("Hidden=true", self.destination.read_text())

    def test_symlinks_are_not_followed(self):
        self.apply("systemd")
        self.destination.unlink()
        foreign = self.root / "foreign"
        foreign.write_text("user entry")
        self.destination.symlink_to(foreign)
        for mode in ["systemd", "autostart", "disabled"]:
            with self.assertRaises((OSError, RuntimeError)):
                self.apply(mode)
            self.assertEqual(foreign.read_text(), "user entry")

    def test_invalid_state_does_not_authorize_suppression(self):
        self.state.parent.mkdir()
        self.state.write_bytes(b"not an ownership record")
        for mode in ["systemd", "autostart", "disabled"]:
            with self.assertRaises(ValueError):
                self.apply(mode)
        self.assertFalse(self.destination.exists())

    def test_invalid_mode_has_no_effects(self):
        with self.assertRaises(ValueError):
            self.apply("unknown")
        self.assertFalse(self.destination.exists())
        self.assertFalse(self.state.exists())


unittest.main()
