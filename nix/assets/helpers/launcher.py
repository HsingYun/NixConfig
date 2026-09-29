"""Maintain native desktop-entry overrides without claiming unrelated user files."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from safe_files import read, write, remove, lock


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid(name):
    return re.fullmatch(r"[A-Za-z0-9_.+-]+\.desktop", name) is not None


def reconcile(rules, data, state, installer, dry_run=False):
    applications = Path(data) / "applications"
    manifest = Path(state) / "nixconfig/hidden-desktop-entries.json"
    raw = read(manifest)
    previous = json.loads(raw) if raw is not None else {}
    if not isinstance(previous, dict):
        raise ValueError("Invalid desktop-entry manifest")
    # Validate the destination directory even when no entries currently exist.
    read(applications / ".nixconfig-path-check")
    owned = {}
    for name, checksum in previous.items():
        target = applications / name
        if not valid(name) or target.is_symlink():
            continue
        content = read(target)
        if content is None:
            continue
        # Keep the hash we validated, never adopt a second read as ownership.
        actual = hashlib.sha256(content).hexdigest()
        if actual in (checksum if isinstance(checksum, list) else [checksum]):
            owned[name] = actual
    desired = {}
    for name in rules["hiddenEntries"]:
        if not valid(name):
            raise ValueError(f"Invalid desktop entry: {name}")
        for root in rules["nativeRoots"]:
            source = Path(root) / "share/applications" / name
            if source.is_file():
                desired[name] = source
                break
    if dry_run:
        print(f"Would reconcile native desktop overrides: {sorted(desired)}")
        return
    for name in owned.keys() - desired.keys():
        target = applications / name
        current = read(target)
        if current is None:
            continue
        if hashlib.sha256(current).hexdigest() != owned[name]:
            raise RuntimeError(f"Desktop entry changed during cleanup: {target}")
        remove(target, current)
    current = {}
    for name, source in desired.items():
        target = applications / name
        if name not in owned and os.path.lexists(target):
            # Home Manager's Nix profile overrides have higher precedence too.
            print(f"Preserving existing desktop entry: {target}")
            continue
        applications.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=applications) as tmp:
            subprocess.run([
                installer, f"--dir={tmp}", "--set-key=NoDisplay",
                "--set-value=true", str(source),
            ], check=True)
            generated = Path(tmp) / name
            before = read(target)
            if before is not None and (name not in owned or hashlib.sha256(before).hexdigest() != owned[name]):
                raise RuntimeError(f"Desktop entry changed during activation: {target}")
            current[name] = digest(generated)
            if name not in owned or current[name] != owned[name]:
                # Journal each entry before replacement; a failed later entry must
                # not strand an untracked file or lose ownership of earlier writes.
                previous[name] = list(set([current[name]] + ([owned[name]] if name in owned else [])))
                write(manifest, json.dumps(previous, sort_keys=True))
                write(target, generated.read_bytes(), mode=0o644, expected=before)
    if current or manifest.exists():
        write(manifest, json.dumps(current, sort_keys=True))


def apply(rules, data, state, installer, dry_run=False):
    if dry_run:
        return reconcile(rules, data, state, installer, True)
    manifest = Path(state) / "nixconfig/hidden-desktop-entries.json"
    if not rules["hiddenEntries"] and read(manifest) is None:
        return
    with lock(str(manifest) + ".lock"):
        return reconcile(rules, data, state, installer)



if __name__ == "__main__":
    apply(json.loads(Path(sys.argv[1]).read_text()), *sys.argv[2:5],
          dry_run=bool(os.environ.get("DRY_RUN_CMD")))
