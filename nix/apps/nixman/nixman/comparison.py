"""Collect immutable generation evidence shared by summary and content views."""
from dataclasses import dataclass, field
from functools import cached_property
import hashlib
import os
import stat
from pathlib import Path

from .profiles import metadata
from .runtime import Error, run


MAX_CONTENT_BYTES = 1024 * 1024
READ_CHUNK_BYTES = 64 * 1024


@dataclass(frozen=True)
class FileEntry:
    identity: tuple
    source: Path = field(compare=False)


class StoredFiles:
    """One read boundary for inventory, hashes and optional text rendering."""

    def __init__(self, generation):
        self.roots = [Path(os.environ.get("NIX_STORE_DIR", "/nix/store")).resolve()]
        if generation is not None:
            self.roots.append(generation.resolve())

    def allowed(self, path):
        resolved = path.resolve()
        return any(resolved.is_relative_to(root) for root in self.roots)

    def _digest(self, path, replace=b""):
        digest = hashlib.sha256()
        # Keep a possible partial self-reference across chunk boundaries.
        pending = b""
        with path.open("rb") as source:
            while chunk := source.read(READ_CHUNK_BYTES):
                pending += chunk
                if replace:
                    while (index := pending.find(replace)) >= 0:
                        digest.update(pending[:index])
                        digest.update(b"<generation>")
                        pending = pending[index + len(replace):]
                    keep = min(len(pending), len(replace) - 1)
                else:
                    keep = 0
                end = len(pending) - keep
                digest.update(pending[:end])
                pending = pending[end:]
        digest.update(pending)
        return digest.hexdigest()

    def entry(self, path, *, follow_link=False, normalise=None):
        try:
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) and not follow_link:
                target = os.readlink(path)
                if normalise is not None:
                    target = target.replace(str(normalise), "<generation>")
                return FileEntry(("link", target), path)
            if not self.allowed(path):
                return FileEntry(("external", str(path)), path)
            if stat.S_ISLNK(info.st_mode):
                info = path.stat()
        except FileNotFoundError:
            return FileEntry(("source", str(path)), path)
        if stat.S_ISREG(info.st_mode):
            identity = ("file", self._digest(path, os.fsencode(normalise) if normalise else b""),
                        info.st_mode & 0o777)
        elif stat.S_ISDIR(info.st_mode):
            identity = ("directory", info.st_mode & 0o777)
        else:
            identity = ("source", str(path))
        return FileEntry(identity, path)

    def tree(self, root, *, normalise_generation=False):
        if not self.allowed(root):
            return {".": self.entry(root)}
        def scan_error(error):
            raise Error(f"Could not scan configuration directory {error.filename or root}: {error.strerror}") from error

        try:
            root.stat()
        except FileNotFoundError:
            return {}
        except OSError as error:
            scan_error(error)
        result = {}
        for directory, dirs, files in os.walk(root, followlinks=False, onerror=scan_error):
            for name in sorted(dirs + files):
                path = Path(directory) / name
                key = str(path.relative_to(root))
                if normalise_generation and key == "nixman.json":
                    continue
                result[key] = self.entry(path, normalise=root if normalise_generation else None)
        return result

    def declared(self, data):
        result = {}
        for destination, source in data.get("managedFiles", {}).items():
            path = Path(source)
            entry = self.entry(path, follow_link=True)
            if entry.identity[0] == "directory":
                # Package/source trees are already covered by the closure.
                opaque = destination.startswith(("/etc/profiles/", "/etc/nix/inputs/", "/etc/nix/path/"))
                entries = {} if opaque else self.tree(path)
                if entries:
                    result.update((str(Path(destination) / suffix), entry) for suffix, entry in entries.items())
                else:
                    result[destination] = FileEntry(("directory", source), path)
            else:
                result[destination] = entry
        return result

    def text(self, entry):
        path = entry.source
        if not self.allowed(path):
            return f"[External source; contents not read: {path}]\n"
        try:
            mode = path.stat().st_mode
        except FileNotFoundError:
            mode = 0
        if stat.S_ISDIR(mode):
            return "[Directory; contents are represented by file entries or the closure.]\n"
        if not stat.S_ISREG(mode):
            return "[Source is unavailable or is not a regular file.]\n"
        with path.open("rb") as source:
            content = source.read(MAX_CONTENT_BYTES + 1)
        if len(content) > MAX_CONTENT_BYTES:
            return f"[Content omitted: file exceeds {MAX_CONTENT_BYTES} bytes.]\n"
        try:
            text = content.decode("utf-8")
        except UnicodeDecodeError:
            return "[Binary file; content omitted.]\n"
        if "\0" in text:
            return "[Binary file; content omitted.]\n"
        return text if text.endswith("\n") else text + "\n[No newline at end of file]\n"


@dataclass
class Snapshot:
    path: Path | None
    data: dict | None
    reader: StoredFiles
    files: dict[str, FileEntry]

    @cached_property
    def closure(self):
        return set(run(["nix-store", "--query", "--requisites", self.path], capture=True).splitlines()) if self.path else set()

    @property
    def payload_closure(self):
        result = self.closure - {str(self.path)}
        record = self.path / "nixman.json"
        if record.is_symlink():
            result.discard(str(record.resolve()))
        return result


@dataclass
class Comparison:
    before: Snapshot
    after: Snapshot
    declared: bool
    system: bool

    @cached_property
    def file_changes(self):
        return list(changes(self.before.files, self.after.files))

    @cached_property
    def changed(self):
        old, new = self.before, self.after
        if old.path is None:
            return True
        if old.path == new.path:
            return False
        return (old.payload_closure != new.payload_closure or
                old.reader.tree(old.path, normalise_generation=True) !=
                new.reader.tree(new.path, normalise_generation=True))


def compare(backend, old, new):
    snapshots = []
    for path in (old, new):
        reader = StoredFiles(path)
        if path is not None and not reader.allowed(path / "nixman.json"):
            raise Error(f"Generation metadata points outside the store: {path}")
        snapshots.append(Snapshot(path, metadata(path), reader, {}))
    declared = all(item.data is not None and "managedFiles" in item.data for item in snapshots)
    for item in snapshots:
        if declared:
            item.files = item.reader.declared(item.data)
        elif item.path is not None:
            item.files = item.reader.tree(item.path / ("etc" if backend.system else "home-files"))
    return Comparison(*snapshots, declared=declared, system=backend.system)


def changes(old, new):
    for key in sorted(old.keys() | new.keys()):
        if key not in old:
            yield "+", key
        elif key not in new:
            yield "-", key
        elif old[key] != new[key]:
            yield "~", key
