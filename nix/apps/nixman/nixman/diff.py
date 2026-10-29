"""Read-only content review of the same generations used by the update preview."""
import json
from pathlib import Path
import shutil
import sys
import tempfile

from .runtime import Error, run


def write_report(comparison, index, output):
    snapshots = (comparison.before, comparison.after)
    snapshot, other = snapshots[index], snapshots[1 - index]
    generation, entries, record = snapshot.path, snapshot.files, snapshot.data
    output.write("Nixman generation content review (read-only; :qa returns to confirmation)\n")
    output.write(f"Generation: {generation or '(none)'}\n")
    output.write("\n=== Nix closure paths unique to this generation ===\n")
    for path in sorted(snapshot.closure - other.closure):
        output.write(path + "\n")
    output.write("\n=== Recorded native package declarations ===\n")
    json.dump(record.get("native", {}) if record else None, output, indent=2, sort_keys=True)
    output.write("\n\n=== Changed managed files ===\n")
    if not comparison.declared:
        output.write("Upstream file-tree comparison; embedded Home Manager declarations may be unavailable.\n")
    if not comparison.file_changes:
        output.write("No managed file changes.\n")
    for _, name in comparison.file_changes:
        output.write(f"\n--- {json.dumps(name)} ---\n")
        if name not in entries:
            output.write("[Not present in this generation]\n")
            continue
        output.write(f"Recorded entry: {json.dumps(entries[name].identity)}\n")
        try:
            content = snapshot.reader.text(entries[name])
        except OSError as error:
            content = f"[Could not read stored content: {error.strerror}]\n"
        output.write(content)


def view_diff(comparison):
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise Error("View Diff requires an interactive terminal for input and output.")
    editor = shutil.which("vimdiff")
    if editor:
        command = [editor]
    else:
        editor = shutil.which("vim")
        if not editor:
            raise Error("View Diff requires vimdiff or Vim on PATH. Install Vim with your preferred package manager.")
        command = [editor, "-d"]
    with tempfile.TemporaryDirectory(prefix="nixman-diff-") as temporary:
        paths = [Path(temporary) / name for name in ("baseline.txt", "candidate.txt")]
        for index, path in enumerate(paths):
            with path.open("w", encoding="utf-8") as output:
                write_report(comparison, index, output)
            path.chmod(0o400)
        # No user plugins, modelines, swap, or viminfo should run or persist this content.
        run([*command, "-N", "-R", "-n", "-i", "NONE", "-u", "NONE", "--noplugin",
             "--cmd", "set nomodeline", "-c", "windo setlocal nomodifiable",
             "--", *paths])
