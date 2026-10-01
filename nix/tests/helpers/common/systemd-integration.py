"""Run only in a disposable Linux system with PID 1 systemd and a writable /etc."""

import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("native_systemd", sys.argv.pop(1))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class NativeSystemdTest(unittest.TestCase):
    def setUp(self):
        self.system = helper.Systemd(
            command=shutil.which("systemctl"), unshare=shutil.which("unshare"),
            mount=shutil.which("mount"),
        )
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name) / "state.json"
        self.units = []
        self.dropins = []

    def unit(self, name, relations="", install="WantedBy=multi-user.target\n"):
        name = f"nixconfig-test-{name}.service"
        self.units.append(name)
        (self.system.directory / name).write_text(
            f"[Unit]\n{relations}\n[Service]\nType=oneshot\nRemainAfterExit=yes\n"
            f"ExecStart={shutil.which('true')}\n[Install]\n{install}"
        )
        self.system.change("daemon-reload")
        return name

    def apply(self, units, owner="alice"):
        helper.reconcile(self.state, owner, units, self.system)

    def tearDown(self):
        self.system.change("stop", "--", *(unit for unit in self.units if "@." not in unit))
        for name, target in self.system.links().items():
            if Path(target).name in self.units:
                self.system.remove_link(name, target)
        for path in self.dropins:
            shutil.rmtree(path)
        for name in self.units:
            (self.system.directory / name).unlink(missing_ok=True)
        self.system.change("daemon-reload")
        self.tmp.cleanup()

    def test_vendor_enable_plan_and_shared_implicit_alias(self):
        peer = self.unit("peer", install="Alias=nixconfig-test-dbus.service\n")
        first = self.unit("first", install=f"WantedBy=multi-user.target\nAlso={peer}\n")
        second = self.unit("second", install=f"WantedBy=multi-user.target\nAlso={peer}\n")
        before = self.system.links()
        plan = self.system.enable_plan([first], {})
        self.assertIn("nixconfig-test-dbus.service", plan)
        self.assertEqual(before, self.system.links())
        self.assertFalse(self.system.active(first))
        self.apply([first])
        self.assertFalse(self.system.active(peer))
        self.apply([second], "bob")
        self.apply([])
        self.assertIn("nixconfig-test-dbus.service", self.system.links())
        self.apply([], "bob")
        self.assertEqual(before, self.system.links())
        self.assertFalse(self.system.active(first))
        self.assertFalse(self.system.active(second))

    def test_template_instances_and_install_dropins(self):
        template = self.unit("worker@")
        instance = template.replace("@.", "@one.")
        self.units.append(instance)
        parent = self.unit("parent")
        dropin = self.system.directory / f"{parent}.d"
        dropin.mkdir()
        self.dropins.append(dropin)
        (dropin / "install.conf").write_text(f"[Install]\nAlso={instance}\n")
        self.system.change("daemon-reload")
        self.apply([parent])
        self.assertTrue(self.system.links([instance]))
        self.assertFalse(self.system.active(instance))
        self.apply([instance], "bob")
        self.apply([])
        self.assertTrue(self.system.active(instance))
        self.apply([], "bob")
        self.assertFalse(self.system.active(instance))
        self.assertFalse(self.system.links([instance]))

    def test_preexisting_implicit_alias(self):
        peer = self.unit("peer", install="Alias=nixconfig-test-dbus.service\n")
        parent = self.unit("parent", install=f"WantedBy=multi-user.target\nAlso={peer}\n")
        self.system.change("enable", "--", peer)
        before = self.system.links()
        self.apply([parent])
        self.apply([])
        self.assertEqual(before, self.system.links())

    def test_live_stop_propagation(self):
        for relation in ["PartOf", "Requisite", "Requires", "BindsTo", "PropagatesStopTo"]:
            with self.subTest(relation=relation):
                # Distinct units keep each relation independent of earlier cases.
                root = f"nixconfig-test-root-{relation}.service"
                child = f"nixconfig-test-child-{relation}.service"
                self.unit(f"root-{relation}", relations=f"PropagatesStopTo={child}\n" if relation == "PropagatesStopTo" else "")
                self.unit(f"child-{relation}", relations=f"{relation}={root}\n" if relation != "PropagatesStopTo" else "")
                self.apply([root])
                self.system.change("start", "--", child)
                self.apply([])
                self.assertTrue(self.system.active(root))
                self.assertTrue(self.system.active(child))
                # Verify the fixture really would propagate an unguarded stop.
                self.system.change("stop", "--", root)
                self.assertFalse(self.system.active(child))

    def test_inactive_intermediate_stop_propagation(self):
        root = self.unit("root")
        middle = self.unit("middle", relations=f"PartOf={root}\n")
        child = self.unit("child", relations=f"PartOf={middle}\n")
        self.apply([root])
        self.system.change("start", "--", child)
        self.assertFalse(self.system.active(middle))
        self.apply([])
        self.assertTrue(self.system.active(root))
        self.assertTrue(self.system.active(child))
        # Traversal is deliberately conservative across systemd versions:
        # stopping an already inactive intermediate may prune its transaction.


unittest.main()
