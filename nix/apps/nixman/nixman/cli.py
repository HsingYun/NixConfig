"""Public command line and the prepare/preview/confirm/activate transaction."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

from .backends import BACKENDS, detect
from .cleanup import generation_gc, store_gc
from .flake import build, prepare
from .preview import preview
from .profiles import fingerprint, generations, list_generations, metadata, select, generation_info
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


def update(backend, args):
    backend.validate_user()
    executable(backend.command)
    initial = fingerprint(backend)
    current = backend.active()
    reference = args.flake
    if reference is None:
        previous = metadata(current)
        if previous is None:
            raise Error("The active generation has no saved flake. Run 'nixman update FLAKE#HOST' once.")
        if previous.get("backend") != backend.name:
            raise Error("Saved flake belongs to a different backend; specify the flake explicitly.")
        reference = previous["flake"]
    with tempfile.TemporaryDirectory(prefix="nixman-") as temporary:
        directory = Path(temporary)
        wrapper, source = prepare(backend, reference, directory)
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


def status(backend):
    active = backend.active()
    profile = backend.profile()
    selected = profile.resolve() if profile.exists() else None
    print(f"Backend: {backend.name}\nProfile: {profile}")
    available = generations(backend)
    active_ids = ", ".join(str(gen.id) for gen in available if gen.active) or "unknown"
    selected_ids = ", ".join(str(gen.id) for gen in available if gen.selected) or "unknown"
    print(f"Active generation: {active_ids}\nSelected generation: {selected_ids}")
    print(f"Active path: {active or '(none)'}\nSelected path: {selected or '(none)'}")
    print(f"Profile matches running configuration: {active is not None and active == selected}")
    data = metadata(active)
    if data:
        print(f"Default update source: {data['flake']}")
        print(f"Recorded revision: {data.get('revision') or '(not available)'}")
    else:
        print("Default update source: unavailable; supply FLAKE#HOST on the first update")


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


def parser():
    result = argparse.ArgumentParser(
        prog="nixman", formatter_class=argparse.RawDescriptionHelpFormatter,
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
  nixman status
  nixman generation list
  nixman generation info 12
  nixman generation diff 11 12
  nixman generation switch 11
  nixman rollback
  nixman generation gc 3
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
  Generations are Nix configurations, not filesystem snapshots. Native package
  versions, application data and arbitrary activation effects are not rolled
  back. Run nixman as your normal user; system activation requests sudo.
""")
    result.add_argument("--version", action="version", version="nixman 0.1.0")
    result.add_argument("--backend", choices=BACKENDS, help="override automatic platform detection")
    commands = result.add_subparsers(dest="command", required=True)
    update_parser = commands.add_parser("update", help="refresh the source flake, preview, then switch")
    update_parser.add_argument("flake", nargs="?", help="FLAKE#HOST; defaults to the active generation's saved source")
    commands.add_parser("status", help="show active/selected generations and the saved update source")
    rollback_parser = commands.add_parser("rollback", help="preview and activate the generation before the running one")
    gc_parser = commands.add_parser("gc", help="preview and delete unreachable Nix store paths")
    generation_parser = commands.add_parser("generation", help="inspect or activate existing upstream generations")
    generations = generation_parser.add_subparsers(dest="generation_command", required=True)
    generations.add_parser("list", help="list generations and mark the active and selected ones")
    info = generations.add_parser("info", help="show generation provenance and native package declarations")
    info.add_argument("generation", type=int)
    diff = generations.add_parser("diff", help="compare two generations without activating either")
    diff.add_argument("before", type=int, help="baseline generation")
    diff.add_argument("after", type=int, help="candidate generation")
    switch_parser = generations.add_parser("switch", help="preview and activate a generation number")
    switch_parser.add_argument("generation", type=int)
    generation_gc = generations.add_parser("gc", help="delete the oldest N inactive generations; omit N for all inactive generations")
    generation_gc.add_argument("count", nargs="?", type=positive_count, metavar="N", help="number to delete, excluding active and selected generations")
    for command in (update_parser, switch_parser, rollback_parser):
        command.add_argument("--yes", "-y", action="store_true", help="explicitly approve activation without prompting")
        command.add_argument("--dry-run", action="store_true", help="build/preview only; do not activate")
    for command in (gc_parser, generation_gc):
        command.add_argument("--yes", "-y", action="store_true", help="explicitly approve deletion without prompting")
        command.add_argument("--dry-run", action="store_true", help="preview only; do not delete")
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command == "gc":
            store_gc(args, confirm)
            return 0
        backend = detect(args.backend)
        if args.command == "update":
            update(backend, args)
        elif args.command == "status":
            status(backend)
        elif args.command == "rollback":
            rollback(backend, args)
        elif args.generation_command == "list":
            list_generations(backend)
        elif args.generation_command == "info":
            generation_info(backend, args.generation)
        elif args.generation_command == "diff":
            preview(backend, select(backend, args.before).path, select(backend, args.after).path)
        elif args.generation_command == "gc":
            generation_gc(backend, args, confirm)
        else:
            switch(backend, args)
    except (Error, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"nixman: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError):
            print("If activation started, inspect 'generation list': upstream activation can fail after partially applying changes.", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nnixman: interrupted", file=sys.stderr)
        return 130
    return 0
