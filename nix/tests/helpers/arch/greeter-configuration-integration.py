"""Verify a declared greeter config without taking ownership of package state.

Run only in a disposable Linux system with bubblewrap and user namespaces.
The optional activation script selects the real port's generated manifest; the standalone fixture is for
running this namespace check outside a Nix build.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import shlex
import tomllib
import sys
import tempfile

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    config = root / "declared.toml"
    original = root / "package.toml"
    sync = root / "sync.toml"
    config.write_text('[session]\ndefault = "niri"\n')
    if len(sys.argv) > 1:
        activation = Path(sys.argv[1]).read_text()
        manifest = Path(re.search(r"--files (\S+)", activation)[1])
        files = {item["destination"]: Path(item["source"]) for item in json.loads(manifest.read_text())}
        target = "/etc/greetd/nixconfig-noctalia.toml"
        assert "/var/lib/noctalia-greeter/greeter.toml" not in files
        assert target in files
        dropin = files["/etc/systemd/system/greetd.service.d/nixconfig.conf"].read_text()
        assert "BindReadOnlyPaths" not in dropin
        greetd = tomllib.loads(files["/etc/greetd/nixconfig.toml"].read_text())
        command = shlex.split(greetd["default_session"]["command"])
        assert command[:12] == ["/usr/bin/bwrap", "--die-with-parent", "--bind", "/", "/", "--dev-bind", "/dev", "/dev", "--ro-bind", target, "/var/lib/noctalia-greeter/greeter.toml", "--"]
        assert command[12] == "/usr/bin/noctalia-greeter-session"
        shutil.copyfile(files[target], config)
    original.write_text("package-owned configuration\n")
    sync.write_text("mutable state\n")
    probe = root / "probe.py"
    probe.write_text('''import errno
from pathlib import Path
import sys
original, sync, expected = map(Path, sys.argv[1:])
assert original.read_bytes() == expected.read_bytes()
with open("/dev/null", "wb") as device:
    device.write(b"device access retained")
try:
    original.write_text("must fail")
except OSError as error:
    assert error.errno == errno.EROFS
else:
    raise AssertionError("Declared config was writable")
sync.write_text("user state retained\\n")
''')
    for generation in range(2):
        subprocess.run([
            "bwrap", "--die-with-parent", "--bind", "/", "/", "--dev-bind", "/dev", "/dev", "--ro-bind", str(config), str(original), "--",
            sys.executable, str(probe), str(original), str(sync), str(config),
        ], check=True)
        assert original.read_text() == "package-owned configuration\n"
        assert sync.read_text() == "user state retained\n"
        replacement = root / "next.toml"
        replacement.write_text('[session]\ndefault = "gnome"\n')
        replacement.replace(config)
print("Greeter config namespace, generation replacement and mutable state checks passed")
