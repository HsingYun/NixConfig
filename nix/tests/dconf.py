import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("managed_dconf", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
command = sys.argv[2]
key = "/nixconfig-tests/managed"
other = "/nixconfig-tests/edited"


def read(name):
    return subprocess.check_output([command, "read", name], text=True).strip()


def write(name, value):
    subprocess.run([command, "write", name, value], check=True)


with tempfile.TemporaryDirectory() as tmp:
    state = Path(tmp) / "state.json"
    write(key, "'original'")
    helper.apply({"": {key: '"configured"', other: "true"}}, state, command)
    assert read(key) == "'configured'"
    # Repeat and update retain the original value for later restoration.
    helper.apply({"": {key: '"configured"', other: "true"}}, state, command)
    helper.apply({"": {key: '"updated"', other: "true"}}, state, command)
    write(other, "false")
    helper.apply({}, state, command)
    assert read(key) == "'original'"
    assert read(other) == "false"
    assert json.loads(state.read_text()) == {}
    helper.apply({}, state, command)
    assert read(key) == "'original'"

    # A new key disappears when the last desktop feature is disabled.
    helper.apply({"": {"/nixconfig-tests/new": "@as []"}}, state, command)
    helper.apply({}, state, command)
    assert not read("/nixconfig-tests/new")

    # Named databases participate in the same lifecycle independently.
    helper.apply({"nixconfig_test_db": {key: "42"}}, state, command)
    helper.apply({}, state, command)
    assert read(key) == "'original'"

    # An interrupted update must still restore the original on feature removal.
    helper.apply({"": {key: "'owned-before-failure'"}}, state, command)
    run = helper.subprocess.run
    def fail_write(args, **kwargs):
        if args[1] == "write" and args[-1] == "'failed-update'":
            raise RuntimeError("injected dconf failure")
        return run(args, **kwargs)
    helper.subprocess.run = fail_write
    try:
        try:
            helper.apply({"": {key: "'failed-update'"}}, state, command)
        except RuntimeError:
            pass
        else:
            raise AssertionError("write did not fail")
    finally:
        helper.subprocess.run = run
    helper.apply({}, state, command)
    assert read(key) == "'original'"

    # Adopt a legacy HM generation only while its values still match.
    state.unlink()
    generation = Path(tmp) / "old-generation"
    (generation / "state").mkdir(parents=True)
    (generation / "state/dconf-keys.json").write_text(json.dumps([key, other]))
    ini = Path(sys.argv[3])
    (generation / "activate").write_text(f"dconf load / < {ini}\n")
    write(key, "'legacy'")
    write(other, "false")
    helper.apply({}, state, command, str(generation))
    assert not read(key)
    assert read(other) == "false"
print("dconf lifecycle and legacy migration passed")
