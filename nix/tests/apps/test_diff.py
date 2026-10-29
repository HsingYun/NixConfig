"""Content review remains read-only and cannot implicitly approve activation."""
import argparse
import contextlib
import errno
import io
import json
import os
import hashlib
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from nixman import cli, comparison, diff, preview, runtime


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.old, self.new = self.root / "old", self.root / "new"
        self.old.mkdir(); self.new.mkdir()
        self.backend = SimpleNamespace(system=True)

    def record(self, root, files):
        data = {"schema": 1, "backend": "nixos", "flake": "github:example/config#host", "managedFiles": {}}
        for name, content in files.items():
            source = root / name
            source.write_text(content)
            data["managedFiles"]["/etc/" + name] = str(source)
        (root / "nixman.json").write_text(json.dumps(data))
        return data

    def reports(self, evidence):
        outputs = [io.StringIO(), io.StringIO()]
        for index, output in enumerate(outputs):
            diff.write_report(evidence, index, output)
        return tuple(output.getvalue() for output in outputs)

    def test_reports_contain_changed_added_and_removed_contents(self):
        self.record(self.old, {"changed": "old setting\n", "removed": "old file\n", "same": "unchanged\n"})
        self.record(self.new, {"changed": "new setting\n", "added": "new file\n", "same": "unchanged\n"})
        with patch.object(comparison, "run", side_effect=["shared\nold-package\n", "shared\nnew-package\n"]):
            left, right = self.reports(comparison.compare(self.backend, self.old, self.new))
        self.assertIn("old setting\n", left)
        self.assertIn("new setting\n", right)
        self.assertIn("old file\n", left)
        self.assertIn("new file\n", right)
        self.assertNotIn("unchanged", left + right)
        self.assertIn("old-package", left)
        self.assertIn("new-package", right)
        self.assertNotIn("shared", left + right)

    def test_legacy_and_first_generation_contents(self):
        (self.new / "etc").mkdir()
        (self.new / "etc/config").write_text("new value\n")
        with patch.object(comparison, "run", return_value="new-package\n"):
            left, right = self.reports(comparison.compare(self.backend, None, self.new))
        self.assertIn("[Not present in this generation]", left)
        self.assertIn("new value", right)
        self.assertIn("declarations may be unavailable", right)

    def test_directory_inventory_retains_file_sources(self):
        directory = self.new / "settings"
        directory.mkdir()
        (directory / "config").write_text("setting\n")
        data = {"managedFiles": {"/etc/settings": str(directory)}}
        entries = comparison.StoredFiles(self.new).declared(data)
        self.assertEqual(entries["/etc/settings/config"].source, directory / "config")
        self.assertEqual(set(entries), {"/etc/settings/config"})

    def update_chain(self, answers, *, dry_run=False, yes=False, editor_error=None):
        """Only replace external commands; run update through real report creation."""
        backend = Mock(system=True, name="nixos", command="nixos-rebuild")
        backend.name = "nixos"
        backend.active.side_effect = [self.old, self.new]
        args = argparse.Namespace(flake="path:/test#host", dry_run=dry_run, yes=yes)
        viewed = []
        report_paths = []
        def editor(command):
            report_paths.extend(command[-2:])
            viewed.append(tuple(path.read_text() for path in command[-2:]))
            if editor_error:
                raise editor_error
        with contextlib.ExitStack() as stack:
            output, errors = io.StringIO(), io.StringIO()
            stack.enter_context(contextlib.redirect_stdout(output))
            stack.enter_context(contextlib.redirect_stderr(errors))
            stack.enter_context(patch.object(cli, "prepare", return_value=(backend, self.root / "wrapper", {"flake": args.flake})))
            stack.enter_context(patch.object(cli, "build", return_value=self.new))
            stack.enter_context(patch.object(cli, "fingerprint", return_value=("unchanged",)))
            stack.enter_context(patch.object(cli, "executable", return_value="/tool"))
            stack.enter_context(patch.object(cli.sys.stdin, "isatty", return_value=True))
            stack.enter_context(patch.object(cli.sys.stdout, "isatty", return_value=True))
            stack.enter_context(patch("builtins.input", side_effect=answers))
            stack.enter_context(patch.object(comparison, "run", return_value="shared-package\n"))
            stack.enter_context(patch.object(preview, "nix", return_value="closure changes\n"))
            stack.enter_context(patch.object(diff.shutil, "which", return_value="/test/vimdiff"))
            stack.enter_context(patch.object(diff, "run", side_effect=editor))
            # Wrap rather than replace either consumer or the comparison builder.
            collected = stack.enter_context(patch.object(cli, "compare", wraps=comparison.compare))
            summary = stack.enter_context(patch.object(cli, "preview", wraps=preview.preview))
            viewer = stack.enter_context(patch.object(cli, "view_diff", wraps=diff.view_diff))
            cli.update(args)
            collected.assert_called_once()
            if viewed:
                evidence = summary.call_args.args[0]
                self.assertTrue(all(call.args[0] is evidence for call in viewer.call_args_list))
        self.assertTrue(all(not path.exists() for path in report_paths))
        return backend, output.getvalue(), errors.getvalue(), viewed

    def test_scan_failures_abort_update_before_confirmation(self):
        for root in (self.old, self.new):
            (root / "etc/nested").mkdir(parents=True)
            (root / "etc/nested/config").write_text(root.name)
        original_scandir = os.scandir
        for inventory in ("declared", "legacy", "payload"):
            for operation in ("scandir", "stat"):
                for suffix in ("etc", "etc/nested"):
                    with self.subTest(inventory=inventory, directory=suffix, operation=operation):
                        for root in (self.old, self.new):
                            record = root / "nixman.json"
                            if inventory == "legacy":
                                record.unlink(missing_ok=True)
                            else:
                                data = self.record(root, {})
                                if inventory == "declared":
                                    data["managedFiles"]["/etc/settings"] = str(root / "etc")
                                record.write_text(json.dumps(data))
                        blocked = self.new / suffix
                        def denied(path):
                            if not isinstance(path, int) and Path(path) == blocked:
                                raise PermissionError(errno.EACCES, "Permission denied", str(path))
                            return original_scandir(path)
                        original_stat, original_lstat = Path.stat, Path.lstat
                        def denied_stat(path, *args, **kwargs):
                            if path == blocked:
                                raise PermissionError(errno.EACCES, "Permission denied", str(path))
                            return original_stat(path, *args, **kwargs)
                        def denied_lstat(path, *args, **kwargs):
                            if path == blocked:
                                raise PermissionError(errno.EACCES, "Permission denied", str(path))
                            return original_lstat(path, *args, **kwargs)
                        backend = Mock(system=True, command="nixos-rebuild")
                        backend.name = "nixos"
                        backend.active.return_value = self.old
                        output, errors = io.StringIO(), io.StringIO()
                        with contextlib.ExitStack() as stack:
                            stack.enter_context(contextlib.redirect_stdout(output))
                            stack.enter_context(contextlib.redirect_stderr(errors))
                            stack.enter_context(patch.object(cli, "prepare", return_value=(backend, self.root / "wrapper", {"flake": "path:/test#host"})))
                            stack.enter_context(patch.object(cli, "build", return_value=self.new))
                            stack.enter_context(patch.object(cli, "fingerprint", return_value=("unchanged",)))
                            stack.enter_context(patch.object(cli, "executable", return_value="/tool"))
                            stack.enter_context(patch.object(comparison, "run", return_value="shared-package\n"))
                            stack.enter_context(patch.object(preview, "nix", return_value=""))
                            if operation == "scandir":
                                stack.enter_context(patch.object(os, "scandir", denied))
                            else:
                                stack.enter_context(patch.object(Path, "stat", denied_stat))
                                stack.enter_context(patch.object(Path, "lstat", denied_lstat))
                            prompt = stack.enter_context(patch("builtins.input"))
                            self.assertEqual(cli.main(["update", "path:/test#host"]), 1)
                        prompt.assert_not_called()
                        backend.update.assert_not_called()
                        if operation == "scandir":
                            self.assertIn("Could not scan configuration directory", errors.getvalue())
                        self.assertIn(str(blocked), errors.getvalue())
                        self.assertIn("Permission denied", errors.getvalue())
                        self.assertNotIn("No configuration changes detected", output.getvalue())

    def test_tree_distinguishes_missing_directory_from_stat_failure(self):
        reader = comparison.StoredFiles(self.new)
        root = self.new / "missing"
        self.assertEqual(reader.tree(root), {})
        original_stat = Path.stat
        def denied(path, *args, **kwargs):
            if path == root:
                raise PermissionError(errno.EACCES, "Permission denied", str(path))
            return original_stat(path, *args, **kwargs)
        with patch.object(Path, "stat", denied):
            with self.assertRaisesRegex(runtime.Error, "Could not scan configuration directory"):
                reader.tree(root)

    def test_viewer_writes_each_content_before_reading_the_next(self):
        self.record(self.old, {})
        self.record(self.new, {f"config-{index:02}": f"setting-{index}\n" * 4096 for index in range(24)})
        original_open = Path.open
        original_text = comparison.StoredFiles.text
        pending = None
        content_writes = 0
        def read_content(reader, entry):
            nonlocal pending
            self.assertIsNone(pending, "Previous file contents were buffered instead of written")
            pending = original_text(reader, entry)
            return pending
        @contextlib.contextmanager
        def open_output(path, mode="r", *args, **kwargs):
            nonlocal pending, content_writes
            with original_open(path, mode, *args, **kwargs) as stream:
                if mode == "w" and path.name in ("baseline.txt", "candidate.txt"):
                    def write(text):
                        nonlocal pending, content_writes
                        if pending is not None:
                            self.assertEqual(text, pending)
                            pending = None
                            content_writes += 1
                        return stream.write(text)
                    yield SimpleNamespace(write=write)
                else:
                    yield stream
        with patch.object(Path, "open", open_output), patch.object(comparison.StoredFiles, "text", read_content):
            backend, _, errors, viewed = self.update_chain(["v", "n"])
        self.assertFalse(errors)
        self.assertEqual(content_writes, 24)
        self.assertIsNone(pending)
        self.assertIn("setting-23", viewed[0][1])
        backend.update.assert_not_called()

    def test_report_write_failure_cleans_up_and_returns_to_confirmation(self):
        self.record(self.old, {})
        self.record(self.new, {"config": "new\n"})
        paths = []
        original_open = Path.open
        @contextlib.contextmanager
        def fail_output(path, mode="r", *args, **kwargs):
            with original_open(path, mode, *args, **kwargs) as stream:
                if mode == "w" and path.name in ("baseline.txt", "candidate.txt"):
                    paths.append(path)
                    def write(text):
                        if "new\n" == text:
                            raise OSError(errno.ENOSPC, "No space left on device", str(path))
                        return stream.write(text)
                    yield SimpleNamespace(write=write)
                else:
                    yield stream
        with patch.object(Path, "open", fail_output):
            backend, _, errors, viewed = self.update_chain(["v", "n"])
        self.assertIn("No space left on device", errors)
        self.assertFalse(viewed)
        self.assertEqual(len(paths), 2)
        self.assertTrue(all(not path.exists() for path in paths))
        backend.update.assert_not_called()

    def test_update_chain_never_reads_or_traverses_external_sources(self):
        live = self.root / "live"
        live.mkdir()
        secret = live / "secret"
        secret.write_text("live secret must not be read")
        for generation in (self.old, self.new):
            data = self.record(generation, {"config": generation.name + " setting\n"})
            (generation / "external-link").symlink_to(secret)
            (generation / "external-dir").symlink_to(live, target_is_directory=True)
            nested = generation / "nested"
            nested.mkdir()
            (nested / "link").symlink_to(secret)
            (nested / "directory").symlink_to(live, target_is_directory=True)
            data["managedFiles"].update({
                "/etc/live-" + generation.name: str(secret),
                "/etc/live-dir-" + generation.name: str(live),
                "/etc/link": str(generation / "external-link"),
                "/etc/directory": str(generation / "external-dir"),
                "/etc/nested-" + generation.name: str(nested),
            })
            (generation / "nixman.json").write_text(json.dumps(data))
        original_open, original_scandir = Path.open, os.scandir
        def checked_open(path, *args, **kwargs):
            self.assertFalse(path.resolve().is_relative_to(live), f"Read live file: {path}")
            return original_open(path, *args, **kwargs)
        def checked_scandir(path):
            if not isinstance(path, int):  # tempfile cleanup uses directory descriptors.
                self.assertFalse(Path(path).resolve().is_relative_to(live), f"Traversed live directory: {path}")
            return original_scandir(path)
        with patch.object(Path, "open", checked_open), patch.object(os, "scandir", checked_scandir):
            backend, output, errors, viewed = self.update_chain(["v", "v", "n"])
        backend.update.assert_not_called()
        self.assertFalse(errors)
        self.assertEqual(len(viewed), 2)
        self.assertEqual(viewed[0], viewed[1])
        self.assertIn("External source", "".join(viewed[0]))
        self.assertIn("/etc/live-new", output)
        self.assertNotIn("live secret must not be read", output + "".join(viewed[0]))

    def test_update_chain_bounds_reads_and_reports_binary_large_and_missing_files(self):
        self.record(self.old, {})
        data = self.record(self.new, {"binary": "\0binary", "large": "x" * (comparison.MAX_CONTENT_BYTES + 1)})
        data["managedFiles"]["/etc/missing"] = str(self.new / "missing")
        (self.new / "nixman.json").write_text(json.dumps(data))
        large = self.new / "large"
        original_open = Path.open
        reads = []
        @contextlib.contextmanager
        def checked_open(path, *args, **kwargs):
            with original_open(path, *args, **kwargs) as stream:
                if path == large:
                    def read(size=-1):
                        self.assertGreater(size, 0, "Unbounded read")
                        self.assertLessEqual(size, comparison.MAX_CONTENT_BYTES + 1)
                        reads.append(size)
                        return stream.read(size)
                    yield SimpleNamespace(read=read)
                else:
                    yield stream
        with patch.object(Path, "open", checked_open):
            backend, _, errors, viewed = self.update_chain(["v", "n"])
        backend.update.assert_not_called()
        self.assertFalse(errors)
        self.assertIn(comparison.READ_CHUNK_BYTES, reads)
        self.assertIn(comparison.MAX_CONTENT_BYTES + 1, reads)
        text = "".join(viewed[0])
        for marker in ("Binary file", "Content omitted", "unavailable"):
            self.assertIn(marker, text)
        self.assertNotIn("x" * 100, text)

    def test_update_chain_review_then_explicit_approval_activates_candidate(self):
        self.record(self.old, {"config": "old\n"})
        self.record(self.new, {"config": "new\n"})
        backend, output, errors, viewed = self.update_chain(["v", "y"])
        self.assertFalse(errors)
        self.assertEqual(len(viewed), 1)
        self.assertIn("~ /etc/config", output)
        self.assertIn("old\n", viewed[0][0])
        self.assertIn("new\n", viewed[0][1])
        backend.update.assert_called_once_with(self.root / "wrapper")

    def test_update_chain_failed_editor_then_eof_cancels(self):
        self.record(self.old, {})
        self.record(self.new, {"config": "new\n"})
        backend, _, errors, viewed = self.update_chain(
            ["v", EOFError()], editor_error=subprocess.CalledProcessError(1, ["vimdiff"]))
        backend.update.assert_not_called()
        self.assertIn("Could not open diff", errors)
        self.assertEqual(len(viewed), 1)

    def test_update_chain_dry_run_and_yes_do_not_open_viewer(self):
        self.record(self.old, {})
        self.record(self.new, {"config": "new\n"})
        for dry_run, yes in ((True, False), (False, True)):
            with self.subTest(dry_run=dry_run):
                backend, output, errors, viewed = self.update_chain([], dry_run=dry_run, yes=yes)
                self.assertFalse(errors)
                self.assertFalse(viewed)
                self.assertIn("+ /etc/config", output)
                self.assertEqual(backend.update.call_count, 0 if dry_run else 1)

    def test_legacy_home_manager_tree_does_not_follow_external_root(self):
        live = self.root / "live-home"
        live.mkdir()
        (live / "private").write_text("private live value")
        (self.old / "home-files").symlink_to(live, target_is_directory=True)
        (self.new / "home-files").mkdir()
        (self.new / "home-files/config").write_text("new config\n")
        original_scandir = os.scandir
        def guarded(path):
            self.assertNotEqual(Path(path).resolve(), live)
            return original_scandir(path)
        with patch.object(os, "scandir", guarded), patch.object(comparison, "run", return_value=""):
            evidence = comparison.compare(SimpleNamespace(system=False), self.old, self.new)
            left, right = self.reports(evidence)
        self.assertIn("External source", left)
        self.assertIn("new config", right)
        self.assertNotIn("private live value", left + right)

    def test_store_links_are_read_and_modes_are_compared(self):
        store = self.root / "store"
        store.mkdir()
        file = store / "config"
        file.write_text("stored config\n")
        for generation in (self.old, self.new):
            self.record(generation, {})
            (generation / "stored").symlink_to(file)
        data = json.loads((self.new / "nixman.json").read_text())
        data["managedFiles"]["/etc/stored"] = str(self.new / "stored")
        (self.new / "nixman.json").write_text(json.dumps(data))
        with patch.dict(os.environ, {"NIX_STORE_DIR": str(store)}), patch.object(comparison, "run", return_value=""):
            evidence = comparison.compare(self.backend, self.old, self.new)
            _, right = self.reports(evidence)
        self.assertIn("stored config", right)
        file_old, file_new = self.old / "config", self.new / "config"
        file_old.write_text("same"); file_new.write_text("same")
        file_old.chmod(0o644); file_new.chmod(0o755)
        self.assertNotEqual(comparison.StoredFiles(self.old).entry(file_old), comparison.StoredFiles(self.new).entry(file_new))

    def test_generation_normalisation_streams_across_chunk_boundaries(self):
        file = self.new / "activate"
        content = ("before " + str(self.new) + " after " + str(self.new)).encode()
        file.write_bytes(content)
        reader = comparison.StoredFiles(self.new)
        for chunk_size in (1, 7, len(str(self.new)) - 1, len(content)):
            with self.subTest(chunk_size=chunk_size), patch.object(comparison, "READ_CHUNK_BYTES", chunk_size):
                entry = reader.entry(file, normalise=self.new)
                self.assertEqual(entry.identity[1], hashlib.sha256(content.replace(os.fsencode(self.new), b"<generation>")).hexdigest())

    def test_external_metadata_is_rejected_before_reading(self):
        external = self.root / "external.json"
        external.write_text("not metadata")
        (self.new / "nixman.json").symlink_to(external)
        with patch.object(Path, "open", side_effect=AssertionError("Must not read external metadata")):
            with self.assertRaisesRegex(runtime.Error, "metadata points outside"):
                comparison.compare(self.backend, self.old, self.new)

    def test_viewer_is_read_only_and_removes_temporary_reports(self):
        paths = []
        def editor(args):
            self.assertEqual(args[0], "/test/vimdiff")
            for flag in ("-R", "-n", "--noplugin", "set nomodeline", "windo setlocal nomodifiable"):
                self.assertIn(flag, args)
            paths.extend(args[-2:])
            self.assertEqual([path.read_text() for path in paths], ["left", "right"])
            self.assertTrue(all(path.stat().st_mode & 0o222 == 0 for path in paths))
            raise subprocess.CalledProcessError(1, args)
        with patch.object(diff.sys.stdin, "isatty", return_value=True), \
                patch.object(diff.sys.stdout, "isatty", return_value=True), \
                patch.object(diff.shutil, "which", return_value="/test/vimdiff"), \
                patch.object(diff, "write_report", side_effect=lambda evidence, index, output: output.write(("left", "right")[index])), \
                patch.object(diff, "run", side_effect=editor):
            with self.assertRaises(subprocess.CalledProcessError):
                diff.view_diff(comparison.compare(self.backend, self.old, self.new))
        self.assertTrue(paths)
        self.assertTrue(all(not path.exists() for path in paths))

    def test_viewer_falls_back_to_vim_diff_mode(self):
        with patch.object(diff.sys.stdin, "isatty", return_value=True), \
                patch.object(diff.sys.stdout, "isatty", return_value=True), \
                patch.object(diff.shutil, "which", side_effect=[None, "/test/vim"]), \
                patch.object(diff, "write_report", side_effect=lambda evidence, index, output: output.write(("left", "right")[index])), \
                patch.object(diff, "run") as run:
            diff.view_diff(comparison.compare(self.backend, self.old, self.new))
        self.assertEqual(run.call_args.args[0][:2], ["/test/vim", "-d"])

    def test_missing_editor_does_not_build_reports(self):
        with patch.object(diff.sys.stdin, "isatty", return_value=True), \
                patch.object(diff.sys.stdout, "isatty", return_value=True), \
                patch.object(diff.shutil, "which", return_value=None), \
                patch.object(diff, "write_report") as reports:
            with self.assertRaisesRegex(runtime.Error, "Install Vim"):
                diff.view_diff(comparison.compare(self.backend, self.old, self.new))
        reports.assert_not_called()

    def test_view_returns_to_confirmation_without_approving(self):
        viewer = Mock()
        with patch.object(cli.sys.stdin, "isatty", return_value=True), \
                patch("builtins.input", side_effect=["v", "view diff", "n"]) as prompt:
            self.assertFalse(cli.confirm(False, view_diff=viewer))
        self.assertEqual(viewer.call_count, 2)
        self.assertIn("View Diff", prompt.call_args.args[0])

    def test_failed_viewer_still_requires_confirmation(self):
        viewer = Mock(side_effect=runtime.Error("missing editor"))
        with patch.object(cli.sys.stdin, "isatty", return_value=True), \
                patch("builtins.input", side_effect=["v", "n"]), \
                contextlib.redirect_stderr(io.StringIO()) as errors:
            self.assertFalse(cli.confirm(False, view_diff=viewer))
        self.assertIn("missing editor", errors.getvalue())

    def test_view_then_default_yes_and_noninteractive_yes(self):
        viewer = Mock()
        with patch.object(cli.sys.stdin, "isatty", return_value=True), \
                patch("builtins.input", side_effect=["v", ""]):
            self.assertTrue(cli.confirm(False, no_changes=True, view_diff=viewer))
        viewer.assert_called_once()
        viewer.reset_mock()
        with patch.object(cli.sys.stdin, "isatty", return_value=False):
            self.assertTrue(cli.confirm(True, view_diff=viewer))
            with self.assertRaises(runtime.Error):
                cli.confirm(False, view_diff=viewer)
        viewer.assert_not_called()


if __name__ == "__main__":
    unittest.main()
