"""Preview bounded cleanup plans; let Nix enforce profile and store liveness."""
from .profiles import fingerprint, generations
from .runtime import Error, executable, nix, run


def generation_plan(backend, count):
    available = sorted(generations(backend), key=lambda generation: generation.id)
    eligible = [generation for generation in available if not generation.active and not generation.selected]
    return eligible if count is None else eligible[:count]


def generation_gc(backend, args, confirm):
    backend.validate_user()
    if backend.active() is None:
        raise Error("Cannot identify the running configuration. Refusing to delete generation links.")
    initial = fingerprint(backend)
    plan = generation_plan(backend, args.count)
    print("Generation cleanup plan (oldest first):")
    for generation in plan:
        print(f"  - {generation.id:<8} {generation.date}  {generation.path}")
    print(f"\nDelete {len(plan)} generation(s). Active and selected generations are protected.")
    print("Store objects remain until garbage collection. Deleted generation numbers cannot be restored.")
    if not plan or args.dry_run:
        print("No generations deleted.")
        return
    if not confirm(args.yes, destructive=True):
        print("Cancelled; no generations deleted.")
        return
    if fingerprint(backend) != initial or generation_plan(backend, args.count) != plan:
        raise Error("Generations changed during preview. Run generation gc again.")
    # Explicit IDs only: upstream's 'old' selector could remove the running
    # generation when the selected profile points at a different generation.
    run([executable("nix-env"), "--profile", backend.profile(), "--delete-generations",
         *[str(generation.id) for generation in plan]], privileged=backend.system)
    print(f"Deleted {len(plan)} generation(s). Run 'nixman gc' to preview store cleanup.")


def dead_paths():
    return sorted(set(run(["nix-store", "--gc", "--print-dead"], capture=True).splitlines()))


def store_gc(args, confirm):
    paths = dead_paths()
    if not paths:
        print("The Nix store has no unreachable paths to collect.")
        return
    print("Store cleanup plan (unreachable paths only):")
    for path in paths:
        print(f"  - {path}")
    print(f"\nCollect {len(paths)} unreachable path(s) using Nix garbage collection.")
    print("Generation links are not removed. Nix still checks GC roots before deletion.")
    if args.dry_run:
        print("Preview complete; no store paths deleted.")
        return
    if not confirm(args.yes, destructive=True):
        print("Cancelled; no store paths deleted.")
        return
    still_dead = set(dead_paths())
    if set(paths) != still_dead:
        raise Error("The store cleanup plan changed during preview. Run gc again.")
    # Native GC also handles unregistered build remnants and stale lock files.
    # Keep that policy in Nix, including root checks and the actual byte count.
    nix("store", "gc")
    print("Store garbage collection complete.")
