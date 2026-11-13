# Risk-judge calibration

Measures the check-risk judge (`skills/stages/check/references/check-risk.md`) against the owner's own labels, so its verdict is a calibrated signal and not a guess. Issue #221 (partial).

**Status: labeled, not yet gating.** `labels.csv` holds the owner's labels and `predictions.csv` the judge's verdicts; `report.py <split>` prints the current rates. The owner labels PRs by hand; nobody else writes `labels.csv`, and nothing here generates, infers, or imports labels.

**The threshold gate is still open.** Auto-merge policy (`AGENTS.md` § Unattended Shipping) is not yet tied to a measured rate. Three things block it: no threshold is agreed, the owner has not confirmed that it applies to TPR (§ Metrics), and the `test` split holds no `needs-review` label, so its TPR reads `n/a`.

## Files

| File | Role |
|---|---|
| `labels.csv` | The owner's labels: `pr,label,labeler,date` |
| `candidates.csv` | Merged PRs to choose from, no labels (written by `collect.py`) |
| `predictions.csv` | The judge's verdict per labeled PR: `pr,prediction` (produced per judge run) |
| `collect.py` | Lists merged PRs with diff stats via `gh` |
| `report.py` | Prints TPR/TNR with n for one split |
| `test_report.py` | Unit tests for the report math, on synthetic data that never touches `labels.csv` |

## Label format

`labels.csv`, one row per PR, CSV with this header:

```csv
pr,label,labeler,date
```

- `pr`: merged PR number.
- `label`: `low` (safe to auto-merge) or `needs-review` (a person should read it). Nothing else.
- `labeler`: who judged it. The protocol requires the owner.
- `date`: `YYYY-MM-DD` the label was written.

Label from the diff and the repository's rules, before reading the judge's verdict, so the label is independent of the judge.

## Protocol

1. `python3 -I evals/risk-judge/collect.py` writes `candidates.csv` (number, title, merge time, additions, deletions, files changed). It carries no labels.
2. The owner picks at least 40 historical PRs and labels each `low` or `needs-review` in `labels.csv`. Include enough of both classes that each split holds some of each; a split with none of a class reports `n/a` for that rate.
3. Splits are fixed by a seeded hash of the PR number, so a label never moves between splits: `sha256("risk-judge-v1:<pr>")`, first 8 bytes as a big-endian integer, mod 100. Below 60 is `train`, below 80 is `dev`, the rest is `test`. The seed lives in `report.py` (`SEED`); changing it re-splits everything and invalidates past results.
4. Tune the judge prompt against `train` and `dev`. Read `test` once, when the prompt is final.
5. Run the judge on each labeled PR as `check-risk.md` § Judge describes (fresh-context judge, the PR's `## Risk` verdict line). The LLM judge is not scriptable from this directory, so its verdicts go in `predictions.csv`: `pr,prediction` with `prediction` of `low` (verdict `low risk`) or `needs-review` (verdict `needs review`).
6. `python3 -I evals/risk-judge/report.py <train|dev|test>` prints the report.

## Metrics

The positive class is `needs-review`.

- **TPR** = needs-review PRs the judge called `needs-review` / all PRs labeled `needs-review`. A low TPR means the judge waves risky PRs through; auto-merge safety rests on this rate.
- **TNR** = `low` PRs the judge called `low` / all PRs labeled `low`. A low TNR means the judge sends safe PRs to a person; it costs time, not safety.

Issue #221 says "TNR on needs-review", which is ambiguous between the two. This README fixes the definitions above; the owner should confirm that TPR is the rate the threshold applies to.

`report.py` exits 0 with a report, 1 when the split has no labels (`no labels yet (n=0)`), and 2 on bad input: a missing or malformed file, a label outside the two classes, a duplicate PR, or a labeled PR with no prediction.

## Tests

```bash
python3 -I evals/risk-judge/test_report.py
```

## Mutation testing

The nightly `mutants-nightly` workflow (`.github/workflows/mutants-nightly.yml`) runs `cargo mutants --in-place` on `cli/src/installer`, writes the caught/missed/timeout/unviable counts to the run summary, and uploads the report as an artifact. It does not gate PRs. `--in-place` is required: the crate's tests read files outside `cli/`, so cargo-mutants' default copy of `cli/` fails the unmutated baseline.
