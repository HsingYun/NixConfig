"""Shared read models for terminal output, JSON clients and completions."""
from datetime import datetime, timezone
import json

from .profiles import generations, metadata, select


def envelope(command, **values):
    return {"schema": 1, "command": command, **values}


def emit_json(value):
    print(json.dumps(value, indent=2, ensure_ascii=False))


def generation_data(gen):
    return {
        "id": gen.id,
        "createdAt": datetime.fromtimestamp(gen.created_at, timezone.utc).isoformat()
                     if gen.created_at is not None else None,
        "path": str(gen.path),
        "active": gen.active,
        "selected": gen.selected,
        "available": gen.path.exists(),
    }


def status_data(backend):
    active, profile = backend.active(), backend.profile()
    selected = profile.resolve() if profile.exists() else None
    available = generations(backend)
    record = metadata(active)
    return envelope("status", backend=backend.name, profile=str(profile),
                    active={"generations": [gen.id for gen in available if gen.active],
                            "path": str(active) if active else None},
                    selected={"generations": [gen.id for gen in available if gen.selected],
                              "path": str(selected) if selected else None},
                    profileMatchesRunning=active is not None and active == selected,
                    defaultUpdateSource=record["flake"] if record else None,
                    revision=record.get("revision") if record else None)


def list_data(backend):
    return envelope("generation list", backend=backend.name, profile=str(backend.profile()),
                    generations=[generation_data(gen) for gen in generations(backend)])


def info_data(backend, number):
    gen = select(backend, number)
    versions = {}
    for name in ("nixos-version", "darwin-version", "hm-version"):
        path = gen.path / name
        if path.is_file():
            versions[name] = path.read_text().strip()
    return envelope("generation info", backend=backend.name, profile=str(backend.profile()),
                    generation=generation_data(gen), provenance=metadata(gen.path), versions=versions)


def local_date(value):
    return datetime.fromisoformat(value).astimezone().strftime("%Y-%m-%d %H:%M:%S") if value else "unknown"


def display_status(data):
    print(f"Backend: {data['backend']}\nProfile: {data['profile']}")
    for name in ("active", "selected"):
        ids = ", ".join(map(str, data[name]["generations"])) or "unknown"
        print(f"{name.capitalize()} generation: {ids}")
    for name in ("active", "selected"):
        print(f"{name.capitalize()} path: {data[name]['path'] or '(none)'}")
    print(f"Profile matches running configuration: {data['profileMatchesRunning']}")
    if data["defaultUpdateSource"] is not None:
        print(f"Default update source: {data['defaultUpdateSource']}")
        print(f"Recorded revision: {data['revision'] or '(not available)'}")
    else:
        print("Default update source: unavailable; supply FLAKE#HOST on the first update")


def display_list(data):
    print("GENERATION  CREATED              STATE")
    for gen in data["generations"]:
        marks = [name for flag, name in ((gen["active"], "* active"), (gen["selected"], "selected"),
                                         (not gen["available"], "missing")) if flag]
        print(f"{gen['id']:<11} {local_date(gen['createdAt']):<20} {'; '.join(marks)}")
    print("* active = running configuration; selected = profile/next-boot configuration")


def display_info(data):
    gen = data["generation"]
    print(f"Generation: {gen['id']}\nCreated: {local_date(gen['createdAt'])}\nBackend: {data['backend']}")
    print(f"Active: {gen['active']}\nSelected: {gen['selected']}\nStore path: {gen['path']}")
    if data["provenance"] is not None:
        emit_json(data["provenance"])
    else:
        print("Source flake: unavailable (generation was not created by nixman)")
    for name, version in data["versions"].items():
        print(f"{name}: {version}")
