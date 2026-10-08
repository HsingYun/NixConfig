"""Exercise generated desktop files and their launchers without a live session."""
import configparser
import json
from pathlib import Path
import subprocess
import sys


def desktop(path):
    subprocess.run(["desktop-file-validate", path], check=True)
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(path)
    entry = parser["Desktop Entry"]
    assert entry["Type"] == "Application"
    assert entry["Terminal"] == "false"
    assert "OnlyShowIn" not in entry and "NotShowIn" not in entry
    # The Exec line is one store executable, without shell quoting or field codes.
    assert entry["Exec"].startswith("/nix/store/")
    assert not any(c.isspace() or c == "%" for c in entry["Exec"])
    return entry


report = json.loads(Path(sys.argv[1]).read_text())
for case in report["cases"]:
    entry = desktop(case["entry"])
    result = subprocess.run([entry["Exec"]], check=True, capture_output=True, text=True)
    assert json.loads(result.stdout) == {
        "argv": report["arguments"],
        "cwd": "/",
        "env": report["environment"],
    }
    overridden = subprocess.run([desktop(case["override"])["Exec"]], check=True, capture_output=True, text=True)
    assert json.loads(overridden.stdout) == {
        "argv": report["arguments"], "cwd": "/tmp", "env": report["environment"],
    }
    directory = Path(case["directory"])
    assert sorted(p.name for p in directory.iterdir()) == ["nixconfig-autostart-probe.desktop"]
    assert (directory / "nixconfig-autostart-probe.desktop").resolve() == Path(case["entry"]).resolve()

failed = subprocess.run([desktop(report["missingDirectory"])["Exec"]], capture_output=True)
assert failed.returncode != 0 and not failed.stdout
role = subprocess.run([desktop(report["role"])["Exec"]], check=True, capture_output=True, text=True)
assert json.loads(role.stdout) == {"argv": report["arguments"], "cwd": "/", "env": report["environment"]}
for path in report["hostEntries"]:
    desktop(path)
print("Desktop autostart: configuration, argv, environment, working directory and host policies passed")
