"""Reconcile shared native units without owning the native package database.

State is root-owned and records each user's desired units and the changes made
by this helper. Existing enablement and active services belong to the host.
"""

import argparse
import json
import os
from pathlib import Path
import sys
import re
import shutil
import tempfile
import subprocess

# Keep shared filesystem safety in one implementation across ports.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))

from safe_files import read, write, lock


UNIT = re.compile(r"[A-Za-z0-9_@.+:-]+\.(service|socket|timer|path)\Z")


def link_unit(name, target):
    """Identify an installed instance even when its file is a template."""
    unit = Path(target).name
    linked = Path(name).name
    if "@." in unit and "@" in linked:
        unit = unit.replace("@.", "@" + linked.split("@", 1)[1].rsplit(".", 1)[0] + ".", 1)
    return unit


def save(path, state):
    serialized = (json.dumps(state, sort_keys=True) + "\n").encode()
    if read(path) != serialized:
        write(path, serialized)


class Systemd:
    def __init__(self, command="/usr/bin/systemctl", directory="/etc/systemd/system",
                 unshare="/usr/bin/unshare", mount="/usr/bin/mount"):
        self.command = command
        self.directory = Path(directory)
        self.unshare = unshare
        self.mount = mount

    def query(self, *args):
        result = subprocess.run([self.command, *args], text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(f"Cannot query systemd ({' '.join(args)}): {result.stderr.strip()}")
        return result.stdout.strip()

    def enabled(self, unit):
        state = self.query("show", "--property=UnitFileState", "--value", "--", unit)
        if state not in {
            "enabled", "enabled-runtime", "disabled", "indirect", "linked",
            "linked-runtime", "alias", "static", "masked", "masked-runtime",
            "generated", "transient",
        }:
            raise RuntimeError(f"Cannot manage {unit}: unknown unit-file state {state!r}")
        return state

    def active(self, unit):
        state = self.query("show", "--property=ActiveState", "--value", "--", unit)
        if state in {"inactive", "failed"}:
            return False
        if state in {
            "active", "activating", "reloading", "deactivating", "maintenance", "refreshing",
        }:
            return True
        raise RuntimeError(f"Cannot manage {unit}: unknown active state {state!r}")

    # These are systemd's live stop-propagation relations, not package metadata.
    stop_relations = ("RequiredBy", "RequisiteOf", "BoundBy", "ConsistsOf", "PropagatesStopTo")
    keep_relations = ("WantedBy", "UpheldBy", "TriggeredBy")

    def relationships(self, unit):
        properties = ("Id",) + self.stop_relations + self.keep_relations
        values = dict(line.split("=", 1) for line in self.query(
            "show", "--all", "--property=" + ",".join(properties), "--", unit,
        ).splitlines())
        if not all(name in values for name in properties) or not values["Id"]:
            raise RuntimeError(f"Incomplete systemd dependency information for {unit}")
        return (
            values["Id"],
            set(" ".join(values[name] for name in self.stop_relations).split()),
            set(" ".join(values[name] for name in self.keep_relations).split()),
        )

    def referenced(self, unit, retired):
        allowed = {self.relationships(name)[0] for name in retired}
        pending, visited = [unit], set()
        while pending:
            current, propagated, users = self.relationships(pending.pop())
            if current in visited:
                continue
            visited.add(current)
            for consumer in propagated | users:
                canonical = self.relationships(consumer)[0]
                if canonical not in allowed and self.active(canonical):
                    return True
            # An inactive intermediate unit can still propagate a stop job.
            pending.extend(propagated - visited)
        return False

    def enable_plan(self, units, owned):
        if not units:
            return {}
        if self.directory.resolve() != self.directory.absolute():
            raise RuntimeError(f"Refusing symlinked systemd directory: {self.directory}")
        for directory, children, _ in os.walk(self.directory, followlinks=False):
            for child in children:
                path = Path(directory) / child
                if path.is_symlink():
                    raise RuntimeError(f"Refusing symlinked systemd directory: {path}")
        # Let the installed systemd interpret Also=, Alias=, templates and
        # drop-ins. A private mount namespace keeps both PID 1 and host files
        # untouched: systemctl installs its links in the disposable copy.
        with tempfile.TemporaryDirectory(prefix="nixconfig-systemd-") as temporary:
            shadow = Path(temporary) / "system"
            shutil.copytree(self.directory, shadow, symlinks=True)
            snapshot = Systemd(directory=shadow)
            for name, target in owned.items():
                snapshot.remove_link(name, target)
            before = snapshot.links()
            subprocess.run([
                self.unshare, "--mount", "--propagation", "private", "--",
                sys.executable, str(Path(__file__).with_name("systemd-enable-plan.py")),
                self.mount, str(shadow), str(self.directory), self.command, *sorted(units),
            ], check=True)
            return {name: target for name, target in snapshot.links().items()
                    if name not in before}

    def change(self, *args):
        subprocess.run([self.command, *args], check=True)

    def links(self, units=None):
        result = {}
        for directory, _, files in os.walk(self.directory, followlinks=False):
            for name in files:
                path = Path(directory) / name
                if path.is_symlink() and (units is None or link_unit(name, str(path.resolve())) in units):
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
        "version": 2, "owners": {}, "units": {}, "links": {}, "pending": None, "reload": False
    }
    if state["version"] not in {1, 2}:
        raise RuntimeError("Unsupported native-systemd state version")

    for units in state["owners"].values():
        if not isinstance(units, list) or not all(isinstance(u, str) and UNIT.fullmatch(u) for u in units):
            raise ValueError("Invalid native-systemd owner record")
    link_records = [state.get("links", {}), state.get("pending") or {}]
    for unit, record in state["units"].items():
        if not UNIT.fullmatch(unit):
            raise ValueError("Invalid native-systemd unit record")
        link_records.append(record.get("links", {}))
    for links in link_records:
        for name, target in links.items():
            parts = Path(name).parts
            if not parts or Path(name).is_absolute() or ".." in parts or not isinstance(target, str):
                raise ValueError("Invalid native-systemd link record")

    def persist():
        save(state_path, state)

    # Recover the old journal before migrating its evidence. Unknown old
    # effects are deliberately not adopted as our property.
    if state["version"] == 1:
        if state["pending"] is not None:
            state["reload"] = True
            for name, target in systemd.links(state["units"]).items():
                if name not in state["pending"]:
                    unit = link_unit(name, str((systemd.directory / name).resolve()))
                    state["units"][unit]["links"][name] = target
        state["links"] = {
            name: target for record in state["units"].values()
            for name, target in record.pop("links").items()
        }
        state["pending"] = None
        state["version"] = 2

    def finish_enable():
        expected = state["pending"]
        if expected is None:
            return
        actual = systemd.links()
        for name, target in expected.items():
            if actual.get(name) == target:
                state["links"][name] = target
        state["pending"] = None
        persist()

    # Claim only planned, previously absent links, including implicit peers.
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
                "enabled": enabled, "active": systemd.active(unit)
            }
    # Runtime ownership belongs only to explicit requests. Enablement effects
    # have independent ownership, shared by the union of all users' plans.
    plan = systemd.enable_plan(wanted, state["links"])
    peers = {link_unit(name, target) for name, target in plan.items()}
    peers = {unit for unit in peers if UNIT.fullmatch(unit)}
    for unit in sorted(peers - set(state["units"])):
        state["units"][unit] = {
            "enabled": systemd.enabled(unit), "active": systemd.active(unit), "explicit": False,
        }
    for unit in wanted:
        state["units"][unit]["explicit"] = True
    persist()
    for name, target in list(state["links"].items()):
        if plan.get(name) != target:
            state["reload"] = True
            persist()
            systemd.remove_link(name, target)
            del state["links"][name]
            persist()

    actual = systemd.links()
    missing = {name: target for name, target in plan.items() if name not in actual}
    if missing or any(systemd.enabled(unit) != "enabled" for unit in wanted):
        state["pending"] = missing
        # An interrupted --no-reload enable must still reload on its next run.
        state["reload"] = True
        persist()
        try:
            systemd.change("enable", "--no-reload", "--", *sorted(wanted))
        finally:
            finish_enable()
    if state["reload"]:
        systemd.change("daemon-reload")
        state["reload"] = False
        persist()
    for unit in sorted(start_wanted):
        if not systemd.active(unit):
            systemd.change("start", "--", unit)

    retired = sorted(set(state["units"]) - wanted - peers)
    # Retired units may still belong to the host. Only ignore consumers that
    # will actually stop, and propagate protection through the entire graph.
    stoppable = {
        unit for unit in retired
        if state["units"][unit].get("explicit", True)
        and not state["units"][unit]["active"]
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
