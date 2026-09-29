"""Suppress a native package's autostart after handing startup to a user unit.

The suppression survives feature removal because the native package survives it.
Unmanaged or edited user entries are never overwritten.
"""
import hashlib
from pathlib import Path
import sys

from safe_files import lock, read, write


def suppress(destination, state, enabled):
    if not enabled and read(state) is None:
        return
    with lock(str(state) + ".lock"):
        text = b"[Desktop Entry]\nType=Application\nName=Fcitx 5\nHidden=true\n"
        checksum = hashlib.sha256(text).hexdigest().encode()
        current = read(destination)
        if current is not None and hashlib.sha256(current).hexdigest().encode() != read(state):
            raise RuntimeError(f"Preserving unmanaged or modified autostart entry: {destination}")
        if current == text:
            return
        write(state, checksum)
        write(destination, text, mode=0o644, expected=current)


if __name__ == "__main__":
    destination, state, enabled = sys.argv[1:]
    suppress(Path(destination), Path(state), enabled == "true")
