"""Real Nix reference/profile/GC integration, exclusively in a disposable store."""
import argparse
import contextlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace

from nixman.backends import BACKENDS
from nixman.cleanup import generation_gc, store_gc
from nixman.flake import prepare, WRAPPER_OPTIONS
from nixman.runtime import nix, nix_json, run


def write_source(directory):
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
          };
        };
      };
    }''')


def observe(wrapper):
    return nix_json("eval", "--json", *WRAPPER_OPTIONS, "--no-update-lock-file",
                    f"{wrapper}#nixosConfigurations.nixman.observed")


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

    source = root / "path-source"
    write_source(source / "sub")
    work = root / "path-work"
    work.mkdir()
    wrapper, record = prepare(BACKENDS["nixos"], f"path:{source}?dir=sub", work)
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
    run(["git", "init", "--quiet", git_source])
    run(["git", "-C", git_source, "add", "."])
    run(["git", "-C", git_source, "-c", "user.name=Nixman Test", "-c", "user.email=test@example.invalid",
         "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "fixture"])
    revision = run(["git", "-C", git_source, "rev-parse", "HEAD"], capture=True).strip()
    for dirty in (False, True):
        work = root / ("dirty-work" if dirty else "git-work")
        work.mkdir()
        if dirty:
            (git_source / "value").write_text("dirty")
        wrapper, record = prepare(BACKENDS["nixos"], f"git+file://{git_source}#fixture", work)
        observed = observe(wrapper)
        assert observed["value"] == ("dirty" if dirty else "original")
        assert observed["dirtyRev" if dirty else "rev"] == revision + ("-dirty" if dirty else "")

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
    with contextlib.redirect_stdout(io.StringIO()):
        store_gc(args, lambda *a, **kw: True)
    assert not paths[0].exists()
    assert paths[1].exists()
    print("Nixman isolated-store integration passed")
