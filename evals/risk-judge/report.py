#!/usr/bin/env python3
"""Report TPR/TNR of the risk judge against the owner's labels for one split.

Usage: python3 -I evals/risk-judge/report.py <train|dev|test>
           [--labels labels.csv] [--predictions predictions.csv]

Positive class is `needs-review`.
  TPR = needs-review PRs the judge called needs-review / all needs-review PRs
  TNR = low PRs the judge called low / all low PRs
A judge that waves a risky PR through lowers TPR; auto-merge safety rests on it.

labels.csv:      pr,label,labeler,date   (owner-written; never generated)
predictions.csv: pr,prediction           (the judge's verdict per labeled PR)

Exit 0 on a report, 1 when the split has no labels (n=0), 2 on bad input.
"""
import argparse
import csv
import hashlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED = "risk-judge-v1"
CLASSES = ("low", "needs-review")
SPLITS = ("train", "dev", "test")


def split_of(pr, seed=SEED):
    """Fixed split: sha256("<seed>:<pr>") mod 100 -> <60 train, <80 dev, else test."""
    h = int.from_bytes(hashlib.sha256(f"{seed}:{pr}".encode()).digest()[:8], "big") % 100
    return "train" if h < 60 else "dev" if h < 80 else "test"


def read_rows(path, required):
    with open(path, newline="") as f:
        r = csv.DictReader(f)
        missing = [c for c in required if c not in (r.fieldnames or [])]
        if missing:
            raise ValueError(f"{path}: missing column(s) {', '.join(missing)}")
        return list(r)


def load_map(rows, column, source):
    """pr -> class, rejecting bad classes and duplicate PRs."""
    out = {}
    for r in rows:
        pr, val = r["pr"].strip(), r[column].strip()
        if val not in CLASSES:
            raise ValueError(f"{source}: PR {pr} has {column} {val!r}, expected one of {CLASSES}")
        if pr in out:
            raise ValueError(f"{source}: PR {pr} appears twice")
        out[pr] = val
    return out


def rates(labels, preds):
    """Confusion counts and rates; a rate is None when its denominator is 0."""
    tp = sum(1 for p, l in labels.items() if l == "needs-review" and preds[p] == "needs-review")
    fn = sum(1 for p, l in labels.items() if l == "needs-review" and preds[p] == "low")
    tn = sum(1 for p, l in labels.items() if l == "low" and preds[p] == "low")
    fp = sum(1 for p, l in labels.items() if l == "low" and preds[p] == "needs-review")
    return {
        "n": len(labels), "tp": tp, "fn": fn, "tn": tn, "fp": fp,
        "tpr": tp / (tp + fn) if tp + fn else None,
        "tnr": tn / (tn + fp) if tn + fp else None,
    }


def fmt(rate, hit, total, what):
    return f"{rate:.3f} ({hit}/{total})" if rate is not None else f"n/a (no {what} labels)"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("split", choices=SPLITS)
    ap.add_argument("--labels", default=str(HERE / "labels.csv"))
    ap.add_argument("--predictions", default=str(HERE / "predictions.csv"))
    args = ap.parse_args(argv)

    try:
        labels = load_map(read_rows(args.labels, ["pr", "label"]), "label", args.labels)
    except (OSError, ValueError) as e:
        print(f"report: {e}", file=sys.stderr)
        return 2
    labels = {p: l for p, l in labels.items() if split_of(p) == args.split}
    if not labels:
        print(f"no labels yet (n=0) for split '{args.split}': the owner writes {args.labels}; "
              "see evals/risk-judge/README.md", file=sys.stderr)
        return 1

    try:
        preds = load_map(read_rows(args.predictions, ["pr", "prediction"]), "prediction", args.predictions)
    except (OSError, ValueError) as e:
        print(f"report: {e}", file=sys.stderr)
        return 2
    missing = sorted(p for p in labels if p not in preds)
    if missing:
        print(f"report: no prediction for labeled PR(s): {', '.join(missing)}", file=sys.stderr)
        return 2

    m = rates(labels, preds)
    pos, neg = m["tp"] + m["fn"], m["tn"] + m["fp"]
    print(f"split={args.split} n={m['n']} (needs-review={pos}, low={neg})")
    print(f"TPR (needs-review caught): {fmt(m['tpr'], m['tp'], pos, 'needs-review')}")
    print(f"TNR (low passed):          {fmt(m['tnr'], m['tn'], neg, 'low')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
