"""Public command line and the prepare/preview/confirm/activate transaction."""
import argparse
import re
from pathlib import Path
import subprocess
import sys
import tempfile

from .backends import detect
from .cleanup import generation_gc, store_gc
from .flake import build, prepare
from .preview import preview
from .profiles import fingerprint, generations, metadata, select
from .inspection import (status_data, list_data, info_data, display_status, display_list,
                         display_info, emit_json, envelope)
from .runtime import Error, executable, run


def confirm(yes, destructive=False, no_changes=False):
    if yes:
        return True
    if not sys.stdin.isatty():
        raise Error("Confirmation requires a terminal. Use --yes to explicitly approve a noninteractive operation.")
    while True:
        try:
            prompt = "\nProceed with deletion? [y/N] " if destructive else "\nProceed with activation? [Y/n] "
            if no_changes and not destructive:
                prompt = "\nContinue with activation and generation registration? [Y/n] "
            answer = input(prompt).strip().lower()
        except EOFError:
            return False
        if answer == "":
            return not destructive
        if answer in ("y", "yes"):
            return True
        if answer in ("n", "no"):
            return False


def unchanged(backend, initial):
    if fingerprint(backend) != initial:
        raise Error("The active configuration or profile changed during preview. Run nixman again before applying.")


def update(args):
    reference = args.flake
    remembered_backend = None
    if reference is None:
        remembered_backend = detect()
        previous = metadata(remembered_backend.active())
        if previous is None:
            raise Error("The active generation has no saved flake. Run 'nixman update FLAKE#HOST' once.")
        if previous.get("backend") != remembered_backend.name:
            raise Error("Saved flake belongs to a different backend; specify the flake explicitly.")
        reference = previous["flake"]
    with tempfile.TemporaryDirectory(prefix="nixman-") as temporary:
        directory = Path(temporary)
        backend, wrapper, source = prepare(reference, directory)
        if remembered_backend is not None and backend.name != remembered_backend.name:
            raise Error("The saved source now selects a different backend. Specify the flake explicitly.")
        backend.validate_user()
        executable(backend.command)
        initial = fingerprint(backend)
        current = backend.active()
        print(f"Backend: {backend.name}\nSource: {source['flake']}", flush=True)
        candidate = build(backend, wrapper, directory)
        changed = preview(backend, current, candidate)
        if args.dry_run:
            print("\nPreview complete; no activation performed.")
            return
        unchanged(backend, initial)
        if not confirm(args.yes, no_changes=changed is False):
            print("Cancelled; no activation performed.")
            return
        unchanged(backend, initial)
        backend.update(wrapper)
        if backend.active() != candidate:
            raise Error("The upstream command completed, but the active generation does not match the preview. Inspect 'generation list'.")
        print("\nActivation complete. The source flake is saved in this generation.")


def switch(backend, args):
    backend.validate_user()
    initial = fingerprint(backend)
    generation = select(backend, args.generation)
    # Keep even an old generation alive through preview and activation if a
    # concurrent garbage collector removes its normal profile root.
    with tempfile.TemporaryDirectory(prefix="nixman-") as temporary:
        run(["nix-store", "--realise", generation.path, "--add-root", Path(temporary) / "generation"], capture=True)
        preview(backend, backend.active(), generation.path)
        if args.dry_run:
            print("\nPreview complete; no activation performed.")
            return
        unchanged(backend, initial)
        if not confirm(args.yes):
            print("Cancelled; no activation performed.")
            return
        unchanged(backend, initial)
        if select(backend, args.generation).path != generation.path:
            raise Error("The requested generation changed during preview.")
        backend.switch(backend.profile(), generation)
        if backend.active() != generation.path:
            raise Error("Activation did not select the expected running generation. Inspect 'generation list'.")
        print(f"\nActivated generation {generation.id}.")


def rollback(backend, args):
    available = generations(backend)
    current = next((gen for gen in available if gen.active and gen.selected), None)
    current = current or next((gen for gen in available if gen.active), None)
    if current is None:
        raise Error("The running configuration is not an available generation. Use generation switch with an explicit ID.")
    previous = next((gen for gen in available if gen.id < current.id and gen.path.exists()), None)
    if previous is None:
        raise Error("No earlier available generation exists.")
    args.generation = previous.id
    print(f"Rollback: generation {current.id} -> {previous.id}")
    switch(backend, args)


def positive_count(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("count must be a positive integer")
    return number


def nonnegative_count(value):
    number = int(value)
    if number < 0:
        raise argparse.ArgumentTypeError("count must be a nonnegative integer")
    return number


def age_seconds(value):
    match = re.fullmatch(r"([1-9][0-9]{0,8})(h|d|w)", value)
    if match is None:
        raise argparse.ArgumentTypeError("age must be a positive whole number followed by h, d or w (for example 30d)")
    return int(match[1]) * {"h": 3600, "d": 86400, "w": 604800}[match[2]]


def parser():
    result = argparse.ArgumentParser(
        prog="nixman", allow_abbrev=False, formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Preview, activate and maintain Nix system and home generations.",
        epilog="""Platform backends:
  NixOS / NixOS-WSL   nixos-rebuild
  macOS               darwin-rebuild
  Other Linux         Home Manager (native system steps may request sudo)

Examples:
  nixman update 'github:HsingYun/NixConfig/master#Darwin'
  nixman update './configuration#ArchLinux'
  nixman update 'git+ssh://git@example.com/config?ref=main#host'
  nixman update --dry-run
  nixman status --json
  nixman generation list
  nixman generation info 12
  nixman generation diff 11 12
  nixman generation switch 11
  nixman rollback
  nixman generation gc --oldest 3
  nixman generation gc --keep 5 --older-than 30d
  nixman completion zsh
  nixman gc --dry-run

Behavior:
  Updates refresh the source flake, not its locked dependencies. The preview
  builds an immutable candidate before activation. The source is saved in that
  generation; omitting FLAKE reuses the running generation's source.
  Activation prompts default to yes [Y/n]; deletion prompts default to no
  [y/N]. Noninteractive changes require --yes. --dry-run never activates or
  deletes, but update --dry-run may download/build store objects for preview.
  Generation cleanup removes generation links; store cleanup removes unreachable
  store objects. Active and selected generations are protected.
  The update backend is inferred from the selected flake output collection;
  generation operations identify the existing upstream configuration.
  Generations are Nix configurations, not filesystem snapshots. Native package
  versions, application data and arbitrary activation effects are not rolled
  back. Run nixman as your normal user; system activation requests sudo.
""")
    result.add_argument("--version", action="version", version="nixman 0.1.0")
    commands = result.add_subparsers(dest="command", required=True)
    update_parser = commands.add_parser("update", help="refresh the source flake, preview, then switch")
    update_parser.add_argument("flake", nargs="?", help="FLAKE#HOST; defaults to the active generation's saved source")
    status_parser = commands.add_parser("status", help="show active/selected generations and the saved update source")
    completion_parser = commands.add_parser("completion", help="print a packaged shell completion script")
    completion_parser.add_argument("shell", choices=("bash", "zsh", "fish"))
    rollback_parser = commands.add_parser("rollback", help="preview and activate the generation before the running one")
    gc_parser = commands.add_parser("gc", help="preview and delete unreachable Nix store paths")
    generation_parser = commands.add_parser("generation", help="inspect or activate existing upstream generations")
    generations = generation_parser.add_subparsers(dest="generation_command", required=True)
    list_parser = generations.add_parser("list", help="list generations and mark the active and selected ones")
    info = generations.add_parser("info", help="show generation provenance and native package declarations")
    info.add_argument("generation", type=int)
    diff = generations.add_parser("diff", help="compare two generations without activating either")
    diff.add_argument("before", type=int, help="baseline generation")
    diff.add_argument("after", type=int, help="candidate generation")
    switch_parser = generations.add_parser("switch", help="preview and activate a generation number")
    switch_parser.add_argument("generation", type=int)
    generation_gc = generations.add_parser(
        "gc", help="preview and delete unprotected generations using retention policies",
        description="Without a policy, select all unprotected historical generations. "
                    "Active and selected generations are always protected. "
                    "Preview precedes confirmation, which defaults to no [y/N].")
    generation_gc.add_argument("--oldest", dest="count", type=positive_count, metavar="N",
                               help="delete the oldest N eligible generations; cannot combine with retention policies")
    generation_gc.add_argument("--keep", type=nonnegative_count, metavar="N",
                               help="retain the newest N generations overall, plus active/selected generations")
    generation_gc.add_argument("--older-than", type=age_seconds, metavar="AGE",
                               help="delete only generations older than AGE (24h, 30d, 4w); intersects with --keep")
    for command in (status_parser, list_parser, info):
        command.add_argument("--json", action="store_true", help="write a versioned JSON result to stdout")
    for command in (gc_parser, generation_gc):
        command.add_argument("--json", action="store_true", help="write a JSON cleanup plan; requires --dry-run")
    for command in (update_parser, switch_parser, rollback_parser):
        command.add_argument("--yes", "-y", action="store_true", help="explicitly approve activation without prompting")
        command.add_argument("--dry-run", action="store_true", help="build/preview only; do not activate")
    for command in (gc_parser, generation_gc):
        command.add_argument("--yes", "-y", action="store_true", help="explicitly approve deletion without prompting")
        command.add_argument("--dry-run", action="store_true", help="preview only; do not delete")
    return result


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "__complete":
        from .completion import complete
        for candidate in complete(argv[1:], parser()):
            print(candidate)
        return 0
    args = parser().parse_args(argv)
    try:
        if args.command == "gc":
            store_gc(args, confirm)
            return 0
        if args.command == "completion":
            from .completion import script
            print(script(args.shell), end="")
            return 0
        if args.command == "update":
            update(args)
            return 0
        backend = detect()
        if args.command == "status":
            data = status_data(backend)
            (emit_json if args.json else display_status)(data)
        elif args.command == "rollback":
            rollback(backend, args)
        elif args.generation_command == "list":
            data = list_data(backend)
            (emit_json if args.json else display_list)(data)
        elif args.generation_command == "info":
            data = info_data(backend, args.generation)
            (emit_json if args.json else display_info)(data)
        elif args.generation_command == "diff":
            preview(backend, select(backend, args.before).path, select(backend, args.after).path)
        elif args.generation_command == "gc":
            generation_gc(backend, args, confirm)
        else:
            switch(backend, args)
    except (Error, OSError, ValueError, subprocess.CalledProcessError) as exc:
        if getattr(args, "json", False):
            command = " ".join(filter(None, (args.command, getattr(args, "generation_command", None))))
            emit_json(envelope(command, error={"message": str(exc)}))
        print(f"nixman: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError):
            print("If activation started, inspect 'generation list': upstream activation can fail after partially applying changes.", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nnixman: interrupted", file=sys.stderr)
        return 130
    return 0
