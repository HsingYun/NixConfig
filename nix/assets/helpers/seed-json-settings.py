"""Seed missing JSONC settings once, preserving user text and all later edits."""

import errno
import json
from pathlib import Path
import re
import sys

import json5

from safe_files import lock, read, snapshot, write


OBJECT_START = re.compile(r"\A\ufeff?(?:\s|//[^\r\n]*(?:\r?\n|$)|/\*[\s\S]*?\*/)*\{")


def seed(settings, marker, defaults):
    with lock(str(marker) + ".lock"):
        if read(marker) is not None:
            return
        try:
            before, identity = snapshot(settings)
            text = before.decode("utf-8") if before is not None else "{\n}\n"
            values = json5.loads(text.lstrip("\ufeff"))
            opening = OBJECT_START.match(text)
            if not isinstance(values, dict) or opening is None:
                raise ValueError("settings must be a JSON object")
        except (ValueError, UnicodeError) as error:
            print(f"Skipping settings initialization for {settings}: {error}")
        except OSError as error:
            if error.errno not in {errno.ELOOP, errno.ENOTDIR}:
                raise
            print(f"Skipping symlinked settings: {settings}")
        else:
            missing = {key: value for key, value in defaults.items() if key not in values}
            if missing:
                # Insert only at the opening brace. Do not serialize the user's
                # settings: comments, ordering and trailing commas stay intact.
                entries = json.dumps(missing, ensure_ascii=False, indent=2)[1:-1].strip("\n")
                position = opening.end()
                updated = text[:position] + "\n" + entries + ("," if values else "") + "\n" + text[position:]
                write(settings, updated, expected=before, identity=identity)
        write(marker, "Initialized; settings are now user-owned.\n", expected=None)


if __name__ == "__main__":
    seed(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))
