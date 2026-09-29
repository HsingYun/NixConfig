import importlib.util
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("launcher", sys.argv[1])
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)
installer = sys.argv[2]

with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    data, state = base / "data", base / "state"
    first, second = base / "usr-local", base / "usr"
    for root, command in [(first, "custom-editor"), (second, "vim")]:
        apps = root / "share/applications"
        apps.mkdir(parents=True)
        (apps / "vim.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=Editor\n"
            f"Exec={command} %F\nMimeType=text/plain;\nActions=new;\n[Desktop Action new]\nName=New\nExec={command}\n"
        )
    rules = {"hiddenEntries": ["vim.desktop", "missing.desktop"], "nativeRoots": [str(first), str(second)]}
    apply = lambda rules=rules, **kw: launcher.apply(rules, data, state, installer, **kw)
    apply(dry_run=True)
    assert not data.exists() and not state.exists()
    apply()
    target = data / "applications/vim.desktop"
    assert "Exec=custom-editor %F" in target.read_text()
    assert "NoDisplay=true" in target.read_text()
    assert "[Desktop Action new]" in target.read_text()
    assert not (target.parent / "missing.desktop").exists()
    timestamp = target.stat().st_mtime_ns
    apply()
    assert target.stat().st_mtime_ns == timestamp
    # Moving from native to Nix changes the source, not the override owner.
    nix_root = base / "nix-provider"
    (nix_root / "share/applications").mkdir(parents=True)
    (nix_root / "share/applications/vim.desktop").write_text(target.read_text().replace("custom-editor", "nix-editor"))
    apply({"hiddenEntries": ["vim.desktop"], "nativeRoots": [str(nix_root), str(first)]})
    assert "Exec=nix-editor %F" in target.read_text()
    apply()
    # Native package upgrades refresh the copied entry.
    source = first / "share/applications/vim.desktop"
    source.write_text(source.read_text().replace("custom-editor", "new-editor"))
    apply()
    assert "Exec=new-editor %F" in target.read_text()
    apply({"hiddenEntries": [], "nativeRoots": []}, dry_run=True)
    assert target.exists()
    apply({"hiddenEntries": [], "nativeRoots": []})
    assert not target.exists()
    # Package removal removes only our override.
    apply()
    source.unlink()
    (second / "share/applications/vim.desktop").unlink()
    apply()
    assert not target.exists()
    source.write_text("[Desktop Entry]\nType=Application\nName=Editor\nExec=vim\n")
    apply()
    target.write_text("user edits")
    apply()
    apply({"hiddenEntries": [], "nativeRoots": []})
    assert target.read_text() == "user edits"
    # Simulate an edit after ownership was inspected but before deletion.
    target.unlink()
    apply()
    real_remove = launcher.remove
    def edit_before_remove(path, expected):
        Path(path).write_text("concurrent user edit")
        return real_remove(path, expected)
    launcher.remove = edit_before_remove
    try:
        try:
            apply({"hiddenEntries": [], "nativeRoots": []})
        except RuntimeError:
            pass
        else:
            raise AssertionError("concurrent edit deleted")
    finally:
        launcher.remove = real_remove
    assert target.read_text() == "concurrent user edit"
    # An edit between ownership validation and later reads must never be adopted.
    target.unlink()
    apply()
    original = target.read_bytes()
    real_sha256 = launcher.hashlib.sha256
    def edit_after_hash(content):
        result = real_sha256(content)
        if content == original:
            target.write_text("edit after ownership hash")
        return result
    launcher.hashlib.sha256 = edit_after_hash
    try:
        try:
            apply({"hiddenEntries": [], "nativeRoots": []})
        except RuntimeError:
            pass
    finally:
        launcher.hashlib.sha256 = real_sha256
    assert target.read_text() == "edit after ownership hash"
    # A user or Home Manager symlink is never overwritten or followed for writes.
    target.unlink()
    target.symlink_to(source)
    apply()
    assert target.is_symlink() and "NoDisplay" not in source.read_text()
    apply({"hiddenEntries": [], "nativeRoots": []})
    assert target.is_symlink()
    try:
        apply({"hiddenEntries": ["../escape.desktop"], "nativeRoots": []})
    except ValueError:
        pass
    else:
        raise AssertionError("path traversal accepted")
print("Native launcher lifecycle passed")
