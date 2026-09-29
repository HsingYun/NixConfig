"""One-time settings initialization must leave user files and later edits intact."""

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

import json5

sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("seed", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
defaults = {"editor.fontFamily": "Maple Mono NF CN", "terminal.integrated.fontFamily": "Maple Mono NF CN"}

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp).resolve()
    def scenario(name, text=None):
        directory = root / name
        directory.mkdir()
        settings, marker = directory / "settings.json", directory / "done"
        if text is not None:
            settings.write_text(text)
        return settings, marker

    settings, marker = scenario("new")
    helper.seed(settings, marker, defaults)
    assert json.loads(settings.read_text()) == defaults
    settings.write_text('{"editor.fontFamily": "User font"}')
    helper.seed(settings, marker, defaults)
    assert json.loads(settings.read_text()) == {"editor.fontFamily": "User font"}
    settings.unlink()
    helper.seed(settings, marker, defaults)
    assert not settings.exists()

    text = '\ufeff// header\n{\n  // user preference\n  "editor.fontFamily": "Other",\n  "other": {"value": "//literal"},\n}\n'
    settings, marker = scenario("existing", text)
    helper.seed(settings, marker, defaults)
    result = settings.read_text()
    assert result.startswith('\ufeff// header\n{')
    assert text[text.index("{") + 1:] in result
    assert json5.loads(result.lstrip('\ufeff')) == {
        **defaults, "editor.fontFamily": "Other", "other": {"value": "//literal"}
    }

    for name, text in [("empty", "{/* comment */}"), ("prefix", "/* { } */\n{}")]:
        settings, marker = scenario(name, text)
        helper.seed(settings, marker, defaults)
        assert json5.loads(settings.read_text()) == defaults

    for name, text in [("invalid", "{ unfinished"), ("array", "[]"),
                       ("already-set", json.dumps(defaults))]:
        settings, marker = scenario(name, text)
        before = settings.stat().st_mtime_ns
        helper.seed(settings, marker, defaults)
        assert settings.read_text() == text
        assert settings.stat().st_mtime_ns == before
        assert marker.exists()

    settings, marker = scenario("symlink")
    target = root / "target.json"
    target.write_text("{}")
    settings.symlink_to(target)
    helper.seed(settings, marker, defaults)
    assert settings.is_symlink() and target.read_text() == "{}"

    settings, marker = scenario("concurrent", "{}")
    original_write = helper.write
    def race(path, content, **kwargs):
        if path == settings:
            settings.write_text('{"user": "concurrent edit"}')
        return original_write(path, content, **kwargs)
    with patch.object(helper, "write", side_effect=race):
        try:
            helper.seed(settings, marker, defaults)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Concurrent edit overwritten")
    assert json.loads(settings.read_text()) == {"user": "concurrent edit"}
    assert not marker.exists()

print("One-time JSONC settings initialization passed")
