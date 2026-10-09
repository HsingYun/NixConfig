"""Exercise confirmation, immutable previews, provenance and upstream adapters."""
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from nixman import backends, cleanup, cli, flake, preview, profiles, runtime


class NixmanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.output = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)

    def test_passes_relative_directory_to_nix_for_canonicalization(self):
        base, host = flake.normalize(".#Darwin")
        self.assertEqual(base, ".")
        self.assertEqual(host, "Darwin")
        self.assertEqual(flake.normalize("path:./#Darwin"), ("path:./", "Darwin"))

    def test_passes_native_reference_types_and_queries_unchanged(self):
        for base in ("../config", "/absolute/path", "path:../config", "flake:my-config",
                     "git+file:///tmp/config?ref=main&dir=hosts/mac",
                     "git+ssh://git@example.com/config?ref=main",
                     "git+https://example.com/config.git?rev=abcd",
                     "gitlab:owner/repo/branch", "https://example.com/config.tar.gz",
                     "file:///tmp/config.tar.gz", ".?dir=subflake"):
            with self.subTest(base=base):
                self.assertEqual(flake.normalize(base + "#host"), (base, "host"))

    def test_normalizes_named_reference_without_changing_branch(self):
        self.assertEqual(flake.normalize("github:HsingYun/NixConfig/master#Darwin"),
                         ("github:HsingYun/NixConfig/master", "Darwin"))

    def test_rejects_inline_secrets(self):
        for ref in ("https://user:password@example.com/flake#host",
                    "github:owner/repo?access_token=test#host", "https://token@example.com/flake",
                    "x\n#host"):
            with self.subTest(ref=ref), self.assertRaises(runtime.Error):
                flake.normalize(ref)

    def test_saved_metadata_and_old_generations(self):
        self.assertIsNone(profiles.metadata(self.root))
        value = {"schema": 1, "flake": "github:owner/repo#host", "backend": "nixos"}
        (self.root / "nixman.json").write_text(json.dumps(value))
        self.assertEqual(profiles.metadata(self.root), value)
        (self.root / "nixman.json").write_text('{"schema": 9}')
        with self.assertRaises(runtime.Error):
            profiles.metadata(self.root)

    def test_profile_selection_distinguishes_running_from_selected(self):
        old, new = self.root / "old", self.root / "new"
        old.mkdir(); new.mkdir()
        profile = self.root / "system"
        (self.root / "system-1-link").symlink_to(old)
        (self.root / "system-2-link").symlink_to(new)
        profile.symlink_to("system-2-link")
        backend = Mock()
        backend.profile.return_value = profile
        backend.active.return_value = old
        gens = profiles.generations(backend)
        self.assertEqual([(g.id, g.selected, g.active) for g in gens], [(2, True, False), (1, False, True)])
        self.assertEqual(profiles.select(backend, 1).path, old)
        with self.assertRaises(runtime.Error):
            profiles.select(backend, 99)

    def test_current_marker_is_not_an_activation_success_claim(self):
        backend = Mock()
        backend.profile.return_value = self.root / "system"
        backend.active.return_value = None
        self.assertEqual(profiles.generations(backend), [])

    def test_populated_profile_without_links_is_rejected_independently_of_payload_format(self):
        for marker in ("manifest.json", "manifest.nix", "hm-version", "darwin-version", "arbitrary-file"):
            target = self.root / marker.replace('.', '-')
            target.mkdir()
            (target / marker).write_text('{}')
            profile = self.root / (target.name + "-profile")
            profile.symlink_to(target)
            (self.root / (target.name + "-other-1-link")).symlink_to(target)
            backend = Mock()
            backend.active.return_value = target
            for path in (profile, target):
                with self.subTest(marker=marker, profile=path):
                    backend.profile.return_value = path
                    for read in (profiles.generations, profiles.fingerprint):
                        with self.assertRaisesRegex(runtime.Error, "no numbered generation links") as error:
                            read(backend)
                        self.assertIn(str(path), str(error.exception))

    def test_profile_selector_must_identify_its_own_numbered_link(self):
        target = self.root / "target"
        target.mkdir()
        profile = self.root / "system"
        (self.root / "system-1-link").symlink_to(target)
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        (elsewhere / "system-1-link").symlink_to(target)
        backend = Mock()
        backend.profile.return_value = profile
        backend.active.return_value = target
        for destination in (None, target, "system-2-link", elsewhere / "system-1-link"):
            with self.subTest(destination=destination):
                if destination is not None:
                    profile.symlink_to(destination)
                with self.assertRaisesRegex(runtime.Error, "Invalid profile"):
                    profiles.generations(backend)
                if profile.is_symlink():
                    profile.unlink()
        profile.symlink_to(self.root / "system-1-link")
        self.assertTrue(profiles.generations(backend)[0].selected)

    def test_non_link_generation_entries_are_invalid(self):
        profile = self.root / "system"
        entry = self.root / "system-1-link"
        entry.mkdir()
        profile.symlink_to(entry)
        backend = Mock()
        backend.profile.return_value = profile
        with self.assertRaisesRegex(runtime.Error, "numbered generation entry.*not a symbolic link"):
            profiles.generations(backend)

    def test_dangling_selector_without_generations_is_not_uninitialized(self):
        profile = self.root / "system"
        profile.symlink_to("system-1-link")
        backend = Mock()
        backend.profile.return_value = profile
        with self.assertRaisesRegex(runtime.Error, "no numbered generation links"):
            profiles.generations(backend)

    def test_regular_file_is_not_an_uninitialized_profile(self):
        profile = self.root / "system"
        profile.touch()
        backend = Mock()
        backend.profile.return_value = profile
        with self.assertRaisesRegex(runtime.Error, "Invalid profile"):
            profiles.fingerprint(backend)

    def test_empty_directory_with_history_is_not_uninitialized(self):
        profile = self.root / "system"
        profile.mkdir()
        (self.root / "system-1-link").symlink_to(self.root / "collected")
        backend = Mock()
        backend.profile.return_value = profile
        with self.assertRaisesRegex(runtime.Error, "profile selector.*not a symbolic link"):
            profiles.generations(backend)

    def test_manifest_with_generation_links_can_be_enumerated(self):
        target = self.root / "target"
        target.mkdir()
        (target / "manifest.json").write_text('{}')
        (self.root / "system-1-link").symlink_to(target)
        # Collected targets still have a generation identity until their links are removed.
        (self.root / "system-2-link").symlink_to(self.root / "collected")
        profile = self.root / "system"
        profile.symlink_to("system-1-link")
        backend = Mock()
        backend.profile.return_value = profile
        backend.active.return_value = target
        self.assertEqual([(g.id, g.selected, g.active) for g in profiles.generations(backend)],
                         [(2, False, False), (1, True, True)])
        with self.assertRaisesRegex(runtime.Error, "garbage-collected or is unavailable"):
            profiles.select(backend, 2)
        profile.unlink()
        profile.symlink_to("system-2-link")
        self.assertTrue(profiles.generations(backend)[0].selected)

    def test_empty_profile_directory_remains_empty(self):
        backend = Mock()
        backend.profile.return_value = self.root
        backend.active.return_value = None
        self.assertEqual(profiles.generations(backend), [])

    def test_generation_cleanup_rejects_manifest_without_links_before_confirmation(self):
        (self.root / "manifest.json").write_text('{}')
        backend = Mock()
        backend.profile.return_value = self.root
        backend.active.return_value = self.root
        confirm = Mock()
        args = argparse.Namespace(count=None, dry_run=False, yes=True)
        with patch.object(cleanup, "run") as run, self.assertRaisesRegex(runtime.Error, "no numbered generation links"):
            cleanup.generation_gc(backend, args, confirm)
        confirm.assert_not_called()
        run.assert_not_called()

    def test_home_profile_precedence_matches_upstream(self):
        state, nix_state = self.root / "user", self.root / "nix"
        user = backends.pwd.getpwuid(os.getuid()).pw_name
        local = state / "nix/profiles"
        global_ = nix_state / "profiles/per-user" / user
        global_.mkdir(parents=True)
        with patch.dict(os.environ, {"XDG_STATE_HOME": str(state), "NIX_STATE_DIR": str(nix_state)}):
            backend = backends.BACKENDS["home-manager"]
            self.assertEqual(backend.profile(), global_ / "home-manager")
            local.mkdir(parents=True)
            self.assertEqual(backend.profile(), local / "home-manager")

    def test_confirmation_default_yes_and_explicit_no(self):
        with patch.object(cli.sys.stdin, "isatty", return_value=True):
            for answer, expected in (("", True), ("y", True), ("YES", True), ("n", False)):
                with patch("builtins.input", return_value=answer):
                    self.assertEqual(cli.confirm(False), expected)
            with patch("builtins.input", side_effect=EOFError):
                self.assertFalse(cli.confirm(False))

    def test_noninteractive_requires_explicit_yes(self):
        with patch.object(cli.sys.stdin, "isatty", return_value=False):
            with self.assertRaises(runtime.Error):
                cli.confirm(False)
            self.assertTrue(cli.confirm(True))

    def update_context(self, *, reference="github:owner/repo#host", dry_run=False, yes=False):
        backend = Mock()
        backend.name = "nixos"
        backend.command = "nixos-rebuild"
        old, new = self.root / "old", self.root / "new"
        old.mkdir(exist_ok=True); new.mkdir(exist_ok=True)
        backend.active.side_effect = [old, old, new] if reference is None else [old, new]
        args = argparse.Namespace(flake=reference, dry_run=dry_run, yes=yes)
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        mocks = {}
        for name, value in {"fingerprint": ("original",), "executable": "/tool",
                            "prepare": (backend, self.root / "frozen", {"flake": "saved#host"}),
                            "detect": backend,
                            "build": new, "preview": None, "confirm": True}.items():
            mocks[name] = stack.enter_context(patch.object(cli, name, return_value=value))
        return backend, args, mocks

    def test_cancel_leaves_profile_and_backend_untouched(self):
        backend, args, mocks = self.update_context()
        mocks["confirm"].return_value = False
        cli.update(args)
        mocks["preview"].assert_called_once()
        backend.update.assert_not_called()

    def test_dry_run_builds_preview_but_never_activates(self):
        backend, args, mocks = self.update_context(dry_run=True)
        cli.update(args)
        mocks["build"].assert_called_once()
        mocks["preview"].assert_called_once()
        mocks["confirm"].assert_not_called()
        backend.update.assert_not_called()

    def test_confirmation_applies_same_frozen_wrapper(self):
        backend, args, mocks = self.update_context(yes=True)
        cli.update(args)
        backend.update.assert_called_once_with(self.root / "frozen")

    def test_profile_change_during_confirmation_aborts(self):
        backend, args, mocks = self.update_context()
        mocks["fingerprint"].side_effect = [("original",), ("original",), ("new",)]
        with self.assertRaisesRegex(runtime.Error, "changed during preview"):
            cli.update(args)
        backend.update.assert_not_called()

    def test_build_failure_cannot_activate(self):
        backend, args, mocks = self.update_context()
        mocks["build"].side_effect = subprocess.CalledProcessError(1, ["nix", "build"])
        with self.assertRaises(subprocess.CalledProcessError):
            cli.update(args)
        backend.update.assert_not_called()

    def test_omitted_argument_uses_active_generation_source(self):
        backend, args, mocks = self.update_context(reference=None, dry_run=True)
        with patch.object(cli, "metadata", return_value={"flake": "path:/old/location#old-host", "backend": "nixos"}):
            cli.update(args)
        self.assertEqual(mocks["prepare"].call_args.args[0], "path:/old/location#old-host")

    def test_unknown_source_requires_explicit_argument(self):
        backend, args, mocks = self.update_context(reference=None)
        with patch.object(cli, "metadata", return_value=None), self.assertRaises(runtime.Error):
            cli.update(args)
        backend.update.assert_not_called()

    def test_update_backend_uses_frozen_flake_and_correct_privilege(self):
        for backend in backends.BACKENDS.values():
            with self.subTest(backend=backend.name), patch.object(backends, "run") as run, patch.object(backends, "executable", side_effect=lambda name: "/bin/" + name):
                backend.update(self.root)
                run.assert_called_once_with(["/bin/" + backend.command, "switch", "--flake",
                                             str(self.root) + "#nixman", *flake.WRAPPER_OPTIONS, "--no-update-lock-file"],
                                            privileged=backend.system)

    def test_generation_adapters_use_existing_generation(self):
        gen = profiles.Generation(3, "date", self.root, False, False)
        (self.root / "bin").mkdir()
        for file in (self.root / "activate", self.root / "bin/switch-to-configuration"):
            file.write_text("#!/bin/sh\nexit 0\n")
            file.chmod(0o755)
        with patch.object(backends, "run") as run, patch.object(backends, "executable", side_effect=lambda name: name):
            backends.BACKENDS["darwin"].switch(self.root / "profile", gen)
            self.assertEqual(run.call_args.args[0], ["darwin-rebuild", "switch", "--switch-generation", "3"])
            run.reset_mock()
            backends.BACKENDS["nixos"].switch(self.root / "profile", gen)
            self.assertEqual(run.call_args.args[0], [self.root / "bin/switch-to-configuration", "switch"])
            (self.root / "gen-version").write_text("1")
            run.reset_mock()
            backends.BACKENDS["home-manager"].switch(self.root / "profile", gen)
            self.assertEqual(run.call_args.args[0], [self.root / "activate", "--driver-version", "1"])
            (self.root / "gen-version").unlink()
            backends.BACKENDS["home-manager"].switch(self.root / "profile", gen)
            self.assertEqual(run.call_args.args[0], [self.root / "activate"])

    def test_missing_activation_script_does_not_change_profile(self):
        gen = profiles.Generation(3, "date", self.root, False, False)
        with patch.object(backends, "run") as run, self.assertRaises(runtime.Error):
            backends.BACKENDS["nixos"].switch(self.root / "profile", gen)
        run.assert_not_called()

    def test_specialisation_protects_its_parent_generation(self):
        parent, active = self.root / "system-generation", self.root / "specialised"
        (parent / "specialisation").mkdir(parents=True)
        active.mkdir()
        (parent / "specialisation/foo").symlink_to(active)
        (self.root / "system-1-link").symlink_to(parent)
        (self.root / "system").symlink_to("system-1-link")
        backend = Mock()
        backend.profile.return_value = self.root / "system"
        backend.active.return_value = active
        self.assertTrue(profiles.generations(backend)[0].active)

    def test_destructive_confirmation_defaults_to_no(self):
        with patch.object(cli.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="") as prompt:
            self.assertFalse(cli.confirm(False, destructive=True))
            self.assertIn("[y/N]", prompt.call_args.args[0])

    def test_generation_cleanup_protects_active_and_selected_and_counts_oldest(self):
        gens = [profiles.Generation(i, "date", self.root / str(i), i == 4, i == 2) for i in (4, 3, 2, 1)]
        with patch.object(cleanup, "generations", return_value=gens):
            self.assertEqual([g.id for g in cleanup.generation_plan(Mock(), 1)], [1])
            self.assertEqual([g.id for g in cleanup.generation_plan(Mock(), None)], [1, 3])

    def test_generation_cleanup_only_deletes_reviewed_ids(self):
        backend = Mock()
        backend.system = True
        backend.profile.return_value = self.root / "system"
        plan = [profiles.Generation(1, "date", self.root / "1", False, False)]
        args = argparse.Namespace(count=1, dry_run=False, yes=False)
        with patch.object(cleanup, "generation_plan", return_value=plan), patch.object(cleanup, "fingerprint", return_value=("stable",)), patch.object(cleanup, "run") as run, patch.object(cleanup, "executable", return_value="nix-env"):
            cleanup.generation_gc(backend, args, Mock(return_value=True))
            run.assert_called_once_with(["nix-env", "--profile", self.root / "system", "--delete-generations", "1"], privileged=True)

    def test_generation_cleanup_aborts_on_concurrent_changes(self):
        args = argparse.Namespace(count=None, dry_run=False, yes=False)
        plan = [profiles.Generation(1, "date", self.root / "1", False, False)]
        with patch.object(cleanup, "generation_plan", return_value=plan), patch.object(cleanup, "fingerprint", side_effect=[("old",), ("new",)]), patch.object(cleanup, "run") as run, self.assertRaises(runtime.Error):
            cleanup.generation_gc(Mock(), args, Mock(return_value=True))
        run.assert_not_called()

    def test_generation_cleanup_cancel_and_dry_run_do_not_delete(self):
        for dry_run in (False, True):
            args = argparse.Namespace(count=None, dry_run=dry_run, yes=False)
            plan = [profiles.Generation(1, "date", self.root / "1", False, False)]
            with patch.object(cleanup, "generation_plan", return_value=plan), patch.object(cleanup, "fingerprint", return_value=("stable",)), patch.object(cleanup, "run") as run:
                cleanup.generation_gc(Mock(), args, Mock(return_value=False))
                run.assert_not_called()

    def test_store_cleanup_delegates_liveness_and_remnants_to_nix(self):
        paths = ["/nix/store/a.drv", "/nix/store/b-source"]
        args = argparse.Namespace(dry_run=False, yes=False)
        with patch.object(cleanup, "dead_paths", return_value=paths), patch.object(cleanup, "estimate_store_size", return_value={"bytes": 1024, "basis": "nar", "unmeasuredPaths": 0}), patch.object(cleanup, "nix") as nix:
            cleanup.store_gc(args, Mock(return_value=True))
            nix.assert_called_once_with("store", "gc")

    def test_store_cleanup_rejects_path_that_became_live(self):
        args = argparse.Namespace(dry_run=False, yes=False)
        path = "/nix/store/old"
        with patch.object(cleanup, "dead_paths", side_effect=[[path], []]), patch.object(cleanup, "estimate_store_size", return_value={"bytes": 1024, "basis": "nar", "unmeasuredPaths": 0}), patch.object(cleanup, "nix") as nix, self.assertRaises(runtime.Error):
            cleanup.store_gc(args, Mock(return_value=True))
        nix.assert_not_called()

    def test_store_cleanup_cancel_dry_run_and_empty_are_read_only(self):
        for dry_run, paths in ((False, []), (False, ["/nix/store/old"]), (True, ["/nix/store/old"])):
            args = argparse.Namespace(dry_run=dry_run, yes=False)
            with patch.object(cleanup, "dead_paths", return_value=paths), patch.object(cleanup, "estimate_store_size", return_value={"bytes": 1024, "basis": "nar", "unmeasuredPaths": 0}), patch.object(cleanup, "nix") as nix:
                cleanup.store_gc(args, Mock(return_value=False))
                nix.assert_not_called()

    def test_store_cleanup_requires_new_preview_if_dead_set_grows(self):
        args = argparse.Namespace(dry_run=False, yes=False)
        with patch.object(cleanup, "dead_paths", side_effect=[["/nix/store/old"], ["/nix/store/old", "/nix/store/new"]]), patch.object(cleanup, "estimate_store_size", return_value={"bytes": 1024, "basis": "nar", "unmeasuredPaths": 0}), patch.object(cleanup, "nix") as nix, self.assertRaises(runtime.Error):
            cleanup.store_gc(args, Mock(return_value=True))
        nix.assert_not_called()

    def test_unchanged_update_uses_generation_registration_prompt(self):
        backend, args, mocks = self.update_context()
        mocks["preview"].return_value = False
        cli.update(args)
        mocks["confirm"].assert_called_once_with(False, no_changes=True)

    def test_no_change_detection_ignores_only_provenance_and_self_references(self):
        old, new = self.root / "old", self.root / "new"
        old.mkdir(); new.mkdir()
        for root in (old, new):
            (root / "activate").write_text(f'GENERATION="{root}"\necho activate\n')
            record = self.root / (root.name + ".json")
            record.write_text(json.dumps({"schema": 1, "flake": root.name}))
            (root / "nixman.json").symlink_to(record)
        def closure(args, capture):
            root = args[-1]
            return f"{root}\n{(root / 'nixman.json').resolve()}\n/nix/store/shared-runtime\n"
        with patch.object(preview, "run", side_effect=closure):
            self.assertTrue(preview.configuration_equal(old, new))
            (new / "activate").write_text('echo changed-services\n')
            self.assertFalse(preview.configuration_equal(old, new))

    def test_new_dependency_prevents_false_no_change(self):
        old, new = self.root / "old", self.root / "new"
        old.mkdir(); new.mkdir()
        with patch.object(preview, "run", side_effect=[f"{old}\n/nix/store/a\n", f"{new}\n/nix/store/b\n"]):
            self.assertFalse(preview.configuration_equal(old, new))

    def test_rollback_uses_running_generation_not_newer_selected_one(self):
        available = [profiles.Generation(i, "date", self.root, i == 4, i == 3) for i in (4, 3, 2, 1)]
        args = argparse.Namespace(yes=False, dry_run=True)
        with patch.object(cli, "generations", return_value=available), patch.object(cli, "switch") as switch:
            cli.rollback(Mock(), args)
            self.assertEqual(switch.call_args.args[1].generation, 2)

    def test_declared_file_preview_includes_embedded_home_settings(self):
        file = self.root / "settings.json"
        file.write_text('{"theme":"dark"}')
        data = {"managedFiles": {"/Users/example/.config/editor/settings.json": str(file)}}
        self.assertEqual(list(preview.declared_files(data)), ["/Users/example/.config/editor/settings.json"])

    def test_managed_file_preview_includes_symlink_directory_changes(self):
        root = self.root / "files"
        root.mkdir()
        (root / "file").write_text("private contents")
        (root / "linked-directory").symlink_to("/missing/store/config-directory")
        result = preview.file_manifest(root)
        self.assertEqual(set(result), {"file", "linked-directory"})
        self.assertNotIn("private contents", repr(result))
        self.assertEqual(list(preview.changes({}, result)), [("+", "file"), ("+", "linked-directory")])

    def test_native_preview_reports_unknown_baseline_and_retention(self):
        preview.native_preview(None, {"native": {"pacman": {"packages": ["foo"], "aur": ["bar"]}}})
        text = self.output.getvalue()
        self.assertIn("pacman.packages: foo", text)
        self.assertIn("pacman.aur: bar", text)
        self.assertIn("not necessarily absent", text)
        self.assertIn("may retain", text)

    def test_prepare_pins_source_without_changing_original_lock(self):
        source = self.root / "source-dir"
        source.mkdir()
        (source / "flake.lock").write_text("original lock")
        request_dir = self.root / "request"
        request_dir.mkdir()
        with patch.object(flake, "nix_json", side_effect=[{"path": str(source), "originalUrl": "github:owner/repo/main", "url": "github:owner/repo/abc", "locked": {"type": "git", "rev": "abc", "narHash": "sha256-test", "dir": "sub", "lastModified": 123}}, {"nixos": ["host"]}]) as fetch, patch.object(flake, "nix") as nix, patch.object(flake, "run"):
            backend, wrapper, data = flake.prepare("github:owner/repo/main#host", request_dir)
        self.assertEqual(backend.name, "nixos")
        self.assertEqual((source / "flake.lock").read_text(), "original lock")
        self.assertIn("--refresh", fetch.call_args_list[0].args)
        self.assertIn("--no-update-lock-file", fetch.call_args_list[0].args)
        nix.assert_called_once_with("flake", "lock", *flake.WRAPPER_OPTIONS, str(wrapper))
        self.assertEqual(data["flake"], "github:owner/repo/main#host")
        locked = json.loads((wrapper / "locked-input.json").read_text())
        self.assertEqual(locked["type"], "git")
        self.assertEqual(locked["dir"], "sub")
        self.assertEqual(locked["lastModified"], 123)
        self.assertIn("original.extendModules", (wrapper / "flake.nix").read_text())

    def test_cli_parses_all_public_commands(self):
        for command in (["generation", "list"], ["generation", "info", "3"],
                        ["generation", "switch", "3", "-y"], ["update"],
                        ["update", ".#Darwin", "--dry-run"], ["status"], ["rollback"],
                        ["generation", "diff", "1", "2"], ["generation", "gc"],
                        ["generation", "gc", "--oldest", "3", "--dry-run"], ["gc", "--dry-run"]):
            cli.parser().parse_args(command)

    def test_snapshot_is_not_a_command_alias(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            cli.parser().parse_args(["snapshot", "list"])
        self.assertEqual(error.exception.code, 2)

    def test_fetcher_literals_cannot_interpolate_nix_code(self):
        self.assertEqual(flake.literal('${builtins.abort "unexpected"}'),
                         '"\\${builtins.abort \\"unexpected\\"}"')


if __name__ == "__main__":
    unittest.main()
