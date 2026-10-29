"""Render generation changes and declared native package intent."""
import json

from .comparison import changes
from .runtime import nix
from .terminal import CHANGE_STYLES, emit, external


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
                    emit(f"  {mark} {provider}.{group}: {name}", CHANGE_STYLES[mark])
            elif a != b:
                emit(f"  ~ {provider}.{group}: {json.dumps(a)} -> {json.dumps(b)}", "change")
    if old is None:
        print("  Previous generation has no recorded plan; '+' means desired, not necessarily absent on this machine.")
    print("  Native changes above describe configuration intent, not a resolved package-manager transaction.")
    print("  Removing a declaration may retain its package. Homebrew/pacman/AUR versions and application data are not rolled back by Nix generations.")


def preview(comparison):
    old, new = comparison.before.path, comparison.after.path
    old_data, new_data = comparison.before.data, comparison.after.data
    emit(f"\nBaseline:  {old or '(none)'}\nCandidate: {new}", "heading", flush=True)
    emit("\nNix closure changes:", "heading", flush=True)
    if old is not None:
        print(external(nix("store", "diff-closures", str(old), str(new), capture=True)), end="", flush=True)
    else:
        print("  Initial activation (no active generation to compare).")
        nix("path-info", "--closure-size", "--human-readable", str(new))
    emit("\nManaged file changes (+ add, - remove, ~ change):", "heading")
    if not comparison.declared:
        # Older generations have no structured provenance. Compare the files
        # upstream included, without guessing usernames from activation code.
        if comparison.system and new_data and "managedFiles" in new_data:
            print("  Embedded Home Manager baseline unavailable in the old generation.")
            print("  Desired home files (not necessarily additions):")
            for name in sorted(new_data["managedFiles"]):
                if not name.startswith("/etc/"):
                    print(f"    {name}")
    rows = comparison.file_changes
    for mark, name in rows:
        emit(f"  {mark} {name}", CHANGE_STYLES[mark])
    if not rows:
        print("  None.")
    emit("\nNative package declarations:", "heading")
    native_preview(old_data, new_data)
    print("\nActivation also applies services and settings from the candidate configuration.", flush=True)
    changed = comparison.changed
    if not changed:
        emit("No configuration changes detected.", "success")
        print("Nix may reuse the existing generation. Activation can still repair drift or run native package actions.")
    return changed
