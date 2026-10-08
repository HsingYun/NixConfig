"""Process execution. Commands are always argument arrays, never shell text."""
import json
import os
import shutil
import subprocess


# A dirty local Git tree is valid for upstream rebuild tools. Only disposable
# wrappers use this option; the captured narHash and source dependency lock
# remain enforced.
WRAPPER_OPTIONS = ["--option", "allow-dirty-locks", "true"]


class Error(Exception):
    pass


def run(args, *, capture=False, privileged=False, input=None):
    args = [str(arg) for arg in args]
    if privileged and os.geteuid() != 0:
        args = ["sudo", "--", *args]
    result = subprocess.run(args, check=True, text=True, input=input,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def nix(*args, capture=False, input=None):
    return run(["nix", "--extra-experimental-features", "nix-command flakes", *args],
               capture=capture, input=input)


def nix_json(*args, input=None):
    return json.loads(nix(*args, capture=True, input=input))


def executable(name):
    found = shutil.which(name)
    if not found:
        raise Error(f"Required upstream tool is missing: {name}")
    return found
