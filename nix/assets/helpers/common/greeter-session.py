"""Seed a greeter default once per configured session, preserving login memory."""
import json
from pathlib import Path
import re
import sys

from safe_files import lock, read, write


def seed(cache, session):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", session):
        raise ValueError("Invalid session identifier")
    directory = Path(cache) / ".local/state"
    marker = directory / "nixconfig-default-session"
    with lock(str(marker) + ".lock"):
        if read(marker) == session.encode():
            return
        memory = directory / "memory.json"
        raw = read(memory)
        previous = json.loads(raw) if raw is not None else {}
        if not isinstance(previous, dict):
            raise ValueError("Invalid greeter memory")
        previous["lastSessionDesktopId"] = f"{session}.desktop"
        previous.pop("lastSessionId", None)
        write(memory, json.dumps(previous, sort_keys=True), expected=raw)
        write(marker, session)


if __name__ == "__main__":
    seed(*sys.argv[1:])
