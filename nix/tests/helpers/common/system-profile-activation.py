"""Exercise production profile activation and GC in a disposable Nix store."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def run(*args, **kwargs):
    return subprocess.check_output([str(arg) for arg in args], text=True, **kwargs).strip()


with tempfile.TemporaryDirectory(prefix="native-profile-") as temporary:
    root = Path(temporary).resolve()
    store = root / "store"
    os.environ.update({
        "NIX_REMOTE": f"local?store={store}&state={root}/state&log={root}/log",
        "NIX_CONFIG": "experimental-features = nix-command flakes\nsubstituters =\n",
        "XDG_CACHE_HOME": str(root / "cache"),
    })
    assert run("nix", "eval", "--raw", "--expr", "builtins.storeDir") == str(store)
    profile = root / "state/profiles/native-system"
    home = root / "state/profiles/home-manager"
    profile.parent.mkdir(parents=True, exist_ok=True)
    template = Path(sys.argv[1]).read_text().replace("@PROFILE@", str(profile))
    source = root / "activation"
    source.write_text(template)
    packages, generations = [], []
    for number in (1, 2):
        payload = root / f"packages-{number}"
        payload.mkdir()
        (payload / "version").write_text(str(number))
        package = Path(run("nix-store", "--add", payload))
        packages.append(package)
        # Like HM's activation derivation, preserve the package set's string
        # context in the generation. Nix owns its transitive GC reachability.
        expression = (
            f'builtins.toFile "home-generation-{number}" '
            '(builtins.replaceStrings ["@PACKAGE_SET@"] '
            f'[(builtins.storePath {json.dumps(str(package))})] '
            f'(builtins.readFile {json.dumps(str(source))}))'
        )
        generation = Path(run("nix", "eval", "--impure", "--raw", "--expr", expression))
        generations.append(generation)
        before = sorted(profile.parent.glob("native-system-*-link"))
        run("bash", generation, env=os.environ | {"DRY_RUN": "1"})
        assert sorted(profile.parent.glob("native-system-*-link")) == before
        run("nix-env", "--profile", home, "--set", generation)
        run("bash", generation)
        assert profile.resolve() == package
        assert len(list(profile.parent.glob("native-system-*-link"))) == 1

    # An unchanged activation also retires pre-existing auxiliary history.
    run("nix-env", "--profile", profile, "--set", packages[0])
    run("nix-env", "--profile", profile, "--set", packages[1])
    assert len(list(profile.parent.glob("native-system-*-link"))) > 1
    run("bash", generations[1])
    assert len(list(profile.parent.glob("native-system-*-link"))) == 1
    before = profile.readlink()
    run("bash", generations[1])
    assert profile.readlink() == before

    # Both retained home generations protect their packages, despite the
    # auxiliary profile having only one selected generation.
    run("nix-store", "--gc")
    assert all(package.exists() for package in packages)
    run("nix-env", "--profile", home, "--switch-generation", "1")
    run("bash", generations[0])
    assert profile.resolve() == packages[0]
    run("nix-env", "--profile", home, "--switch-generation", "2")
    run("bash", generations[1])
    run("nix-env", "--profile", home, "--delete-generations", "1")
    run("nix-store", "--gc")
    assert not packages[0].exists()
    assert packages[1].exists()
    print("Native system packages follow retained Home Manager generations")
