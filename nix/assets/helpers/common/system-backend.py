"""Observe native-system activation without granting ownership of resources.

Ports supply immutable plans, activation stages and read-only checks. Resource
ownership stays with their privileged reconcilers. This user-owned journal is
diagnostic only and must never authorize file deletion or service retirement.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from safe_files import lock, read, write


def now():
    return datetime.now(timezone.utc).isoformat()


def identity(pid):
    try:
        # comm can contain spaces and closing parentheses; starttime is field 22.
        stat = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        if stat[0] == "Z":
            return None
        return {"pid": pid, "start": stat[19],
                "boot": Path("/proc/sys/kernel/random/boot_id").read_text().strip()}
    except FileNotFoundError:
        return None


def desired(plan):
    return {name: resource["desired"] for name, resource in plan["resources"].items()}


def running(attempt):
    return any(process and identity(process["pid"]) == process
               for process in [attempt["process"], attempt.get("worker")])


class Backend:
    def __init__(self, plan, directory):
        self.plan = plan
        if plan.get("version") != 1 or not isinstance(plan.get("resources"), dict):
            raise ValueError("Unsupported native-system plan")
        self.plan_id = hashlib.sha256(json.dumps(plan, sort_keys=True).encode()).hexdigest()
        self.directory = Path(directory)
        self.path = self.directory / "state.json"

    def load(self):
        raw = read(self.path)
        state = json.loads(raw) if raw is not None else {"version": 1, "attempt": None, "successful": None}
        if state.get("version") != 1:
            raise ValueError("Unsupported native-system journal")
        return state

    def record(self, action, pid, stage=None, exit_code=None, worker=None):
        process = identity(pid)
        if process is None:
            raise RuntimeError("Activation process no longer exists")
        with lock(self.directory / "lock"):
            state = self.load()
            attempt = state["attempt"]
            if action == "begin":
                if attempt and attempt["status"] == "running" and running(attempt):
                    raise RuntimeError("Another activation is still running; refusing concurrent application")
                state["attempt"] = {
                    "plan": self.plan_id, "owner": self.plan["owner"], "host": self.plan["host"],
                    "process": process, "started": now(), "status": "running", "stage": None,
                    "completed": [], "desired": desired(self.plan),
                }
            else:
                if not attempt or attempt["plan"] != self.plan_id or attempt["process"] != process or attempt["status"] != "running":
                    raise RuntimeError("Journal does not belong to this active attempt")
                if stage is not None and stage not in self.plan["stages"] and stage != "verification":
                    raise ValueError(f"Unknown native-system stage: {stage}")
                if action == "stage-start":
                    if attempt["stage"] is not None:
                        raise RuntimeError("The previous stage has not finished")
                    attempt["stage"] = stage
                    attempt["worker"] = identity(worker) if worker is not None else None
                    if worker is not None and attempt["worker"] is None:
                        raise RuntimeError("Activation worker no longer exists")
                elif action in {"stage-end", "failed"}:
                    if attempt["stage"] != stage:
                        raise RuntimeError("Stage result does not match the running stage")
                    if action == "failed":
                        attempt.update(status="failed", exitCode=exit_code, ended=now())
                    else:
                        attempt["completed"].append(stage)
                        attempt["stage"] = None
                        attempt["worker"] = None
                elif action == "complete":
                    if attempt["stage"] != "verification" or set(attempt["completed"]) != set(self.plan["stages"]):
                        raise RuntimeError("Cannot complete an unfinished native-system plan")
                    attempt.update(status="succeeded", stage=None, worker=None, ended=now())
                    state["successful"] = {"plan": self.plan_id, "desired": desired(self.plan), "ended": now()}
                else:
                    raise ValueError(f"Unknown journal operation: {action}")
            write(self.path, json.dumps(state, sort_keys=True) + "\n")

    def status(self):
        state = self.load()
        attempt = state["attempt"]
        if attempt and attempt["status"] == "running" and not running(attempt):
            attempt["status"] = "interrupted"
        return {"selectedPlan": self.plan_id, **state}

    def diff(self):
        successful = self.load()["successful"]
        previous = successful["desired"] if successful else {}
        current = desired(self.plan)
        return {name: {"previous": previous.get(name), "desired": current.get(name),
                       "change": "added" if name not in previous else "removed" if name not in current else "changed"}
                for name in sorted(previous.keys() | current.keys())
                if name not in previous or name not in current or previous[name] != current[name]}

    def verify(self):
        results = {}
        for name, resource in self.plan["resources"].items():
            check = resource.get("check")
            if check is None:
                results[name] = {"status": "unchecked"}
                continue
            try:
                result = subprocess.run([check], capture_output=True, text=True, timeout=60)
                results[name] = {"status": "passed" if result.returncode == 0 else "failed",
                                 "exitCode": result.returncode, "output": result.stdout + result.stderr}
            except (OSError, subprocess.TimeoutExpired) as error:
                results[name] = {"status": "failed", "output": str(error)}
        return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    sub = parser.add_subparsers(dest="action", required=True)
    for name in ["plan", "status", "diff", "verify"]:
        sub.add_parser(name)
    for name in ["begin", "stage-start", "stage-end", "failed", "complete"]:
        command = sub.add_parser(name)
        command.add_argument("--pid", type=int, required=True)
        if name in {"stage-start", "stage-end", "failed"}:
            command.add_argument("--stage", required=True)
        if name == "stage-start":
            command.add_argument("--worker", type=int)
        if name == "failed":
            command.add_argument("--exit-code", type=int, required=True)
    args = parser.parse_args()
    backend = Backend(json.loads(args.plan.read_text()), args.state)
    if args.action == "plan":
        output = backend.plan
    elif args.action == "status":
        output = backend.status()
    elif args.action == "diff":
        output = backend.diff()
    elif args.action == "verify":
        output = backend.verify()
    else:
        backend.record(args.action, args.pid, getattr(args, "stage", None), getattr(args, "exit_code", None), getattr(args, "worker", None))
        return 0
    print(json.dumps(output, indent=2, sort_keys=True))
    return int(args.action == "verify" and any(result["status"] == "failed" for result in output.values()))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError) as error:
        print(f"Native system: {error}", file=sys.stderr)
        raise SystemExit(1)
