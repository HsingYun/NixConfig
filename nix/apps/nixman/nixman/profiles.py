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


def generations(backend):
    profile = backend.profile()
    if not profile.exists() and not profile.is_symlink():
        return []
    active = backend.active()
    selected = profile.readlink().name if profile.is_symlink() else None
    result = []
    # Like nixos-rebuild list-generations, inspect upstream profile links.
    # nix-env --list-generations locks the profile even for a read, requiring
    # unnecessary root access for system profiles on current Nix versions.
    for entry in profile.parent.glob(f"{profile.name}-*-link"):
        match = re.fullmatch(re.escape(profile.name) + r"-(\d+)-link", entry.name)
        if not match:
            continue
        number = int(match[1])
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
    link = str(profile.readlink()) if profile.is_symlink() else None
    return link, str(profile.resolve()) if profile.exists() else None, str(backend.active())
