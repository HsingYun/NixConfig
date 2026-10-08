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
        date = datetime.fromtimestamp(entry.lstat().st_mtime).astimezone().strftime("%Y-%m-%d %H:%M:%S")
        specialised = path / "specialisation"
        running = path == active or (active is not None and specialised.is_dir() and any(
            item.resolve() == active for item in specialised.iterdir()
        ))
        result.append(Generation(number, date, path, entry.name == selected, running))
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


def list_generations(backend):
    print("GENERATION  CREATED              STATE")
    for gen in generations(backend):
        marks = [name for flag, name in [(gen.active, "* active"), (gen.selected, "selected")] if flag]
        if not gen.path.exists():
            marks.append("missing")
        print(f"{gen.id:<11} {gen.date:<20} {'; '.join(marks)}")
    print("* active = running configuration; selected = profile/next-boot configuration")


def generation_info(backend, number):
    gen = select(backend, number)
    print(f"Generation: {gen.id}\nCreated: {gen.date}\nBackend: {backend.name}")
    print(f"Active: {gen.active}\nSelected: {gen.selected}\nStore path: {gen.path}")
    data = metadata(gen.path)
    if data:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("Source flake: unavailable (generation was not created by nixman)")
    for name in ("nixos-version", "darwin-version", "hm-version"):
        version = gen.path / name
        if version.is_file():
            print(f"{name}: {version.read_text().strip()}")
