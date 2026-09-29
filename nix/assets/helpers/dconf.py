"""Track dconf values, including the last removal and pre-adapter generations."""

import configparser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from gi.repository import GLib
from safe_files import read as read_file, write as write_file, lock


def normalize(value):
    return GLib.Variant.parse(None, value, None, None).print_(True) if value else ""


def save(path, data):
    serialized = json.dumps(data, sort_keys=True).encode()
    if read_file(path) != serialized:
        write_file(path, serialized)


def previous_generation(path):
    # HM's older dconf activation embeds immutable INI inputs. Read those inputs
    # without executing the old script; only reset values still matching them.
    activate = Path(path) / "activate"
    if not path or not activate.is_file():
        return {}
    result = {}
    for name in re.findall(r"dconf load / < (/nix/store/[^\s;]+-hm-dconf.ini)", activate.read_text())[:1]:
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        parser.read(name)
        # The legacy default database has a key manifest. Restrict migration to
        # those keys; named databases stay untouched if their profile is unknown.
        keys_path = Path(path) / "state/dconf-keys.json"
        keys = set(json.loads(keys_path.read_text())) if keys_path.is_file() else set()
        for section in parser.sections():
            for key, value in parser[section].items():
                full_key = f"/{section}/{key}"
                if full_key in keys:
                    result[full_key] = {"original": "", "written": normalize(value)}
    return {"": result} if result else {}


def reconcile(desired, path, command, old_generation=""):
    raw = read_file(path)
    old = json.loads(raw) if raw is not None else previous_generation(old_generation)
    # Validate every record before the first dconf write/reset.
    for databases in [desired, old]:
        if not isinstance(databases, dict):
            raise ValueError("Invalid dconf database manifest")
        for database, entries in databases.items():
            if database and not re.fullmatch(r"[A-Za-z0-9_]+", database):
                raise ValueError("Invalid dconf database name")
            if not isinstance(entries, dict):
                raise ValueError("Invalid dconf key manifest")
            for key, value in entries.items():
                if not re.fullmatch(r"/(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+", key):
                    raise ValueError("Invalid dconf key")
                if databases is desired:
                    normalize(value)
                else:
                    normalize(value["original"])
                    normalize(value["written"])
                    for pending in value.get("pending", []):
                        normalize(pending)
    for database in sorted(set(old) | set(desired)):
        records = old.setdefault(database, {})
        wanted = desired.get(database, {})
        with tempfile.TemporaryDirectory() as temporary:
            env = os.environ.copy()
            if database:
                profile = Path(temporary) / "profile"
                profile.write_text(f"user-db:{database}\n")
                env["DCONF_PROFILE"] = str(profile)
            else:
                env.pop("DCONF_PROFILE", None)

            def read(key):
                return subprocess.check_output([command, "read", key], env=env, text=True).strip()

            def write(key, value):
                args = ["write", key, value] if value else ["reset", key]
                subprocess.run([command, *args], env=env, check=True)

            for key in sorted(set(records) - set(wanted)):
                record = records[key]
                if normalize(read(key)) in [record["written"]] + record.get("pending", []):
                    write(key, record["original"])
                else:
                    print(f"Preserving externally changed dconf value: {key}")
                del records[key]
                save(path, old)
            for key, value in wanted.items():
                target = normalize(value)
                current = normalize(read(key))
                if key not in records:
                    records[key] = {"original": current, "written": target}
                else:
                    # A failed update may leave either the previous or new owned
                    # value. Keep both until the write succeeds.
                    record = records[key]
                    record["pending"] = list(set(record.get("pending", []) + [record["written"], target]))
                # Journal the intended value before the write, making retries
                # safe even if dconf fails or activation is interrupted.
                save(path, old)
                if current != target:
                    write(key, value)
                records[key]["written"] = target
                records[key].pop("pending", None)
                save(path, old)
        if not records:
            del old[database]
    if old or path.exists():
        save(path, old)


def apply(desired, path, command, old_generation=""):
    if not desired and read_file(path) is None and not old_generation:
        return
    with lock(str(path) + ".lock"):
        reconcile(desired, path, command, old_generation)


if __name__ == "__main__":
    desired_path, state_path, dconf, old_generation = sys.argv[1:]
    apply(json.loads(Path(desired_path).read_text()), Path(state_path), dconf, old_generation)
