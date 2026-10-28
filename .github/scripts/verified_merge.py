"""Reuse PR checks only when the pushed commit has the same verified Git tree."""

import json
import os
import subprocess
from pathlib import Path


def api(path, *, pages=False):
    command = ["gh", "api", path]
    if pages:
        command += ["--paginate", "--slurp"]
    return json.loads(subprocess.check_output(command, text=True))


def verified_merge(request, repo, sha, branch):
    pulls = request(f"repos/{repo}/commits/{sha}/pulls", pages=True)
    for page in pulls:
        for pull in page:
            if not (
                pull["merged_at"]
                and pull["merge_commit_sha"] == sha
                and pull["base"]["repo"]["full_name"] == repo
                and pull["base"]["ref"] == branch
            ):
                continue
            head = pull["head"]["sha"]
            merged_tree = request(f"repos/{repo}/git/commits/{sha}")["tree"]["sha"]
            checked_tree = request(f"repos/{repo}/git/commits/{head}")["tree"]["sha"]
            if merged_tree != checked_tree:
                continue
            pages = request(
                f"repos/{repo}/commits/{head}/check-runs"
                "?check_name=Check%20complete&filter=latest&per_page=100",
                pages=True,
            )
            checks = [
                check
                for page in pages
                for check in page["check_runs"]
                if check["name"] == "Check complete"
                and check["head_sha"] == head
                and check["app"]["slug"] == "github-actions"
            ]
            if checks and all(
                check["status"] == "completed" and check["conclusion"] == "success"
                for check in checks
            ):
                return pull["number"]
    return None


def main():
    pull = None
    try:
        pull = verified_merge(
            api,
            os.environ["GITHUB_REPOSITORY"],
            os.environ["GITHUB_SHA"],
            os.environ["GITHUB_REF_NAME"],
        )
    except (subprocess.CalledProcessError, ValueError, KeyError, TypeError) as error:
        print(f"Could not verify previous checks ({type(error).__name__}); running full checks.")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write(f"verified={str(pull is not None).lower()}\n")
    message = (
        f"Reusing successful checks from PR #{pull}: the merged Git tree is identical."
        if pull is not None
        else "No verified identical PR tree found; running full checks."
    )
    print(message)
    with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
        summary.write(message + "\n")


if __name__ == "__main__":
    main()
