"""Exercise native unit ownership, failures and shared dependencies without root."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("native_systemd", sys.argv.pop(1))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class FakeSystemd(helper.Systemd):
    def __init__(self, directory):
        super().__init__(directory=directory)
        self.directory.mkdir()
        self.running = set()
        self.actions = []
        self.fail = None
        self.masked = set()
        self.consumers = {}

    def enabled(self, unit):
        if unit in self.masked:
            return "masked"
        return "enabled" if self.links([unit]) else "disabled"

    def active(self, unit):
        return unit in self.running

    def link(self, unit, name=None):
        path = self.directory / "multi-user.target.wants" / (name or unit)
        path.parent.mkdir(exist_ok=True)
        path.symlink_to(f"/usr/lib/systemd/system/{unit}")

    def referenced(self, unit, retired):
        return bool((self.consumers.get(unit, set()) - set(retired)) & self.running)

    def change(self, *args):
        self.actions.append(args)
        if args[0] == "enable":
            unit = args[-1]
            self.link(unit)
            if unit == "avahi-daemon.service" and not self.links(["avahi-daemon.socket"]):
                self.link("avahi-daemon.socket")
        # A failure can occur after side effects, as with an interrupted enable.
        if self.fail == args[0]:
            raise RuntimeError("injected failure")
        if args[0] == "start":
            self.running.add(args[-1])
        elif args[0] == "stop":
            stopped = set(args[2:])
            while True:
                dependents = set().union(*(self.consumers.get(unit, set()) for unit in stopped))
                if dependents <= stopped:
                    break
                stopped |= dependents
            self.running -= stopped


class UnitsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / "state.json"
        self.system = FakeSystemd(self.root / "system")

    def apply(self, units, owner="alice"):
        helper.reconcile(self.state, owner, units, self.system)

    def test_enable_repeat_disable(self):
        units = ["cups.socket", "fwupd-refresh.timer"]
        self.apply(units)
        before = list(self.system.actions)
        self.apply(units)
        self.assertEqual(self.system.actions, before)
        self.apply([])
        self.assertFalse(self.system.links(units))
        self.assertFalse(self.system.running)
        before = list(self.system.actions)
        self.apply([])
        self.assertEqual(self.system.actions, before)

    def test_preexisting_units_and_active_units(self):
        self.system.link("cups.socket")
        self.system.running.add("pcscd.socket")
        self.apply(["cups.socket", "pcscd.socket"])
        self.apply([])
        self.assertTrue(self.system.links(["cups.socket"]))
        self.assertFalse(self.system.links(["pcscd.socket"]))
        self.assertEqual(self.system.running, {"cups.socket", "pcscd.socket"})

    def test_shared_users_and_duplicated_feature_requirements(self):
        self.apply(["cups.socket", "cups.socket"])
        self.apply(["cups.socket"], owner="bob")
        self.apply([])
        self.assertTrue(self.system.active("cups.socket"))
        self.apply([], owner="bob")
        self.assertFalse(self.system.active("cups.socket"))
        self.assertFalse(self.system.links(["cups.socket"]))

    def test_install_also_and_shared_socket(self):
        units = ["avahi-daemon.service", "avahi-daemon.socket"]
        self.apply(units)
        self.apply(["avahi-daemon.socket"])
        self.assertFalse(self.system.active("avahi-daemon.service"))
        self.assertTrue(self.system.active("avahi-daemon.socket"))
        self.assertTrue(self.system.links(["avahi-daemon.socket"]))
        self.apply([])
        self.assertFalse(self.system.running)

    def test_also_preserves_preexisting_socket(self):
        self.system.link("avahi-daemon.socket")
        self.apply(["avahi-daemon.service", "avahi-daemon.socket"])
        self.apply([])
        self.assertTrue(self.system.links(["avahi-daemon.socket"]))
        self.assertTrue(self.system.active("avahi-daemon.socket"))
        self.assertFalse(self.system.active("avahi-daemon.service"))

    def test_failed_enable_is_not_adopted_on_retry(self):
        self.system.fail = "enable"
        with self.assertRaises(RuntimeError):
            self.apply(["cups.socket"])
        self.system.fail = None
        self.apply(["cups.socket"])
        self.apply([])
        self.assertFalse(self.system.links(["cups.socket"]))
        self.assertFalse(self.system.running)

    def test_killed_enable_journal_recovery(self):
        self.state.write_text(json.dumps({
            "version": 1, "owners": {"alice": ["cups.socket"]}, "reload": False,
            "units": {"cups.socket": {"enabled": "disabled", "active": False, "links": {}}},
            "pending": {},
        }))
        self.system.link("cups.socket")
        self.apply([])
        self.assertFalse(self.system.links(["cups.socket"]))

    def test_failed_stop_and_reload_are_retryable(self):
        for phase in ["daemon-reload", "stop"]:
            with self.subTest(phase=phase):
                self.apply(["cups.socket"])
                self.system.fail = phase
                with self.assertRaises(RuntimeError):
                    self.apply([])
                self.system.fail = None
                self.apply([])
                self.assertFalse(self.system.running)
                self.assertFalse(self.system.links(["cups.socket"]))

    def test_external_link_and_edit_are_preserved(self):
        self.apply(["cups.socket"])
        self.system.link("cups.socket", "external.socket")
        self.apply([])
        self.assertTrue(self.system.active("cups.socket"))
        self.assertEqual(len(self.system.links(["cups.socket"])), 1)
        self.apply(["pcscd.socket"])
        link = self.system.directory / "multi-user.target.wants/pcscd.socket"
        link.unlink()
        link.symlink_to("/administrator/pcscd.socket")
        self.apply([])
        self.assertEqual(os.readlink(link), "/administrator/pcscd.socket")
        self.assertTrue(self.system.active("pcscd.socket"))

    def test_enable_only_units_are_not_started(self):
        helper.reconcile(self.state, "alice", ["NetworkManager.service"], self.system, ["NetworkManager-wait-online.service"])
        self.assertTrue(self.system.links(["NetworkManager-wait-online.service"]))
        self.assertFalse(self.system.active("NetworkManager-wait-online.service"))
        before = list(self.system.actions)
        helper.reconcile(self.state, "alice", ["NetworkManager.service"], self.system, ["NetworkManager-wait-online.service"])
        self.assertEqual(before, self.system.actions)
        self.apply([])
        self.assertFalse(self.system.links(["NetworkManager-wait-online.service"]))

    def test_foreign_active_consumers_are_preserved(self):
        self.apply(["cups.socket"])
        self.system.running.add("foreign.service")
        self.system.consumers["cups.socket"] = {"foreign.service"}
        self.apply([])
        self.assertTrue(self.system.active("cups.socket"))
        self.assertFalse(self.system.links(["cups.socket"]))

    def test_masked_units_are_not_unmasked(self):
        self.system.masked.add("cups.socket")
        with self.assertRaisesRegex(RuntimeError, "no automatic unmasking"):
            self.apply(["cups.socket"])
        self.assertEqual(self.system.actions, [])

    def test_retired_host_consumer_preserves_transitive_dependencies(self):
        for protection in ["enabled", "active", "external-link"]:
            with self.subTest(protection=protection):
                consumer = f"{protection}.service"
                # The last dependency sorts first: protection needs a fixed point.
                units = ["a.socket", "b.service", consumer]
                if protection == "enabled":
                    self.system.link(consumer)
                elif protection == "active":
                    self.system.running.add(consumer)
                self.apply(units)
                if protection == "external-link":
                    self.system.link(consumer, "external.service")
                self.system.consumers = {"a.socket": {"b.service"}, "b.service": {consumer}}
                self.apply([])
                self.assertTrue(set(units) <= self.system.running)
                self.system.running.clear()
                self.system.consumers.clear()

    def test_owned_dependency_cycle_stops_in_one_transaction(self):
        units = ["a.service", "b.service"]
        self.apply(units)
        self.system.consumers = {"a.service": {"b.service"}, "b.service": {"a.service"}}
        self.apply([])
        self.assertFalse(self.system.running)
        self.assertEqual(self.system.actions[-1], ("stop", "--", *units))


unittest.main()
