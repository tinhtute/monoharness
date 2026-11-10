#!/usr/bin/env python3
"""List merged PRs as labeling candidates. Writes no labels.

Usage: python3 -I evals/risk-judge/collect.py [--limit N] [--out FILE] [--repo OWNER/NAME]

Calls `gh pr list --state merged` and writes candidates.csv with
pr,title,merged_at,additions,deletions,changed_files. The owner picks PRs from
it and writes labels.csv by hand; nothing here assigns or guesses a label.
"""
import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

FIELDS = ["pr", "title", "merged_at", "additions", "deletions", "changed_files"]


def rows_from_gh(prs):
    """Map the `gh pr list --json` records to candidate rows, oldest PR first."""
    rows = [
        {
            "pr": p["number"],
            "title": p["title"],
            "merged_at": p["mergedAt"],
            "additions": p["additions"],
            "deletions": p["deletions"],
            "changed_files": p["changedFiles"],
        }
        for p in prs
    ]
    return sorted(rows, key=lambda r: r["pr"])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--limit", type=int, default=300)
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent / "candidates.csv"))
    ap.add_argument("--repo", default=None, help="OWNER/NAME; default is the current repository")
    args = ap.parse_args(argv)

    cmd = [
        "gh", "pr", "list", "--state", "merged", "--limit", str(args.limit),
        "--json", "number,title,mergedAt,additions,deletions,changedFiles",
    ]
    if args.repo:
        cmd += ["--repo", args.repo]
    try:
        out = subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        detail = getattr(e, "stderr", "") or e
        print(f"collect: gh failed: {detail}", file=sys.stderr)
        return 2

    rows = rows_from_gh(json.loads(out))
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {len(rows)} candidates to {args.out} (no labels)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
