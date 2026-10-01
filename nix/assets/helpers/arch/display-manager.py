"""Select an owned login manager for the next boot, without ending a session."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import subprocess

# Keep shared filesystem safety in one implementation across ports.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))

from safe_files import lock, read, write

_spec = importlib.util.spec_from_file_location("owned_file", Path(__file__).resolve().parents[1] / "common" / "owned-file.py")
owned_file = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(owned_file)
MANAGERS = {"gdm.service", "greetd.service"}


class Systemd:
    def __init__(self, command, alias):
        self.command, self.alias = command, Path(alias)

    def current(self):
        if self.alias.exists() and not self.alias.is_symlink():
            raise RuntimeError("Refusing unmanaged display-manager file")
        return self.alias.resolve().name if self.alias.is_symlink() else ""

    def enabled(self, unit):
        result = subprocess.run([self.command, "show", "--property=LoadState,UnitFileState", "--", unit],
                                text=True, capture_output=True, check=True)
        state = dict(line.split("=", 1) for line in result.stdout.splitlines())
        if state.get("LoadState") == "not-found":
            return "not-found"
        value = state.get("UnitFileState")
        if value not in {"enabled", "enabled-runtime", "disabled", "static", "indirect", "linked", "linked-runtime", "masked", "masked-runtime"}:
            raise RuntimeError(f"Cannot inspect display-manager unit {unit}: {state}")
        return value

    def default_target(self):
        return subprocess.check_output([self.command, "get-default"], text=True).strip()

    def change(self, *args):
        subprocess.run([self.command, *args], check=True)


def reconcile(state_path, owner, service, files, systemd):
    raw = read(state_path)
    if raw is None and service is None:
        return
    state = json.loads(raw) if raw is not None else {
        "version": 2, "owners": {}, "managed": [], "files": {}, "reload": False,
        "original": None, "retiring": False,
    }
    if state.get("version") not in {1, 2} or not set(state["managed"]) <= MANAGERS:
        raise ValueError("Invalid display-manager state")
    if state["version"] == 1:
        # Old records did not distinguish adopted from newly enabled managers.
        state.update(version=2, original={"known": False} if state["managed"] else None, retiring=False)
    if service is not None and service not in MANAGERS:
        raise ValueError("Unsupported display manager")
    owners = dict(state["owners"])
    if service is None:
        owners.pop(owner, None)
    else:
        owners[owner] = service
    if len(set(owners.values())) > 1:
        raise RuntimeError("Conflicting display-manager owners")
    desired = next(iter(owners.values()), None)
    original = state.get("original")
    if not desired and state["managed"] and original and not original.get("known"):
        raise RuntimeError("Cannot retire the legacy login manager: its original state was not recorded. Keep a desktop selected until the boot manager is explicitly migrated.")
    current = systemd.current()
    if desired and current not in MANAGERS | {"", "display-manager.service"}:
        raise RuntimeError(f"Refusing unsupported display manager: {current}")
    # Resolve query failures before writing files or changing enablement.
    enabled = {unit: systemd.enabled(unit) for unit in MANAGERS}
    default_target = systemd.default_target() if desired or original else None
    if desired and original is None:
        state["original"] = original = {
            "known": True,
            "service": current if current in MANAGERS and enabled[current] in {"enabled", "enabled-runtime"} else None,
            "target": default_target,
        }
    if original and original.get("known") and (
        original.get("service") not in MANAGERS | {None}
        or not isinstance(original.get("target"), str)
        or not original["target"].endswith(".target")
    ):
        raise ValueError("Invalid original display-manager state")
    state["owners"] = owners
    previous_files = dict(state["files"].get(owner, {}))
    requested = {item["destination"]: item for item in files} if service else {}
    records = state["files"].setdefault(owner, {})

    def persist():
        write(state_path, json.dumps(state, sort_keys=True) + "\n")

    # Record intent before effects so interrupted activation can be retried or
    # retired. File content/identity ownership remains with the shared helper.
    if desired and desired not in state["managed"]:
        state["managed"].append(desired)
    if desired:
        state["retiring"] = False
    persist()
    for destination, item in requested.items():
        file_state = item.get("stateFile", "/var/lib/nixconfig/files/" +
                              hashlib.sha256(destination.encode()).hexdigest() + ".json")
        records[destination] = file_state
        if read(destination) != read(item["source"]):
            state["reload"] = True
        persist()
        owned_file.reconcile(destination, file_state, item["source"], owner)
    if state["reload"]:
        systemd.change("daemon-reload")
        state["reload"] = False
        persist()
    if desired:
        if current != desired or enabled[desired] != "enabled":
            systemd.change("enable", "--force", desired)
        for other in sorted(MANAGERS - {desired}):
            if enabled[other] in {"enabled", "enabled-runtime"}:
                systemd.change("disable", "--", other)
        if default_target != "graphical.target":
            systemd.change("set-default", "graphical.target")
    elif original and original.get("known") and (
        current in state["managed"] or state.get("retiring") and current == (original["service"] or "")
    ):
        # Journal restoration before touching the alias: interruption after
        # enabling the original manager must still retire the replacement.
        state["retiring"] = True
        persist()
        restored = original["service"]
        if restored:
            if enabled[restored] == "not-found":
                raise RuntimeError(f"Original login manager is unavailable: {restored}")
            if current != restored or enabled[restored] != "enabled":
                systemd.change("enable", "--force", restored)
        for other in state["managed"]:
            if other != restored and enabled[other] in {"enabled", "enabled-runtime"}:
                systemd.change("disable", "--", other)
        # Restore only the default target this backend changed. Keep external edits.
        if default_target == "graphical.target" and original["target"] != default_target:
            systemd.change("set-default", original["target"])
    # Retire owned configuration even when the feature's final consumer goes
    # away. Keep foreign edits as an actionable conflict, never overwrite them.
    for destination, file_state in previous_files.items():
        if destination not in requested:
            state["reload"] = True
            persist()
            owned_file.reconcile(destination, file_state, None, owner)
            records.pop(destination, None)
    if state["reload"]:
        systemd.change("daemon-reload")
        state["reload"] = False
    if not records:
        state["files"].pop(owner, None)
    state["managed"] = [desired] if desired else []
    if not desired:
        state["original"] = None
        state["retiring"] = False
    persist()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--service", default="")
    parser.add_argument("--files", type=Path, required=True)
    parser.add_argument("--systemctl", default="/usr/bin/systemctl")
    parser.add_argument("--alias", default="/etc/systemd/system/display-manager.service")
    args = parser.parse_args()
    with lock(str(args.state) + ".lock"):
        reconcile(args.state, args.owner, args.service or None,
                  json.loads(args.files.read_text()), Systemd(args.systemctl, args.alias))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from error
