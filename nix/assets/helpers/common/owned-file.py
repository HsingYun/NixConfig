"""Reconcile one explicitly owned system file; never adopt an existing file."""
import hashlib
import json
from pathlib import Path
import sys

from safe_files import lock, read, remove, write, snapshot


def digest(value):
    return hashlib.sha256(value).hexdigest()


def reconcile(destination, state, source, owner="default"):
    content = read(source) if source else None
    if source and content is None:
        raise FileNotFoundError(source)
    with lock(str(state) + ".lock"):
        raw = read(state)
        record = json.loads(raw) if raw is not None else None
        if record is not None and (record.get("destination") != str(Path(destination).absolute())
                                   or not isinstance(record.get("files"), list)):
            raise RuntimeError("Invalid managed-file ownership record")
        owners = dict((record or {}).get("owners", {}))
        if content is None and owner not in owners:
            return
        if content is not None and any(value != digest(content) for name, value in owners.items() if name != owner):
            raise RuntimeError(f"Conflicting owners for system file: {destination}")
        current, identity = snapshot(destination)
        current_record = {"checksum": digest(current), "identity": identity} if current is not None else None
        if current is not None and (record is None or current_record not in record["files"]):
            raise RuntimeError(f"Preserving unmanaged or modified system file: {destination}")
        if content is None:
            del owners[owner]
            if owners:
                record["owners"] = owners
                write(state, json.dumps(record, sort_keys=True))
                return
            if current is not None:
                remove(destination, current, identity=identity)
            if raw is not None:
                remove(state, raw)
            return
        checksum = digest(content)
        owners[owner] = checksum
        new_record = current_record
        if current != content:
            def journal(new_identity):
                nonlocal new_record
                new_record = {"checksum": checksum, "identity": new_identity}
                pending = {"destination": str(Path(destination).absolute()),
                           "files": ([current_record] if current_record else []) + [new_record], "owners": owners}
                # Record the staged inode, not just its content. An interrupted
                # create cannot claim an unrelated file with identical bytes.
                write(state, json.dumps(pending, sort_keys=True))
            write(destination, content, mode=0o644, expected=current,
                  identity=identity, before_commit=journal)
        final = json.dumps({"destination": str(Path(destination).absolute()), "files": [new_record], "owners": owners}, sort_keys=True)
        if read(state) != final.encode():
            write(state, final)



if __name__ == "__main__":
    destination, state, source, owner = sys.argv[1:]
    reconcile(destination, state, source or None, owner)
