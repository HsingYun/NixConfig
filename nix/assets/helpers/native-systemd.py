"""Reconcile shared native units without owning the native package database.

State is root-owned and records each user's desired units and the changes made
by this helper. Existing enablement and active services belong to the host.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess

from safe_files import read, write, lock


UNIT = re.compile(r"[A-Za-z0-9_@.+:-]+\.(service|socket|timer|path)\Z")


def save(path, state):
    serialized = (json.dumps(state, sort_keys=True) + "\n").encode()
    if read(path) != serialized:
        write(path, serialized)



class Systemd:
    def __init__(self, command="/usr/bin/systemctl", directory="/etc/systemd/system"):
        self.command = command
        self.directory = Path(directory)

    def query(self, *args):
        result = subprocess.run([self.command, *args], text=True, capture_output=True)
        return result.stdout.strip()

    def enabled(self, unit):
        return self.query("is-enabled", unit)

    def active(self, unit):
        return self.query("is-active", unit) in {"active", "activating", "reloading"}

    def referenced(self, unit, retired):
        # Re-evaluate the live reverse graph, rather than encoding dependencies
        # from a particular package version. Foreign active consumers win.
        result = subprocess.run([
            self.command, "show", "--value", "--property=RequiredBy",
            "--property=WantedBy", "--property=BoundBy", "--property=UpheldBy",
            "--property=TriggeredBy", "--", unit,
        ], text=True, capture_output=True)
        if result.returncode:
            print(f"Preserving {unit}: could not inspect active consumers")
            return True
        return any(self.active(name) for name in set(result.stdout.split()) - set(retired))

    def change(self, *args):
        subprocess.run([self.command, *args], check=True)

    def links(self, units=None):
        result = {}
        for directory, _, files in os.walk(self.directory, followlinks=False):
            for name in files:
                path = Path(directory) / name
                if path.is_symlink() and (units is None or path.resolve().name in units):
                    result[str(path.relative_to(self.directory))] = os.readlink(path)
        return result

    def remove_link(self, name, target):
        path = self.directory / name
        # Do not follow a replaced parent directory or delete an edited link.
        if path.parent.resolve() != path.parent.absolute():
            raise RuntimeError(f"Refusing symlinked systemd directory: {path.parent}")
        if path.is_symlink() and os.readlink(path) == target:
            path.unlink()
        elif os.path.lexists(path):
            print(f"Preserving externally changed systemd link: {path}")


def reconcile(state_path, owner, desired, systemd, enable_only=()):
    raw = read(state_path)
    state = json.loads(raw) if raw is not None else {
        "version": 1, "owners": {}, "units": {}, "pending": None, "reload": False
    }
    if state["version"] != 1:
        raise RuntimeError("Unsupported native-systemd state version")

    for units in state["owners"].values():
        if not isinstance(units, list) or not all(isinstance(u, str) and UNIT.fullmatch(u) for u in units):
            raise ValueError("Invalid native-systemd owner record")
    for unit, record in state["units"].items():
        if not UNIT.fullmatch(unit):
            raise ValueError("Invalid native-systemd unit record")
        for name, target in record["links"].items():
            parts = Path(name).parts
            if not parts or Path(name).is_absolute() or ".." in parts or not isinstance(target, str):
                raise ValueError("Invalid native-systemd link record")

    def persist():
        save(state_path, state)

    def finish_enable():
        before = state["pending"]
        if before is None:
            return
        for name, target in systemd.links(state["units"]).items():
            if name not in before:
                unit = (systemd.directory / name).resolve().name
                state["units"][unit]["links"][name] = target
        state["pending"] = None
        persist()

    # The journal precedes enable, so a process killed after creating links can
    # retry without adopting those links as pre-existing host configuration.
    finish_enable()
    state.setdefault("starts", {name: list(units) for name, units in state["owners"].items()})
    start_units = sorted(set(desired))
    desired = sorted(set(desired) | set(enable_only))
    if desired:
        state["owners"][owner] = desired
        state["starts"][owner] = start_units
    else:
        state["owners"].pop(owner, None)
        state["starts"].pop(owner, None)
    start_wanted = {unit for units in state["starts"].values() for unit in units}
    wanted = {unit for units in state["owners"].values() for unit in units}
    for unit in sorted(wanted):
        if unit not in state["units"]:
            enabled = systemd.enabled(unit)
            if enabled not in {"enabled", "enabled-runtime", "disabled", "indirect", "linked", "linked-runtime"}:
                raise RuntimeError(f"Cannot manage {unit}: unit state is {enabled!r}; no automatic unmasking")
            state["units"][unit] = {
                "enabled": enabled, "active": systemd.active(unit), "links": {}
            }
    # Snapshot every unit before enabling any: [Install] Also= may enable peers.
    persist()
    for unit in sorted(wanted):
        if systemd.enabled(unit) != "enabled":
            state["pending"] = systemd.links(state["units"])
            persist()
            try:
                systemd.change("enable", "--", unit)
            finally:
                finish_enable()
        if unit in start_wanted and not systemd.active(unit):
            systemd.change("start", "--", unit)

    retired = sorted(set(state["units"]) - wanted)
    for unit in retired:
        for name, target in state["units"][unit]["links"].items():
            target_unit = Path(target).name
            if target_unit in wanted:
                # A formerly implicit peer is now explicitly required elsewhere.
                state["units"][target_unit]["links"][name] = target
                continue
            # Mark reload before unlinking so interrupted cleanup is retryable.
            state["reload"] = True
            persist()
            systemd.remove_link(name, target)
    if state["reload"]:
        systemd.change("daemon-reload")
        state["reload"] = False
        persist()
    # Retired units may still belong to the host. Only ignore consumers that
    # will actually stop, and propagate protection through the entire graph.
    stoppable = {
        unit for unit in retired
        if not state["units"][unit]["active"]
        and state["units"][unit]["enabled"] not in {"enabled", "enabled-runtime"}
        and not systemd.links([unit]) and systemd.active(unit)
    }
    while True:
        protected = {unit for unit in stoppable if systemd.referenced(unit, stoppable)}
        if not protected:
            break
        stoppable -= protected
    if stoppable:
        # One transaction lets systemd order dependencies (including cycles).
        # Keep every record until the transaction succeeds so failures retry.
        systemd.change("stop", "--", *sorted(stoppable))
    for unit in retired:
        del state["units"][unit]
        persist()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--units", type=Path, required=True)
    parser.add_argument("--state-dir", type=Path, default=Path("/var/lib/nixconfig/native-systemd"))
    args = parser.parse_args()
    manifest = json.loads(args.units.read_text())
    units = manifest if isinstance(manifest, list) else manifest["units"]
    enable_only = [] if isinstance(manifest, list) else manifest.get("enableOnly", [])
    if not isinstance(units, list) or not isinstance(enable_only, list) or not all(isinstance(u, str) and UNIT.fullmatch(u) for u in units + enable_only):
        raise ValueError("Invalid native systemd unit list")
    with lock(args.state_dir / "lock"):
        reconcile(args.state_dir / "state.json", args.owner, units, Systemd(), enable_only)


if __name__ == "__main__":
    main()
