"""Exercise native unit ownership, failures and shared dependencies without root."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess

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
        self.relations = {}
        self.aliases = {}
        self.also = {"avahi-daemon.service": {"avahi-daemon.socket"}}
        self.install_aliases = {}

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

    def query(self, *args):
        if "--property=ActiveState" in args:
            return super().query(*args)
        unit = self.aliases.get(args[-1], args[-1])
        properties = next(arg.split("=", 1)[1].split(",") for arg in args if arg.startswith("--property="))
        values = {"Id": unit, **{
            key: " ".join(self.relations.get(unit, {}).get(key, set()))
            for key in self.stop_relations + self.keep_relations
        }}
        values["RequiredBy"] = " ".join(self.consumers.get(unit, set()))
        return "\n".join(f"{key}={values[key]}" for key in properties)

    def effects(self, units):
        pending, seen, result = list(units), set(), {}
        while pending:
            unit = pending.pop()
            if unit in seen:
                continue
            seen.add(unit)
            result[f"multi-user.target.wants/{unit}"] = f"/usr/lib/systemd/system/{unit}"
            for alias in self.install_aliases.get(unit, []):
                result[alias] = f"/usr/lib/systemd/system/{unit}"
            pending.extend(self.also.get(unit, set()))
        return result

    def enable_plan(self, units, owned):
        actual = self.links()
        return {name: target for name, target in self.effects(units).items()
                if name not in actual or actual[name] == owned.get(name)}

    def change(self, *args):
        self.actions.append(args)
        if args[0] == "enable":
            for name, target in self.effects(args[args.index("--") + 1:]).items():
                path = self.directory / name
                path.parent.mkdir(exist_ok=True)
                if not path.is_symlink():
                    path.symlink_to(target)
        # A failure can occur after side effects, as with an interrupted enable.
        if self.fail == args[0]:
            raise RuntimeError("injected failure")
        if args[0] in {"start", "restart"}:
            self.running.add(args[-1])
        elif args[0] == "stop":
            stopped = set(args[2:])
            while True:
                dependents = set().union(*(self.relationships(unit)[1] for unit in stopped))
                dependents = {self.aliases.get(unit, unit) for unit in dependents}
                if dependents <= stopped:
                    break
                stopped |= dependents
            self.running -= stopped


class DefinitionsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.state = self.root / "state.json"
        self.system = FakeSystemd(self.root / "system")
        self.source = self.root / "source"
        self.source.write_text("[Service]\nExecStart=/first\n")
        self.unit = "example.service"

    def apply(self, enabled=True, owner="alice"):
        helper.reconcile(self.state, owner, [self.unit] if enabled else [], self.system,
                         definitions={self.unit: str(self.source)} if enabled else {})

    def test_create_update_restart_repeat_and_retire(self):
        self.apply()
        self.assertEqual((self.system.directory / self.unit).read_text(), self.source.read_text())
        self.assertTrue(self.system.active(self.unit))
        self.system.actions.clear()
        self.apply()
        self.assertEqual(self.system.actions, [])
        self.source.write_text("[Service]\nExecStart=/second\n")
        self.apply()
        self.assertIn(("restart", "--", self.unit), self.system.actions)
        self.apply(False)
        self.assertFalse((self.system.directory / self.unit).exists())
        self.assertFalse(self.system.active(self.unit))
        self.system.actions.clear()
        self.apply(False)
        self.assertEqual(self.system.actions, [])

    def test_failed_restart_retries_without_losing_ownership(self):
        self.apply()
        self.source.write_text("changed")
        self.system.fail = "restart"
        with self.assertRaisesRegex(RuntimeError, "injected"):
            self.apply()
        self.system.fail = None
        self.system.actions.clear()
        self.apply()
        self.assertIn(("restart", "--", self.unit), self.system.actions)
        self.apply(False)
        self.assertFalse((self.system.directory / self.unit).exists())

    def test_external_file_is_neither_adopted_nor_deleted(self):
        target = self.system.directory / self.unit
        target.write_text("foreign")
        self.system.running.add(self.unit)
        with self.assertRaisesRegex(RuntimeError, "Preserving"):
            self.apply()
        self.apply(False)
        self.assertEqual(target.read_text(), "foreign")
        self.assertTrue(self.system.active(self.unit))

    def test_shared_definition_keeps_other_owner(self):
        self.apply()
        self.apply(owner="bob")
        self.apply(False)
        self.assertTrue((self.system.directory / self.unit).exists())
        self.assertTrue(self.system.active(self.unit))
        self.apply(False, owner="bob")
        self.assertFalse((self.system.directory / self.unit).exists())

    def test_edited_managed_file_is_preserved(self):
        self.apply()
        target = self.system.directory / self.unit
        target.write_text("foreign edit")
        with self.assertRaisesRegex(RuntimeError, "Preserving"):
            self.apply(False)
        self.assertEqual(target.read_text(), "foreign edit")

    def test_active_foreign_consumer_preserves_definition(self):
        self.apply()
        self.system.running.add("foreign.service")
        self.system.consumers[self.unit] = {"foreign.service"}
        with self.assertRaisesRegex(RuntimeError, "still used"):
            self.apply(False)
        self.assertTrue((self.system.directory / self.unit).exists())
        self.system.running.clear()
        self.apply(False)
        self.assertFalse((self.system.directory / self.unit).exists())

    def test_enable_only_consumer_preserves_definition(self):
        self.apply()
        helper.reconcile(self.state, "bob", [], self.system, enable_only=[self.unit])
        self.system.running.clear()
        with self.assertRaisesRegex(RuntimeError, "still used"):
            self.apply(False)
        self.assertTrue((self.system.directory / self.unit).exists())
        helper.reconcile(self.state, "bob", [], self.system)
        self.apply(False)
        self.assertFalse((self.system.directory / self.unit).exists())

    def test_request_without_definition_does_not_restart_foreign_edit(self):
        self.apply()
        (self.system.directory / self.unit).write_text("external")
        self.system.actions.clear()
        helper.reconcile(self.state, "bob", [self.unit], self.system)
        self.assertNotIn(("restart", "--", self.unit), self.system.actions)

    def test_template_definitions_rejected_before_effects(self):
        with self.assertRaisesRegex(ValueError, "definitions"):
            helper.reconcile(self.state, "alice", [], self.system,
                             definitions={"worker@.service": str(self.source)})
        self.assertFalse(self.state.exists())
        self.assertEqual(list(self.system.directory.iterdir()), [])


class QueryTest(unittest.TestCase):
    def test_verification_requires_ready_units_but_not_enable_only_jobs(self):
        system = helper.Systemd()
        with patch.object(system, "enabled", return_value="enabled"):
            for state in ["activating", "deactivating", "inactive", "failed"]:
                with self.subTest(state=state), patch.object(system, "query", return_value=state):
                    with self.assertRaisesRegex(RuntimeError, "not ready"):
                        system.verify(["host.service"])
            with patch.object(system, "query", return_value="active"):
                system.verify(["host.service"])
            with patch.object(system, "query") as query:
                system.verify([], ["boot.service"])
                query.assert_not_called()

    def test_state_queries_reject_errors_and_empty_results(self):
        system = helper.Systemd()
        for method in [system.enabled, system.active]:
            with self.subTest(method=method.__name__), patch.object(helper.subprocess, "run", return_value=CompletedProcess([], 1, "", "bus unavailable")):
                with self.assertRaisesRegex(RuntimeError, "bus unavailable"):
                    method("host.service")
        for method in [system.enabled, system.active]:
            for state in ["", "unknown"]:
                with self.subTest(method=method.__name__, state=state), patch.object(helper.subprocess, "run", return_value=CompletedProcess([], 0, state, "")):
                    with self.assertRaisesRegex(RuntimeError, "unknown"):
                        method("host.service")

    def test_active_and_inactive_states(self):
        for state in ["active", "activating", "deactivating", "maintenance", "refreshing", "inactive", "failed"]:
            with self.subTest(state=state), patch.object(helper.subprocess, "run", return_value=CompletedProcess([], 0, state, "")):
                self.assertEqual(helper.Systemd().active("host.service"), state not in {"inactive", "failed"})

    def test_consumer_query_failure_is_not_inactivity(self):
        properties = "Id=owned.socket\n" + "\n".join(f"{key}=" + ("foreign.service" if key == "RequiredBy" else "") for key in helper.Systemd.stop_relations + helper.Systemd.keep_relations)
        results = [CompletedProcess([], 0, properties, ""), CompletedProcess([], 1, "", "bus unavailable")]
        with patch.object(helper.subprocess, "run", side_effect=results):
            with self.assertRaisesRegex(RuntimeError, "bus unavailable"):
                helper.Systemd().referenced("owned.socket", [])


class UnitsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / "state.json"
        self.system = FakeSystemd(self.root / "system")

    def apply(self, units, owner="alice"):
        helper.reconcile(self.state, owner, units, self.system)

    def test_failed_initial_query_does_not_claim_host_service(self):
        self.system.running.add("host.service")
        with patch.object(self.system, "active", wraps=lambda unit: helper.Systemd.active(self.system, unit)), patch.object(helper.subprocess, "run", return_value=CompletedProcess([], 1, "", "bus unavailable")):
            with self.assertRaisesRegex(RuntimeError, "bus unavailable"):
                self.apply(["host.service"])
        self.assertFalse(self.state.exists())
        self.assertEqual(self.system.actions, [])
        self.apply(["host.service"])
        self.apply([])
        self.assertIn("host.service", self.system.running)

    def test_failed_cleanup_query_retains_record_for_retry(self):
        self.apply(["owned.service"])
        with patch.object(self.system, "active", wraps=lambda unit: helper.Systemd.active(self.system, unit)), patch.object(helper.subprocess, "run", return_value=CompletedProcess([], 1, "", "bus unavailable")):
            with self.assertRaisesRegex(RuntimeError, "bus unavailable"):
                self.apply([])
        self.assertIn("owned.service", self.system.running)
        self.assertIn("owned.service", json.loads(self.state.read_text())["units"])
        self.apply([])
        self.assertFalse(self.system.running)

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

    def test_migration_preserves_only_recorded_ownership(self):
        self.system.link("owned.service")
        recorded = self.system.links()
        self.system.link("owned.service", "unrecorded.service")
        self.system.running.add("owned.service")
        self.state.write_text(json.dumps({
            "version": 1, "owners": {"alice": ["owned.service"]}, "reload": False,
            "units": {"owned.service": {"enabled": "disabled", "active": False, "links": recorded}},
            "pending": None,
        }))
        self.apply([])
        self.assertEqual(json.loads(self.state.read_text())["version"], 2)
        self.assertEqual(set(self.system.links()), {"multi-user.target.wants/unrecorded.service"})
        self.assertTrue(self.system.active("owned.service"))

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

    def test_implicit_alias_effects_and_shared_parents(self):
        self.system.also = {"network.service": {"dispatcher.service"},
                            "other.service": {"dispatcher.service"}}
        self.system.install_aliases = {"dispatcher.service": ["dbus-dispatcher.service"]}
        self.apply(["network.service"])
        self.assertFalse(self.system.active("dispatcher.service"))
        self.assertIn("dbus-dispatcher.service", json.loads(self.state.read_text())["links"])
        self.apply(["other.service"], owner="bob")
        self.apply([])
        self.assertIn("dbus-dispatcher.service", self.system.links())
        self.apply([], owner="bob")
        self.assertFalse(self.system.links())

    def test_implicit_to_explicit_and_back(self):
        self.apply(["avahi-daemon.service"])
        self.apply(["avahi-daemon.socket"], owner="bob")
        self.apply([])
        self.assertTrue(self.system.links(["avahi-daemon.socket"]))
        self.apply([], owner="bob")
        self.assertFalse(self.system.links())
        self.assertFalse(self.system.running)

    def test_preexisting_implicit_alias_and_modified_owned_alias(self):
        self.system.also = {"network.service": {"dispatcher.service"}}
        self.system.install_aliases = {"dispatcher.service": ["dbus-dispatcher.service"]}
        alias = self.system.directory / "dbus-dispatcher.service"
        alias.symlink_to("/usr/lib/systemd/system/dispatcher.service")
        self.apply(["network.service"])
        self.apply([])
        self.assertTrue(alias.is_symlink())
        alias.unlink()
        self.apply(["network.service"])
        alias.unlink()
        alias.symlink_to("/administrator/dispatcher.service")
        self.apply([])
        self.assertEqual(os.readlink(alias), "/administrator/dispatcher.service")

    def test_all_stop_relations_and_inactive_intermediates(self):
        for relation in self.system.stop_relations:
            for intermediate in [False, True]:
                with self.subTest(relation=relation, intermediate=intermediate):
                    self.apply(["owned.service"])
                    self.system.running.add("foreign.service")
                    if intermediate:
                        self.system.relations = {
                            "owned.service": {relation: {"idle.service"}},
                            "idle.service": {"ConsistsOf": {"foreign.service"}},
                        }
                    else:
                        self.system.relations = {"owned.service": {relation: {"foreign.service"}}}
                    # RequiredBy uses the legacy fixture mapping.
                    if relation == "RequiredBy":
                        self.system.consumers = {"owned.service": {"idle.service" if intermediate else "foreign.service"}}
                    self.apply([])
                    self.assertIn("owned.service", self.system.running)
                    self.assertIn("foreign.service", self.system.running)
                    self.system.running.clear()
                    self.system.relations.clear()
                    self.system.consumers.clear()

    def test_aliases_do_not_turn_owned_cycles_into_foreign_consumers(self):
        self.system.aliases = {"alias.service": "b.service"}
        self.system.relations = {"a.service": {"ConsistsOf": {"alias.service"}},
                                 "b.service": {"ConsistsOf": {"a.service"}}}
        self.apply(["a.service", "b.service"])
        self.apply([])
        self.assertFalse(self.system.running)

    def test_planning_failure_has_no_live_effects(self):
        self.apply(["owned.service"])
        before = self.state.read_bytes(), self.system.links(), list(self.system.actions)
        with patch.object(self.system, "enable_plan", side_effect=RuntimeError("namespace unavailable")):
            with self.assertRaisesRegex(RuntimeError, "namespace unavailable"):
                self.apply(["other.service"])
        self.assertEqual(before, (self.state.read_bytes(), self.system.links(), self.system.actions))

    def test_plan_rejects_directory_symlinks_before_subprocess(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.system.directory / "multi-user.target.wants").symlink_to(outside)
        with patch.object(helper.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "symlinked systemd directory"):
                helper.Systemd.enable_plan(self.system, ["owned.service"], {})
            run.assert_not_called()

    def test_failed_enable_records_all_implicit_effects(self):
        self.system.fail = "enable"
        with self.assertRaises(RuntimeError):
            self.apply(["avahi-daemon.service"])
        self.system.fail = None
        self.apply([])
        self.assertFalse(self.system.links())

    def test_implicit_activity_alone_is_not_runtime_ownership(self):
        self.apply(["avahi-daemon.service"])
        self.system.running.add("avahi-daemon.socket")
        self.apply([])
        self.assertTrue(self.system.active("avahi-daemon.socket"))
        self.assertFalse(self.system.links())

    def test_pending_plan_recovers_only_expected_effects(self):
        self.apply(["avahi-daemon.service"])
        state = json.loads(self.state.read_text())
        state["pending"], state["links"] = state["links"], {}
        state["reload"] = True
        self.state.write_text(json.dumps(state))
        self.system.link("foreign.service")
        self.apply([])
        self.assertEqual(set(self.system.links()), {"multi-user.target.wants/foreign.service"})

    def test_vendor_install_changes_retire_obsolete_effects(self):
        self.apply(["avahi-daemon.service"])
        self.system.also = {}
        self.apply(["avahi-daemon.service"])
        self.assertFalse(self.system.links(["avahi-daemon.socket"]))
        self.assertTrue(self.system.active("avahi-daemon.service"))



unittest.main()
