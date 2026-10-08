"""Show immutable closure/file changes and declared native package intent."""
import json
import hashlib
import os
from pathlib import Path

from .profiles import metadata
from .runtime import nix, run


def file_manifest(root, *, normalise_generation=False):
    result = {}
    if not root.exists():
        return result
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            path = Path(directory) / name
            key = str(path.relative_to(root))
            if normalise_generation and key == "nixman.json":
                continue
            if path.is_symlink():
                target = os.readlink(path)
                if normalise_generation:
                    target = target.replace(str(root), "<generation>")
                result[key] = ("link", target)
            elif path.is_file():
                # Managed files are normally store symlinks. Read regular files
                # too, without displaying potentially sensitive contents.
                content = path.read_bytes()
                if normalise_generation:
                    content = content.replace(os.fsencode(root), b"<generation>")
                result[key] = ("file", hashlib.sha256(content).hexdigest(), path.stat().st_mode & 0o777)
            elif path.is_dir():
                result[key] = ("directory", path.stat().st_mode & 0o777)
    return result


def configuration_equal(old, new):
    if old is None:
        return False
    if old == new:
        return True
    def payload_closure(path):
        closure = set(run(["nix-store", "--query", "--requisites", path], capture=True).splitlines())
        closure.discard(str(path))
        record = path / "nixman.json"
        if record.is_symlink():
            closure.discard(str(record.resolve()))
        return closure
    return (payload_closure(old) == payload_closure(new)
            and file_manifest(old, normalise_generation=True) == file_manifest(new, normalise_generation=True))


def declared_files(data):
    """Use module declarations to include embedded Home Manager files too."""
    result = {}
    for destination, source in data.get("managedFiles", {}).items():
        path = Path(source)
        if path.is_dir():
            # These are package/source trees, not configuration directories.
            # Their content is already covered by the closure comparison.
            if destination.startswith(("/etc/profiles/", "/etc/nix/inputs/", "/etc/nix/path/")):
                result[destination] = ("directory", source)
            else:
                entries = file_manifest(path)
                if not entries:
                    result[destination] = ("directory", source)
                for suffix, value in entries.items():
                    result[str(Path(destination) / suffix)] = value
        elif path.is_file():
            result[destination] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
        else:
            result[destination] = ("source", source)
    return result


def changes(old, new):
    for key in sorted(old.keys() | new.keys()):
        if key not in old:
            yield "+", key
        elif key not in new:
            yield "-", key
        elif old[key] != new[key]:
            yield "~", key


def native_preview(old, new):
    before = (old or {}).get("native", {})
    after = (new or {}).get("native", {})
    if not any(before.values()) and not any(after.values()):
        print("  No recorded native package plan.")
        return
    for provider in sorted(before.keys() | after.keys()):
        left, right = before.get(provider, {}), after.get(provider, {})
        for group in sorted(left.keys() | right.keys()):
            a, b = left.get(group), right.get(group)
            if isinstance(a or b, list):
                for mark, name in changes(dict.fromkeys(a or []), dict.fromkeys(b or [])):
                    print(f"  {mark} {provider}.{group}: {name}")
            elif a != b:
                print(f"  ~ {provider}.{group}: {json.dumps(a)} -> {json.dumps(b)}")
    if old is None:
        print("  Previous generation has no recorded plan; '+' means desired, not necessarily absent on this machine.")
    print("  Native changes above describe configuration intent, not a resolved package-manager transaction.")
    print("  Removing a declaration may retain its package. Homebrew/pacman/AUR versions and application data are not rolled back by Nix generations.")


def preview(backend, old, new):
    old_data, new_data = metadata(old), metadata(new)
    print(f"\nBaseline:  {old or '(none)'}\nCandidate: {new}", flush=True)
    print("\nNix closure changes:", flush=True)
    if old is not None:
        nix("store", "diff-closures", str(old), str(new))
    else:
        print("  Initial activation (no active generation to compare).")
        nix("path-info", "--closure-size", "--human-readable", str(new))
    print("\nManaged file changes (+ add, - remove, ~ change):")
    subdir = "etc" if backend.system else "home-files"
    if old_data and "managedFiles" in old_data and new_data and "managedFiles" in new_data:
        before, after = declared_files(old_data), declared_files(new_data)
    else:
        # Older generations have no structured provenance. Compare the files
        # upstream included, without guessing usernames from activation code.
        before = file_manifest(old / subdir) if old else {}
        after = file_manifest(new / subdir)
        if backend.system and new_data and "managedFiles" in new_data:
            print("  Embedded Home Manager baseline unavailable in the old generation.")
            print("  Desired home files (not necessarily additions):")
            for name in sorted(new_data["managedFiles"]):
                if not name.startswith("/etc/"):
                    print(f"    {name}")
    rows = list(changes(before, after))
    for mark, name in rows:
        print(f"  {mark} {name}")
    if not rows:
        print("  None.")
    print("\nNative package declarations:")
    native_preview(old_data, new_data)
    print("\nActivation also applies services and settings from the candidate configuration.", flush=True)
    changed = not configuration_equal(old, new)
    if not changed:
        print("No configuration changes detected.")
        print("Nix may reuse the existing generation. Activation can still repair drift or run native package actions.")
    return changed
