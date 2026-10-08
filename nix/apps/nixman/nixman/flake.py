"""Freeze a source flake and extend its upstream module result with provenance."""
import json
from pathlib import Path
import re
import shutil
from urllib.parse import unquote, quote, urlsplit, parse_qsl

from .runtime import Error, nix, nix_json, run, WRAPPER_OPTIONS
from .backends import BACKENDS
from .terminal import emit


def normalize(reference):
    base, _, host = reference.partition("#")
    if not base or "\n" in reference or "\r" in reference or "\0" in reference:
        raise Error("Expected a flake reference or local directory, optionally followed by #HOST.")
    host = unquote(host)
    parsed = urlsplit(base)
    if (parsed.password or (parsed.scheme in ("http", "https", "git+http", "git+https") and parsed.username)
            or any(re.search(r"token|password|secret|credential|authorization", key, re.I)
                              for key, _ in parse_qsl(parsed.query))):
        raise Error("Flake references are stored publicly in the Nix store. Configure credentials in Nix, not in the reference.")
    # Let Nix parse every reference type and query parameter. In particular,
    # filesystem normalization must not turn '?dir=' into part of a filename.
    return base, host or None


def literal(value):
    if not isinstance(value, (str, bool, int)):
        raise Error("Unsupported Nix fetcher metadata value.")
    return json.dumps(value, ensure_ascii=False).replace("${", r"\${")


def choose_configuration(collections, host):
    candidates = [(BACKENDS[name], configuration) for name, names in collections.items()
                  for configuration in names if host is None or configuration == host]
    if host is None and len(candidates) > 1:
        candidates = [(backend, name) for backend, name in candidates if name in backend.default_names()]
    if len(candidates) != 1:
        available = ", ".join(f"{BACKENDS[name].collection}.{item}"
                              for name, names in collections.items() for item in names)
        raise Error(f"Cannot select a unique configuration{(' for #' + host) if host else ''}. "
                    "Use a unique #HOST. Available: " + (available or "(none)"))
    return candidates[0]


def prepare(reference, directory):
    base, host = normalize(reference)
    # Do not update the user's lock file, even in memory. --refresh refreshes
    # the requested source branch; dependency versions remain in flake.lock.
    details = nix_json("flake", "metadata", "--json", "--refresh",
                       "--no-update-lock-file", base)
    source_path = Path(details["path"])
    if not source_path.is_absolute() or not source_path.is_dir():
        raise Error("Nix did not return an available immutable source path.")
    run(["nix-store", "--realise", source_path, "--add-root", directory / "source"], capture=True)
    # Keep Nix's original fetcher and its locked metadata, including dir,
    # dirtyRev and lastModified. Recasting a Git flake as a path flake would
    # change self.sourceInfo and can change the user's configuration semantics.
    locked = {key: value for key, value in details["locked"].items() if key != "__final"}
    if "narHash" not in locked:
        raise Error("Nix did not return a content hash for the source flake.")
    source = {
        "flake": details["originalUrl"] + ("#" + quote(host, safe="@.+-_") if host else ""),
        "configuration": host,
        "lockedReference": details.get("url"),
        "revision": details.get("revision") or details.get("dirtyRevision") or locked.get("rev"),
        "sourceHash": locked["narHash"],
    }
    wrapper = directory / "flake"
    wrapper.mkdir()
    templates = Path(__file__).resolve().parent.parent / "templates"
    for template in templates.iterdir():
        if template.is_file():
            # copytree/copy2 would inherit the store's read-only directory
            # permissions, preventing request.json and flake.lock creation.
            shutil.copyfile(template, wrapper / template.name)
    (wrapper / "request.json").write_text(json.dumps(source) + "\n")
    (wrapper / "locked-input.json").write_text(json.dumps(locked) + "\n")
    # Flake inputs must be a literal attribute set, not a fromJSON thunk.
    # Encode its scalar metadata as Nix literals, escaping interpolation too.
    # Configuration names and generation provenance are still read as JSON.
    input_attrs = " ".join(f"{literal(key)} = {literal(value)};" for key, value in sorted(locked.items()))
    # Inspect only names in the pinned source, before evaluating a chosen host.
    collections = " ".join(
        f'"{name}" = builtins.attrNames (target.{backend.collection} or {{}});'
        for name, backend in BACKENDS.items())
    (wrapper / "flake.nix").write_text(f'''{{
  inputs.target = {{ {input_attrs} }};
  outputs = {{ target, ... }}: {{ lib.configurations = {{ {collections} }}; }};
}}
''')
    nix("flake", "lock", *WRAPPER_OPTIONS, str(wrapper))
    names = nix_json("eval", "--json", *WRAPPER_OPTIONS, "--no-update-lock-file",
                     f"{wrapper}#lib.configurations")
    backend, host = choose_configuration(names, host)
    source.update(configuration=host, flake=details["originalUrl"] + "#" + quote(host, safe="@.+-_"))
    (wrapper / "request.json").write_text(json.dumps(source) + "\n")
    (wrapper / "flake.nix").write_text(f'''{{
  inputs.target = {{ {input_attrs} }};
  outputs = {{ target, ... }}:
    let
      source = builtins.fromJSON (builtins.readFile ./request.json);
      original = builtins.getAttr source.configuration target.{backend.collection};
      configured = original.extendModules {{
        modules = [ (import ./generation.nix {{
          inherit source;
          backend = "{backend.name}";
        }}) ];
      }};
    in {{
      {backend.collection}.nixman = configured;
    }};
}}
''')
    return backend, wrapper, source


def build(backend, wrapper, directory):
    target = f"{wrapper}#{backend.collection}.nixman.{backend.output}"
    emit("\nBuild plan (dry run):", "heading", flush=True)
    nix("build", "--dry-run", "--no-link", *WRAPPER_OPTIONS, "--no-update-lock-file", target)
    print("\nBuilding the candidate for an exact preview; nothing is activated yet.", flush=True)
    result = nix_json("build", "--json", "--out-link", str(directory / "candidate"),
                      *WRAPPER_OPTIONS, "--no-update-lock-file", target)
    if len(result) != 1 or "out" not in result[0].get("outputs", {}):
        raise Error("Expected exactly one configuration output from Nix.")
    return Path(result[0]["outputs"]["out"])
