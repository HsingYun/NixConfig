"""Retention policies, machine-readable inspection and backend-free completion."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from nixman import backends, cleanup, cli, completion, flake, inspection, profiles
from nixman.runtime import Error


class InterfaceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.profile = self.root / "system"
        self.paths = {}
        for number, stamp in enumerate((10, 20, 900, 1000, 1100, 1200), 1):
            target = self.root / f"gen-{number}"
            target.mkdir()
            self.paths[number] = target
            link = self.root / f"system-{number}-link"
            link.symlink_to(target)
            os.utime(link, (stamp, stamp), follow_symlinks=False)
        self.profile.symlink_to("system-6-link")
        self.backend = SimpleNamespace(name="darwin", system=True, profile=lambda: self.profile,
                                       active=lambda: self.paths[2], validate_user=Mock())
        self.output = io.StringIO()
        redirect = contextlib.redirect_stdout(self.output)
        redirect.__enter__()
        self.addCleanup(redirect.__exit__, None, None, None)

    def ids(self, **policy):
        return [gen.id for gen in cleanup.generation_plan(self.backend, None, **policy)]

    def invoke(self, *arguments):
        self.output.seek(0)
        self.output.truncate()
        with patch.object(cli, "detect", return_value=self.backend):
            code = cli.main(list(arguments))
        return code, json.loads(self.output.getvalue())

    def test_keep_counts_all_generations_and_protects_older_active(self):
        self.assertEqual(self.ids(keep=2), [1, 3, 4])
        self.assertEqual(self.ids(keep=0), [1, 3, 4, 5])
        self.assertEqual(self.ids(keep=100), [])

    def test_age_uses_link_timestamp_strict_boundary_and_intersection(self):
        self.assertEqual(self.ids(cutoff=1000), [1, 3])
        self.assertEqual(self.ids(keep=4, cutoff=1000), [1])
        self.assertEqual(self.ids(cutoff=10), [])

    def test_unknown_age_is_not_eligible_for_age_based_deletion(self):
        unknown = profiles.Generation(1, "unknown", self.paths[1], False, False)
        with patch.object(cleanup, "generations", return_value=[unknown]):
            self.assertEqual(self.ids(cutoff=1000), [])

    def test_oldest_count_selects_only_unprotected_generations(self):
        self.assertEqual([gen.id for gen in cleanup.generation_plan(self.backend, 2)], [1, 3])

    def test_policy_combinations_rejected_before_side_effects(self):
        for extra in (("--keep", "2"), ("--older-than", "30d")):
            args = cli.parser().parse_args(["generation", "gc", "--oldest", "1", *extra])
            with patch.object(cleanup, "run") as run, self.assertRaises(Error):
                cleanup.generation_gc(self.backend, args, Mock())
            run.assert_not_called()

    def test_cutoff_does_not_advance_while_waiting_for_confirmation(self):
        args = cli.parser().parse_args(["generation", "gc", "--older-than", "1h"])
        with patch.object(cleanup.time, "time", return_value=4600) as clock, \
                patch.object(cleanup, "run") as run, patch.object(cleanup, "executable", return_value="nix-env"):
            cleanup.generation_gc(self.backend, args, Mock(return_value=True))
        clock.assert_called_once()
        self.assertEqual(run.call_args.args[0][-2:], ["1", "3"])

    def test_json_cleanup_preview_never_confirms_or_deletes(self):
        args = cli.parser().parse_args(["generation", "gc", "--keep", "2", "--dry-run", "--json"])
        confirm = Mock()
        with patch.object(cleanup, "run") as run:
            cleanup.generation_gc(self.backend, args, confirm)
        confirm.assert_not_called()
        run.assert_not_called()
        data = json.loads(self.output.getvalue())
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["policy"]["keep"], 2)
        self.assertEqual([gen["id"] for gen in data["generations"]], [1, 3, 4])

    def test_json_cleanup_requires_dry_run_even_with_yes(self):
        for command in (["gc"], ["generation", "gc"]):
            with contextlib.redirect_stderr(io.StringIO()), patch.object(cleanup, "dead_paths") as dead:
                code, result = self.invoke(*command, "--json", "--yes")
            self.assertEqual(code, 1)
            self.assertIn("requires --dry-run", result["error"]["message"])
            dead.assert_not_called()

    def test_store_cleanup_json_is_a_single_document(self):
        with patch.object(cleanup, "dead_paths", return_value=["/nix/store/old"]), \
                patch.object(cleanup, "nix_json", return_value={"/nix/store/old": {"narSize": 4096}}), \
                patch.object(cleanup, "nix") as nix:
            code, data = self.invoke("gc", "--dry-run", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(data["paths"], ["/nix/store/old"])
        self.assertEqual(data["sizeEstimate"], {"bytes": 4096, "basis": "nar", "unmeasuredPaths": 0})
        nix.assert_not_called()

    def test_size_estimate_batches_large_plans_without_counting_closures(self):
        paths = [f"/nix/store/path-{number:05}" for number in range(26000)]
        info = {path: {"narSize": 1024, "closureSize": 999999} for path in paths}
        with patch.object(cleanup, "nix_json", return_value=info) as query:
            self.assertEqual(cleanup.estimate_store_size(paths + paths[:2]),
                             {"bytes": 26000 * 1024, "basis": "nar", "unmeasuredPaths": 0})
        query.assert_called_once_with("path-info", "--json", "--json-format", "1", "--stdin",
                                      input="\n".join(paths) + "\n")

    def test_size_estimate_empty_plan_needs_no_query(self):
        with patch.object(cleanup, "nix_json") as query:
            self.assertEqual(cleanup.estimate_store_size([]), {"bytes": 0, "basis": "nar", "unmeasuredPaths": 0})
        query.assert_not_called()

    def test_partial_size_metadata_explicitly_counts_unmeasured_paths(self):
        for info in ({"/a": {"narSize": 12}}, {"/a": {"narSize": 12}, "/b": None},
                     {"/a": {"narSize": 12}, "/b": {"narSize": -1}},
                     {"/a": {"narSize": 12}, "/b": {"narSize": True}},
                     {"/a": {"narSize": 12}, "/not-in-plan": {"narSize": 999999}}):
            with self.subTest(info=info), patch.object(cleanup, "nix_json", return_value=info):
                self.assertEqual(cleanup.estimate_store_size(["/a", "/b"]),
                                 {"bytes": 12, "basis": "nar", "unmeasuredPaths": 1})

    def test_unavailable_size_metadata_is_not_zero(self):
        for info in ({}, {"/a": None}, []):
            with patch.object(cleanup, "nix_json", return_value=info):
                self.assertEqual(cleanup.estimate_store_size(["/a"]),
                                 {"bytes": None, "basis": "nar", "unmeasuredPaths": 1})
        for error in (OSError("missing executable"), ValueError("invalid JSON"),
                      subprocess.CalledProcessError(1, ["nix", "path-info"])):
            with patch.object(cleanup, "nix_json", side_effect=error):
                self.assertIsNone(cleanup.estimate_store_size(["/a"])["bytes"])

    def test_size_estimate_is_shown_before_confirmation(self):
        args = cli.parser().parse_args(["gc"])

        def decline(*args, **kwargs):
            self.assertIn("Estimated space to reclaim: 1.50 GiB (NAR-based estimate).", self.output.getvalue())
            self.assertIn("Estimate excludes 1 path(s) without size metadata.", self.output.getvalue())
            return False

        with patch.object(cleanup, "dead_paths", return_value=["/nix/store/old"]), \
                patch.object(cleanup, "estimate_store_size", return_value={
                    "bytes": 3 * 1024**3 // 2, "basis": "nar", "unmeasuredPaths": 1}), \
                patch.object(cleanup, "nix") as nix:
            cleanup.store_gc(args, decline)
        nix.assert_not_called()

    def test_unavailable_size_is_explicit_in_text_and_json(self):
        with patch.object(cleanup, "dead_paths", return_value=["/nix/store/old"]), \
                patch.object(cleanup, "estimate_store_size", return_value={
                    "bytes": None, "basis": "nar", "unmeasuredPaths": 1}), \
                patch.object(cleanup, "nix") as nix:
            code, data = self.invoke("gc", "--dry-run", "--json")
            self.assertEqual(code, 0)
            self.assertIsNone(data["sizeEstimate"]["bytes"])
            cleanup.store_gc(cli.parser().parse_args(["gc", "--dry-run"]), Mock())
        self.assertIn("Estimated space to reclaim: unavailable", self.output.getvalue())
        nix.assert_not_called()

    def test_status_json_distinguishes_profile_identity_and_provenance(self):
        code, data = self.invoke("status", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(data["active"]["generations"], [2])
        self.assertEqual(data["selected"]["generations"], [6])
        self.assertFalse(data["profileMatchesRunning"])
        self.assertIsNone(data["defaultUpdateSource"])
        self.profile.unlink()
        self.profile.symlink_to("system-2-link")
        _, data = self.invoke("status", "--json")
        self.assertTrue(data["profileMatchesRunning"])
        self.assertIsNone(data["defaultUpdateSource"])

    def test_list_and_info_share_generation_fields(self):
        record = {"schema": 1, "backend": "darwin", "flake": "github:owner/repo#host"}
        (self.paths[2] / "nixman.json").write_text(json.dumps(record))
        _, listing = self.invoke("generation", "list", "--json")
        _, info = self.invoke("generation", "info", "2", "--json")
        self.assertEqual(info["generation"], next(gen for gen in listing["generations"] if gen["id"] == 2))
        self.assertEqual(info["provenance"], record)
        self.assertTrue(info["generation"]["createdAt"].endswith("+00:00"))

    def test_info_prints_only_the_complete_active_record(self):
        record = {"schema": 1, "backend": "darwin", "flake": "github:owner/repo#active",
                  "native": {"homebrew": {"brews": ["vim"]}}, "extra": {"label": "测试"}}
        (self.paths[2] / "nixman.json").write_text(json.dumps(record))
        (self.paths[6] / "nixman.json").write_text(json.dumps({**record, "flake": "selected"}))
        code, result = self.invoke("info")
        self.assertEqual(code, 0)
        self.assertEqual(result, record)
        self.assertEqual(self.output.getvalue(), json.dumps(record, indent=2, ensure_ascii=False) + "\n")
        self.assertEqual(completion.complete(["inf"], cli.parser()), ["info"])

    def test_info_missing_or_invalid_record_leaves_stdout_empty(self):
        for content in (None, "invalid JSON", '{"schema": 2, "flake": "source"}'):
            if content is not None:
                (self.paths[2] / "nixman.json").write_text(content)
            self.output.seek(0)
            self.output.truncate()
            errors = io.StringIO()
            with patch.object(cli, "detect", return_value=self.backend), contextlib.redirect_stderr(errors):
                self.assertEqual(cli.main(["info"]), 1)
            self.assertEqual(self.output.getvalue(), "")
            self.assertIn("nixman", errors.getvalue())

    def test_json_error_is_parseable_and_nonzero(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code, data = self.invoke("generation", "info", "999", "--json")
        self.assertEqual(code, 1)
        self.assertEqual(data["command"], "generation info")
        self.assertIn("does not exist", data["error"]["message"])

    def test_invalid_policy_values_and_removed_backend_are_rejected(self):
        for argv in (["generation", "gc", "--keep", "-1"], ["generation", "gc", "--oldest", "0"],
                     ["generation", "gc", "--older-than", "0d"], ["generation", "gc", "--older-than", "1.5d"],
                     ["generation", "gc", "3"], ["--backend", "darwin", "status"]):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                cli.parser().parse_args(argv)
        self.assertEqual(cli.age_seconds("30d"), 30 * 86400)
        self.assertEqual(cli.age_seconds("2w"), 14 * 86400)

    def test_flake_collection_selects_backend_independently_of_host_os(self):
        names = {"nixos": ["PC"], "darwin": ["Mac"], "home-manager": ["Arch"]}
        for name, host in (("nixos", "PC"), ("darwin", "Mac"), ("home-manager", "Arch")):
            selected, configuration = flake.choose_configuration(names, host)
            self.assertEqual((selected.name, configuration), (name, host))
        with self.assertRaises(Error):
            flake.choose_configuration({"nixos": ["same"], "darwin": ["same"]}, "same")
        with self.assertRaises(Error):
            flake.choose_configuration(names, "missing")

    def test_existing_generation_backend_comes_from_record_or_upstream_marker(self):
        path = self.paths[2]
        (path / "nixos-version").write_text("fixture")
        self.assertEqual(backends.generation_backend(path).name, "nixos")
        (path / "nixman.json").write_text(json.dumps({"schema": 1, "flake": "source", "backend": "home-manager"}))
        self.assertEqual(backends.generation_backend(path).name, "home-manager")

    def test_completion_uses_parser_choices_and_never_runs_commands(self):
        self.assertEqual(completion.complete(["generation", "gc", "--o"], cli.parser()), ["--older-than", "--oldest"])
        self.assertEqual(completion.complete(["completion", ""], cli.parser()), ["bash", "fish", "zsh"])
        self.assertNotIn("--backend", completion.complete(["--"], cli.parser()))
        self.assertEqual(completion.complete(["generation", "gc", "--keep", ""], cli.parser()), [])
        with patch.object(completion, "detect", return_value=self.backend), patch.object(cli, "switch") as switch:
            values = completion.complete(["generation", "diff", "2", ""], cli.parser())
        self.assertEqual(values, ["1", "2", "3", "4", "5", "6"])
        switch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
