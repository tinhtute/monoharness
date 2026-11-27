#!/usr/bin/env python3
"""Report TPR/TNR of the risk judge against the owner's labels for one split.

Usage: python3 -I evals/risk-judge/report.py <train|dev|test|planted|gate>
           [--labels labels.csv] [--predictions predictions.csv]
           [--planted-dir planted/]

Positive class is `needs-review`.
  TPR = needs-review PRs the judge called needs-review / all needs-review PRs
  TNR = low PRs the judge called low / all low PRs
A judge that waves a risky PR through lowers TPR; auto-merge safety rests on it.

labels.csv:      pr,label,labeler,date   (owner-written; never generated)
predictions.csv: pr,prediction           (the judge's verdict per labeled PR)

`planted` reads planted/labels.csv and planted/predictions.csv (ids P01...,
never hash-split) and, when planted/facts.csv (pr,mechanical_hit) exists, also
the TPR of the needs-review patches with no mechanical risk-facts hit.
`gate` pools the test split and the planted split: PASS only when no
needs-review item is missed and there are at least MIN_POSITIVES of them.

Exit 0 on a report or a passing gate, 1 when the split has no labels (n=0),
2 on bad input, 3 on a failing gate.
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
MIN_POSITIVES = 20


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


def load_split(labels_path, preds_path, keep):
    """Labels kept by keep(pr) and their predictions; raises ValueError on bad input."""
    labels = load_map(read_rows(labels_path, ["pr", "label"]), "label", labels_path)
    labels = {p: l for p, l in labels.items() if keep(p)}
    if not labels:
        return labels, {}
    preds = load_map(read_rows(preds_path, ["pr", "prediction"]), "prediction", preds_path)
    missing = sorted(p for p in labels if p not in preds)
    if missing:
        raise ValueError(f"no prediction for labeled PR(s): {', '.join(missing)}")
    return labels, preds


def load_facts(path):
    """pr -> True when risk-facts.sh raised a mechanical hit for that planted patch."""
    out = {}
    for r in read_rows(path, ["pr", "mechanical_hit"]):
        val = r["mechanical_hit"].strip()
        if val not in ("true", "false"):
            raise ValueError(f"{path}: {r['pr'].strip()} has mechanical_hit {val!r}, expected true or false")
        out[r["pr"].strip()] = val == "true"
    return out


def print_rates(name, m):
    pos, neg = m["tp"] + m["fn"], m["tn"] + m["fp"]
    print(f"split={name} n={m['n']} (needs-review={pos}, low={neg})")
    print(f"TPR (needs-review caught): {fmt(m['tpr'], m['tp'], pos, 'needs-review')}")
    print(f"TNR (low passed):          {fmt(m['tnr'], m['tn'], neg, 'low')}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("split", choices=SPLITS + ("planted", "gate"))
    ap.add_argument("--labels", default=str(HERE / "labels.csv"))
    ap.add_argument("--predictions", default=str(HERE / "predictions.csv"))
    ap.add_argument("--planted-dir", default=str(HERE / "planted"))
    args = ap.parse_args(argv)
    planted = Path(args.planted_dir)

    try:
        if args.split in SPLITS + ("gate",):
            split = "test" if args.split == "gate" else args.split
            labels, preds = load_split(args.labels, args.predictions, lambda p: split_of(p) == split)
        if args.split in ("planted", "gate"):
            pl, pp = load_split(planted / "labels.csv", planted / "predictions.csv", lambda p: True)
            pl = {f"planted:{p}": l for p, l in pl.items()}
            pp = {f"planted:{p}": v for p, v in pp.items()}
            facts_path = planted / "facts.csv"
            facts = load_facts(facts_path) if args.split == "planted" and facts_path.exists() else None
            if args.split == "planted":
                labels, preds = pl, pp
            else:
                labels, preds = labels | pl, preds | pp
    except (OSError, ValueError) as e:
        print(f"report: {e}", file=sys.stderr)
        return 2

    if not labels:
        where = planted / "labels.csv" if args.split == "planted" else args.labels
        print(f"no labels yet (n=0) for split '{args.split}': the owner writes {where}; "
              "see evals/risk-judge/README.md", file=sys.stderr)
        return 1

    m = rates(labels, preds)
    print_rates(args.split if args.split != "gate" else "test+planted", m)
    if args.split == "planted":
        if facts is None:
            print("TPR, no mechanical hit:   n/a (no facts.csv)")
        else:
            no_hit = {p: l for p, l in labels.items() if not facts.get(p.removeprefix("planted:"), True)}
            s = rates(no_hit, preds)
            pos = s["tp"] + s["fn"]
            print(f"TPR, no mechanical hit:   {fmt(s['tpr'], s['tp'], pos, 'needs-review')}")
    if args.split != "gate":
        return 0

    pos = m["tp"] + m["fn"]
    missed = sorted(p.removeprefix("planted:") for p, l in labels.items()
                    if l == "needs-review" and preds[p] == "low")
    if missed or pos < MIN_POSITIVES:
        why = [f"missed {', '.join(missed)}"] if missed else []
        if pos < MIN_POSITIVES:
            why.append(f"needs-review={pos} < {MIN_POSITIVES}")
        print(f"gate: FAIL ({'; '.join(why)})")
        return 3
    print(f"gate: PASS (0 missed of needs-review={pos} >= {MIN_POSITIVES})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
