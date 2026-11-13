"""Real Nix reference/profile/GC integration, exclusively in a disposable store."""
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

from nixman import flake
from nixman.backends import BACKENDS
from nixman.cleanup import generation_gc, store_gc
from nixman.flake import prepare
from nixman.runtime import WRAPPER_OPTIONS, nix, nix_json, run


def write_source(directory, collection="nixosConfigurations"):
    directory.mkdir(parents=True)
    (directory / "value").write_text("original")
    (directory / "flake.nix").write_text('''{
      outputs = { self }: {
        nixosConfigurations.fixture.extendModules = _: {
          observed = {
            value = builtins.readFile ./value;
            rev = self.rev or null;
            dirtyRev = self.dirtyRev or null;
            lastModified = self.lastModified or null;
            sourceInfo = builtins.removeAttrs self.sourceInfo [ "outPath" ];
          };
        };
      };
    }'''.replace("nixosConfigurations", collection))
    (directory / "flake.lock").write_text(json.dumps({"nodes": {"root": {}}, "root": "root", "version": 7}) + "\n")


def observe(wrapper, collection="nixosConfigurations"):
    return nix_json("eval", "--json", *WRAPPER_OPTIONS, "--no-update-lock-file",
                    f"{wrapper}#{collection}.nixman.observed")


with tempfile.TemporaryDirectory(prefix="nixman-integration-") as temporary:
    root = Path(temporary).resolve()
    store = root / "store"
    os.environ.update({
        "NIX_REMOTE": f"local?store={store}&state={root}/state&log={root}/log",
        "NIX_CONFIG": "experimental-features = nix-command flakes\nsubstituters =\nflake-registry =\n",
        "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_CONFIG_HOME": str(root / "config"),
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
    })
    # This assertion precedes every mutating test. Nothing below can target
    # the developer's or CI runner's normal Nix store.
    assert nix("eval", "--raw", "--expr", "builtins.storeDir", capture=True) == str(store)

    # Infer the target from each output collection before any host activation.
    for expected in BACKENDS.values():
        source = root / f"{expected.name}-source"
        write_source(source, expected.collection)
        work = root / f"{expected.name}-work"
        work.mkdir()
        detected, wrapper, record = prepare(f"path:{source}#fixture", work)
        assert detected.name == expected.name
        assert observe(wrapper, expected.collection)["value"] == "original"

    source = root / "path-source"
    write_source(source / "sub")
    work = root / "path-work"
    work.mkdir()
    backend, wrapper, record = prepare(f"path:{source}?dir=sub", work)
    assert record["flake"] == f"path:{source}?dir=sub#fixture"
    assert observe(wrapper)["value"] == "original"
    (source / "sub/value").write_text("changed-after-preview")
    try:
        assert observe(wrapper)["value"] == "original"
    except subprocess.CalledProcessError:
        # A rejected content hash is also safe: source edits must never
        # silently change what will be activated after the user previews it.
        pass

    git_source = root / "git-source"
    write_source(git_source)
    write_source(git_source / "sub")
    run(["git", "init", "--quiet", git_source])
    run(["git", "-C", git_source, "add", "."])
    run(["git", "-C", git_source, "-c", "user.name=Nixman Test", "-c", "user.email=test@example.invalid",
         "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "fixture"])
    revision = run(["git", "-C", git_source, "rev-parse", "HEAD"], capture=True).strip()
    for dirty in (False, True):
        for subdir in ("", "sub"):
            value = git_source / subdir / "value"
            value.write_text("dirty" if dirty else "original")
            work = root / f"git-{dirty}-{subdir or 'root'}-work"
            work.mkdir()
            reference = f"git+file://{git_source}" + ("?dir=sub" if subdir else "") + "#fixture"
            expected = nix_json("eval", "--json", "--no-update-lock-file",
                                reference.replace("#fixture", "#nixosConfigurations.fixture.extendModules"),
                                "--apply", "f: (f {}).observed")
            lock = (git_source / subdir / "flake.lock").read_bytes()
            backend, wrapper, record = prepare(reference, work)
            assert observe(wrapper) == expected
            assert expected["value"] == ("dirty" if dirty else "original")
            assert expected["dirtyRev" if dirty else "rev"] == revision + ("-dirty" if dirty else "")
            locked = json.loads((wrapper / "locked-input.json").read_text())
            assert locked["type"] == "git"
            assert locked.get("dir", "") == subdir
            assert record["sourceHash"] == expected["sourceInfo"]["narHash"]
            assert (git_source / subdir / "flake.lock").read_bytes() == lock
            # A rooted, materialized tree must survive GC independently of
            # evaluator caches and later edits to the original Git checkout.
            source_root = (work / "source").resolve(strict=True)
            assert source_root.parent == store
            run(["nix-store", "--gc"], capture=True)
            assert source_root.is_dir()
            value.write_text("changed-after-preview")
            shutil.rmtree(root / "cache")
            assert observe(wrapper) == expected
            value.write_text("dirty" if dirty else "original")

    # If a dirty checkout changes between metadata and materialization, Nix
    # must either retain the captured content or reject its now-stale hash.
    value = git_source / "value"
    value.write_text("captured-before-materialization")
    work = root / "racing-work"
    work.mkdir()

    def change_after_metadata(*args, **kwargs):
        result = nix_json(*args, **kwargs)
        if args[:2] == ("flake", "metadata"):
            value.write_text("changed-before-materialization")
        return result

    with patch.object(flake, "nix_json", side_effect=change_after_metadata):
        try:
            backend, wrapper, record = prepare(f"git+file://{git_source}#fixture", work)
        except subprocess.CalledProcessError:
            assert not (work / "flake").exists()
            assert not (work / "source").exists()
        else:
            assert observe(wrapper)["value"] == "captured-before-materialization"

    # Exercise actual upstream generation deletion and garbage collection.
    # The fake backend supplies only profile location/current identity; all
    # profile and store mutations still go through the real Nix commands.
    profile = root / "profiles/home-manager"
    profile.parent.mkdir()
    paths = []
    for number in (1, 2):
        directory = root / f"generation-{number}"
        directory.mkdir()
        (directory / "value").write_text(str(number))
        path = Path(run(["nix-store", "--add", directory], capture=True).strip())
        assert path.parent == store
        paths.append(path)
        run(["nix-env", "--profile", profile, "--set", path])
    backend = SimpleNamespace(system=False, profile=lambda: profile,
                              active=lambda: paths[1], validate_user=lambda: None)
    args = argparse.Namespace(count=1, yes=True, dry_run=False)
    with contextlib.redirect_stdout(io.StringIO()):
        generation_gc(backend, args, lambda *a, **kw: True)
    assert not (profile.parent / "home-manager-1-link").is_symlink()
    assert (profile.parent / "home-manager-2-link").is_symlink()
    assert paths[0].exists()  # Removing a generation alone must not delete it.
    preview_output = io.StringIO()
    with contextlib.redirect_stdout(preview_output):
        store_gc(argparse.Namespace(dry_run=True, json=True), lambda *a, **kw: False)
    plan = json.loads(preview_output.getvalue())
    assert str(paths[0]) in plan["paths"]
    assert str(paths[1]) not in plan["paths"]
    assert plan["sizeEstimate"]["basis"] == "nar"
    assert plan["sizeEstimate"]["unmeasuredPaths"] == 0
    expected_size = sum(int(run(["nix-store", "--query", "--size", path], capture=True))
                        for path in plan["paths"])
    assert plan["sizeEstimate"]["bytes"] == expected_size > 0
    assert paths[0].exists()  # A size query and dry run must not collect it.
    with contextlib.redirect_stdout(io.StringIO()):
        store_gc(args, lambda *a, **kw: True)
    assert not paths[0].exists()
    assert paths[1].exists()
    print("Nixman isolated-store integration passed")
