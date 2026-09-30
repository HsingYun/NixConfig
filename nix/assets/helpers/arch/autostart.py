"""Reconcile native Fcitx startup with the selected input-method mode.

The suppression survives feature removal because the native package survives it.
Selecting desktop autostart releases the owned suppression, retaining its stamp
so a later input-method disable can still suppress the retained native package.
Unmanaged or edited user entries are never overwritten.
"""
import hashlib
from pathlib import Path
import re
import sys

# Keep shared filesystem safety in one implementation across ports.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))

from safe_files import lock, read, remove, write


def reconcile(destination, state, mode):
    if mode not in {"systemd", "autostart", "disabled"}:
        raise ValueError(f"Unknown input-method startup mode: {mode}")
    if mode == "disabled" and read(state) is None:
        return
    with lock(str(state) + ".lock"):
        # Three states: absent means never managed; empty records participation
        # without owning a file; a checksum owns the suppression we installed.
        stamp = read(state)
        if stamp not in {None, b""} and not re.fullmatch(rb"[0-9a-f]{64}", stamp):
            raise ValueError("Invalid autostart ownership state")
        if mode == "autostart" and stamp in {None, b""}:
            if stamp is None:
                write(state, b"")
            return
        text = b"[Desktop Entry]\nType=Application\nName=Fcitx 5\nHidden=true\n"
        checksum = hashlib.sha256(text).hexdigest().encode()
        current = read(destination)
        if current is not None and hashlib.sha256(current).hexdigest().encode() != stamp:
            raise RuntimeError(f"Preserving unmanaged or modified autostart entry: {destination}")
        if mode == "autostart":
            if current is not None:
                remove(destination, current)
            # Retain participation, but release ownership of the removed file.
            write(state, b"")
            return
        if current == text:
            return
        write(state, checksum)
        write(destination, text, mode=0o644, expected=current)


if __name__ == "__main__":
    destination, state, mode = sys.argv[1:]
    reconcile(Path(destination), Path(state), mode)
