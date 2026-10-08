"""Preview bounded cleanup plans; let Nix enforce profile and store liveness."""
import subprocess
import time

from .profiles import fingerprint, generations
from .inspection import envelope, emit_json, generation_data
from .runtime import Error, executable, nix, nix_json, run
from .terminal import emit


def generation_plan(backend, count, *, keep=None, cutoff=None):
    available = sorted(generations(backend), key=lambda generation: generation.id)
    retained = {gen.id for gen in available[-keep:]} if keep else set()
    eligible = [generation for generation in available
                if not generation.active and not generation.selected and generation.id not in retained
                and (cutoff is None or (generation.created_at is not None and generation.created_at < cutoff))]
    return eligible if count is None else eligible[:count]


def generation_gc(backend, args, confirm):
    keep, age = getattr(args, "keep", None), getattr(args, "older_than", None)
    if args.count is not None and (keep is not None or age is not None):
        raise Error("--oldest cannot be combined with --keep or --older-than.")
    json_output = getattr(args, "json", False)
    if json_output and not args.dry_run:
        raise Error("Cleanup --json requires --dry-run; it never approves deletion.")
    backend.validate_user()
    if backend.active() is None:
        raise Error("Cannot identify the running configuration. Refusing to delete generation links.")
    initial = fingerprint(backend)
    # Capture the age boundary once, so time spent reviewing cannot grow the plan.
    cutoff = time.time() - age if age is not None else None
    plan = generation_plan(backend, args.count, keep=keep, cutoff=cutoff)
    if json_output:
        emit_json(envelope("generation gc", backend=backend.name, profile=str(backend.profile()),
                           dryRun=True, policy={"oldest": args.count, "keep": keep,
                                                "olderThanSeconds": age, "cutoff": cutoff},
                           generations=[generation_data(gen) for gen in plan]))
        return
    emit("Generation cleanup plan (oldest first):", "heading")
    if keep is not None:
        print(f"Keep the newest {keep} generation(s), plus any older active or selected generations.")
    if age is not None:
        print(f"Only generations older than {age} seconds at preview time are eligible.")
    for generation in plan:
        emit(f"  - {generation.id:<8} {generation.date}  {generation.path}", "remove")
    emit(f"\nDelete {len(plan)} generation(s). Active and selected generations are protected.", "warning")
    print("Store objects remain until garbage collection. Deleted generation numbers cannot be restored.")
    if not plan or args.dry_run:
        print("No generations deleted.")
        return
    if not confirm(args.yes, destructive=True):
        print("Cancelled; no generations deleted.")
        return
    if fingerprint(backend) != initial or generation_plan(backend, args.count, keep=keep, cutoff=cutoff) != plan:
        raise Error("Generations changed during preview. Run generation gc again.")
    # Explicit IDs only: upstream's 'old' selector could remove the running
    # generation when the selected profile points at a different generation.
    run([executable("nix-env"), "--profile", backend.profile(), "--delete-generations",
         *[str(generation.id) for generation in plan]], privileged=backend.system)
    emit(f"Deleted {len(plan)} generation(s). Run 'nixman gc' to preview store cleanup.", "success")


def dead_paths():
    return sorted(set(run(["nix-store", "--gc", "--print-dead"], capture=True).splitlines()))


def estimate_store_size(paths):
    """Sum each planned path's NAR size once, without traversing closures."""
    paths = sorted(set(paths))
    estimate = {"bytes": None, "basis": "nar", "unmeasuredPaths": len(paths)}
    if not paths:
        return {**estimate, "bytes": 0}
    try:
        # stdin avoids ARG_MAX for large stores. Nix supplies cached metadata;
        # no filesystem walk, build, substitution or recursive closure query.
        info = nix_json("path-info", "--json", "--json-format", "1", "--stdin",
                        input="\n".join(paths) + "\n")
        if not isinstance(info, dict):
            return estimate
        sizes = []
        for path in paths:
            item = info.get(path)
            size = item.get("narSize") if isinstance(item, dict) else None
            if type(size) is int and size >= 0:
                sizes.append(size)
        # Native GC also lists unregistered build remnants and lock files.
        # They have no NAR metadata; make the unmeasured portion explicit.
        return {**estimate, "bytes": sum(sizes) if sizes else None,
                "unmeasuredPaths": len(paths) - len(sizes)}
    except (OSError, ValueError, subprocess.CalledProcessError):
        # Concurrent GC or unavailable metadata must not masquerade as zero.
        # The existing plan recheck and native GC still protect live paths.
        return estimate


def format_size(size):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"):
        if size < 1024 or unit == "EiB":
            return f"{size:.2f} {unit}"
        size /= 1024


def store_gc(args, confirm):
    json_output = getattr(args, "json", False)
    if json_output and not args.dry_run:
        raise Error("Cleanup --json requires --dry-run; it never approves deletion.")
    paths = dead_paths()
    size_estimate = estimate_store_size(paths)
    if json_output:
        emit_json(envelope("gc", dryRun=True, paths=paths,
                           sizeEstimate=size_estimate))
        return
    if not paths:
        print("The Nix store has no unreachable paths to collect.")
        return
    emit("Store cleanup plan (unreachable paths only):", "heading")
    for path in paths:
        emit(f"  - {path}", "remove")
    emit(f"\nCollect {len(paths)} unreachable path(s) using Nix garbage collection.", "warning")
    if size_estimate["bytes"] is None:
        emit("Estimated space to reclaim: unavailable (could not query path sizes).", "warning")
    else:
        emit(f"Estimated space to reclaim: {format_size(size_estimate['bytes'])} (NAR-based estimate).", "heading")
        if size_estimate["unmeasuredPaths"]:
            print(f"Estimate excludes {size_estimate['unmeasuredPaths']} path(s) without size metadata.")
        print("Actual disk space freed may differ due to hard links, compression and filesystem overhead.")
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
    emit("Store garbage collection complete.", "success")
