"""Read upstream profile generations, distinguishing selected and active state."""
from dataclasses import dataclass
from datetime import datetime
import json
from pathlib import Path
import re

from .runtime import Error


@dataclass(frozen=True)
class Generation:
    id: int
    date: str
    path: Path
    selected: bool
    active: bool
    created_at: float | None = None


def _profile_links(profile):
    """Validate upstream's selector/numbered-link layout without inspecting payload formats."""
    def invalid(reason):
        raise Error(f"Invalid profile {profile}: {reason}. Check the profile layout before continuing.")

    entries = []
    # Like nixos-rebuild list-generations, inspect upstream profile links.
    # nix-env --list-generations locks the profile even for a read, requiring
    # unnecessary root access for system profiles on current Nix versions.
    siblings = profile.parent.iterdir() if profile.parent.is_dir() else []
    for entry in siblings:
        match = re.fullmatch(re.escape(profile.name) + r"-(\d+)-link", entry.name)
        if not match:
            continue
        if not entry.is_symlink():
            invalid(f"numbered generation entry {entry.name} is not a symbolic link")
        entries.append((int(match[1]), entry))

    if not entries:
        if not profile.is_symlink() and (
            not profile.exists() or (profile.is_dir() and next(profile.iterdir(), None) is None)
        ):
            return None, []
        invalid(f"profile is populated or is a symbolic link, but has no numbered generation links ({profile.name}-<number>-link)")

    if not profile.is_symlink():
        invalid("numbered generation links exist, but the profile selector is missing or is not a symbolic link")
    selected = profile.parent / profile.readlink()
    if selected.parent.resolve() != profile.parent.resolve() or selected.name not in {entry.name for _, entry in entries}:
        invalid("profile selector does not point to one of its numbered generation links")
    # Missing store targets remain visible as unavailable generations. Their
    # identity comes from the numbered link, not the payload's continued existence.
    return selected.name, entries


def generations(backend):
    selected, entries = _profile_links(backend.profile())
    active = backend.active()
    result = []
    for number, entry in entries:
        path = entry.resolve()
        created_at = entry.lstat().st_mtime
        date = datetime.fromtimestamp(created_at).astimezone().strftime("%Y-%m-%d %H:%M:%S")
        specialised = path / "specialisation"
        running = path == active or (active is not None and specialised.is_dir() and any(
            item.resolve() == active for item in specialised.iterdir()
        ))
        result.append(Generation(number, date, path, entry.name == selected, running, created_at))
    return sorted(result, key=lambda item: item.id, reverse=True)


def select(backend, number):
    for generation in generations(backend):
        if generation.id == number:
            if not generation.path.exists():
                raise Error(f"Generation {number} has been garbage-collected or is unavailable.")
            return generation
    raise Error(f"Generation {number} does not exist. Use 'nixman generation list'.")


def metadata(path):
    if path is None or not (path / "nixman.json").exists():
        return None
    try:
        value = json.loads((path / "nixman.json").read_text())
        if value.get("schema") != 1 or not isinstance(value.get("flake"), str):
            raise ValueError("unsupported schema")
        return value
    except (ValueError, AttributeError) as exc:
        raise Error(f"Invalid nixman metadata in {path}: {exc}") from exc


def fingerprint(backend):
    profile = backend.profile()
    _profile_links(profile)
    link = str(profile.readlink()) if profile.is_symlink() else None
    return link, str(profile.resolve()) if profile.exists() else None, str(backend.active())
