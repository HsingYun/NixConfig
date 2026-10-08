"""TTY presentation must not alter JSON, completion or confirmation semantics."""
import contextlib
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from nixman import cli, inspection, preview, terminal


class TTY(io.StringIO):
    def isatty(self):
        return True


class TerminalTests(unittest.TestCase):
    def setUp(self):
        env = patch.dict(terminal.os.environ, {"TERM": "xterm-256color"}, clear=True)
        env.start()
        self.addCleanup(env.stop)

    def test_color_requires_a_terminal_and_respects_no_color(self):
        for environment, expected in (({"TERM": "xterm-256color"}, True),
                                      ({"TERM": "dumb"}, False), ({}, False),
                                      ({"TERM": "xterm", "NO_COLOR": "1"}, False),
                                      ({"TERM": "xterm", "NO_COLOR": "0"}, False),
                                      ({"TERM": "xterm", "NO_COLOR": ""}, True)):
            with self.subTest(environment=environment), patch.dict(terminal.os.environ, environment, clear=True):
                self.assertEqual(terminal.color_enabled(TTY()), expected)
                self.assertFalse(terminal.color_enabled(io.StringIO()))

    def test_stderr_color_does_not_depend_on_stdout(self):
        out, err = io.StringIO(), TTY()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            terminal.emit("Heading", "heading")
            terminal.emit("Error", "error", file=err)
        self.assertEqual(out.getvalue(), "Heading\n")
        self.assertIn("\x1b[31mError\x1b[0m", err.getvalue())

    def test_info_and_json_reports_remain_json_on_a_tty(self):
        record = {"schema": 1, "backend": "darwin", "flake": "source#host"}
        data = inspection.envelope("status", backend="darwin")
        for args, expected in ((["info"], record), (["status", "--json"], data)):
            out = TTY()
            with contextlib.redirect_stdout(out), patch.object(cli, "detect"), \
                    patch.object(cli, "metadata", return_value=record), \
                    patch.object(cli, "status_data", return_value=data):
                self.assertEqual(cli.main(args), 0)
            self.assertNotIn("\x1b", out.getvalue())
            self.assertEqual(json.loads(out.getvalue()), expected)

    def test_completions_are_plain_even_on_a_tty(self):
        out = TTY()
        with contextlib.redirect_stdout(out):
            self.assertEqual(cli.main(["__complete", "inf"]), 0)
        self.assertEqual(out.getvalue(), "info\n")

    def test_plain_and_colored_preview_have_identical_content(self):
        outputs = []
        for out in (io.StringIO(), TTY()):
            with contextlib.redirect_stdout(out), patch.object(preview, "metadata", return_value={
                    "managedFiles": {}, "native": {}}), \
                    patch.object(preview, "nix", return_value="pkg: \x1b[32m1 -> 2\x1b[0m\n"), \
                    patch.object(preview, "configuration_equal", return_value=False):
                preview.preview(SimpleNamespace(system=True), Path("/old"), Path("/new"))
            outputs.append(out.getvalue())
        self.assertNotIn("\x1b", outputs[0])
        self.assertIn("\x1b", outputs[1])
        self.assertEqual(outputs[0], terminal.SGR.sub("", outputs[1]))

    def test_no_color_strips_upstream_diff_colors_on_a_tty(self):
        with contextlib.redirect_stdout(TTY()), patch.dict(terminal.os.environ, {"NO_COLOR": "1"}):
            self.assertEqual(terminal.external("\x1b[31;1mremoved\x1b[0m\n"), "removed\n")
            self.assertEqual(terminal.style("warning", "warning"), "warning")

    def test_colored_confirmation_preserves_default_choices(self):
        with contextlib.redirect_stdout(TTY()), patch.object(cli.sys, "stdin", TTY()):
            with patch("builtins.input", return_value="") as prompt:
                self.assertFalse(cli.confirm(False, destructive=True))
                self.assertIn("[y/N]", prompt.call_args.args[0])
                self.assertIn("\x1b", prompt.call_args.args[0])
            with patch("builtins.input", return_value=""):
                self.assertTrue(cli.confirm(False))


if __name__ == "__main__":
    unittest.main()
