#!/usr/bin/env python3
"""Tests for report.py. Run: python3 -I evals/risk-judge/test_report.py

SYNTHETIC DATA ONLY. The PR numbers and labels below are invented to exercise
the arithmetic; they are not owner labels and are never written to labels.csv.
"""
import contextlib
import importlib.util
import io
import tempfile
import unittest
from unittest import mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("report", HERE / "report.py")
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

# SYNTHETIC: 4 needs-review (3 caught), 4 low (3 passed).
SYNTHETIC_LABELS = {
    "1": "needs-review", "2": "needs-review", "3": "needs-review", "4": "needs-review",
    "5": "low", "6": "low", "7": "low", "8": "low",
}
SYNTHETIC_PREDS = {
    "1": "needs-review", "2": "needs-review", "3": "needs-review", "4": "low",
    "5": "low", "6": "low", "7": "low", "8": "needs-review",
}


def write_csv(path, header, rows):
    path.write_text(header + "\n" + "".join(",".join(r) + "\n" for r in rows))


class RatesTest(unittest.TestCase):
    def test_synthetic_counts_and_rates(self):
        m = report.rates(SYNTHETIC_LABELS, SYNTHETIC_PREDS)
        self.assertEqual((m["n"], m["tp"], m["fn"], m["tn"], m["fp"]), (8, 3, 1, 3, 1))
        self.assertAlmostEqual(m["tpr"], 0.75)
        self.assertAlmostEqual(m["tnr"], 0.75)

    def test_empty_class_gives_none(self):
        m = report.rates({"1": "low"}, {"1": "low"})
        self.assertIsNone(m["tpr"])
        self.assertEqual(m["tnr"], 1.0)

    def test_split_is_deterministic_and_covers_all_three(self):
        seen = {report.split_of(str(n)) for n in range(1, 400)}
        self.assertEqual(seen, set(report.SPLITS))
        self.assertEqual(report.split_of("42"), report.split_of("42"))


class CliTest(unittest.TestCase):
    def run_main(self, argv):
        err = io.StringIO()
        out = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(out):
            rc = report.main(argv)
        return rc, out.getvalue(), err.getvalue()

    def test_header_only_labels_report_n0(self):
        with tempfile.TemporaryDirectory() as d:
            labels = Path(d) / "labels.csv"
            write_csv(labels, "pr,label,labeler,date", [])
            rc, _, err = self.run_main(["test", "--labels", str(labels)])
        self.assertEqual(rc, 1)
        self.assertIn("no labels yet (n=0)", err)

    def test_report_on_synthetic_split(self):
        split = report.split_of("1")
        labels = {p: l for p, l in SYNTHETIC_LABELS.items() if report.split_of(p) == split}
        with tempfile.TemporaryDirectory() as d:
            lp, pp = Path(d) / "labels.csv", Path(d) / "predictions.csv"
            write_csv(lp, "pr,label,labeler,date", [[p, l, "synthetic", "2000-01-01"] for p, l in labels.items()])
            write_csv(pp, "pr,prediction", [[p, SYNTHETIC_PREDS[p]] for p in labels])
            rc, out, _ = self.run_main([split, "--labels", str(lp), "--predictions", str(pp)])
        self.assertEqual(rc, 0)
        self.assertIn(f"n={len(labels)}", out)
        self.assertIn("TPR", out)

    def test_missing_prediction_is_an_error(self):
        split = report.split_of("1")
        with tempfile.TemporaryDirectory() as d:
            lp, pp = Path(d) / "labels.csv", Path(d) / "predictions.csv"
            write_csv(lp, "pr,label,labeler,date", [["1", "low", "synthetic", "2000-01-01"]])
            write_csv(pp, "pr,prediction", [])
            rc, _, err = self.run_main([split, "--labels", str(lp), "--predictions", str(pp)])
        self.assertEqual(rc, 2)
        self.assertIn("no prediction", err)

    def test_invalid_label_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            lp = Path(d) / "labels.csv"
            write_csv(lp, "pr,label,labeler,date", [["1", "maybe", "synthetic", "2000-01-01"]])
            rc, _, err = self.run_main(["test", "--labels", str(lp)])
        self.assertEqual(rc, 2)
        self.assertIn("expected one of", err)


def planted_dir(d, labels, preds, facts=None):
    """Write a synthetic planted/ directory: ids P01..., labels, predictions, optional facts."""
    p = Path(d) / "planted"
    p.mkdir()
    write_csv(p / "labels.csv", "pr,label,labeler,date", [[i, l, "synthetic", "2000-01-01"] for i, l in labels.items()])
    write_csv(p / "predictions.csv", "pr,prediction", [[i, preds[i]] for i in labels])
    if facts is not None:
        write_csv(p / "facts.csv", "pr,mechanical_hit", [[i, h] for i, h in facts.items()])
    return p


def make_test_split(d, n_pos=0, n_neg=0, miss=0):
    """Synthetic labels/predictions holding only test-split PRs: n_pos needs-review (miss of them called low), n_neg low."""
    prs = [str(n) for n in range(1, 2000) if report.split_of(str(n)) == "test"][: n_pos + n_neg]
    labels = {p: ("needs-review" if i < n_pos else "low") for i, p in enumerate(prs)}
    preds = {p: ("low" if l == "low" or i < miss else "needs-review") for i, (p, l) in enumerate(labels.items())}
    lp, pp = Path(d) / "labels.csv", Path(d) / "predictions.csv"
    write_csv(lp, "pr,label,labeler,date", [[p, l, "synthetic", "2000-01-01"] for p, l in labels.items()])
    write_csv(pp, "pr,prediction", [[p, preds[p]] for p in labels])
    return lp, pp


def pos_ids(n, start=1):
    return [f"P{i:02d}" for i in range(start, start + n)]


class PlantedAndGateTest(unittest.TestCase):
    run_main = CliTest.run_main

    def test_planted_split_reports_rates(self):
        labels = {"P01": "needs-review", "P02": "needs-review", "P03": "low"}
        preds = {"P01": "needs-review", "P02": "low", "P03": "low"}
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, labels, preds)
            rc, out, _ = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 0)
        self.assertIn("split=planted n=3 (needs-review=2, low=1)", out)
        self.assertIn("0.500 (1/2)", out)

    def test_planted_stratum_counts_only_no_hit_positives(self):
        labels = {"P01": "needs-review", "P02": "needs-review", "P03": "needs-review", "P04": "low"}
        preds = {"P01": "needs-review", "P02": "low", "P03": "needs-review", "P04": "low"}
        facts = {"P01": "true", "P02": "false", "P03": "false", "P04": "false"}
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, labels, preds, facts)
            rc, out, _ = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 0)
        self.assertIn("TPR, no mechanical hit:   0.500 (1/2)", out)

    def test_planted_without_facts_says_so(self):
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, {"P01": "needs-review"}, {"P01": "needs-review"})
            rc, out, _ = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 0)
        self.assertIn("n/a (no facts.csv)", out)

    def run_gate(self, n_test_pos, n_planted_pos, test_miss=0, planted_miss=0):
        with tempfile.TemporaryDirectory() as d:
            lp, pp = make_test_split(d, n_pos=n_test_pos, n_neg=2, miss=test_miss)
            ids = pos_ids(n_planted_pos)
            labels = {i: "needs-review" for i in ids} | {"P90": "low"}
            preds = {i: ("low" if k < planted_miss else "needs-review") for k, i in enumerate(ids)} | {"P90": "low"}
            pd = planted_dir(d, labels, preds)
            return self.run_main(["gate", "--labels", str(lp), "--predictions", str(pp), "--planted-dir", str(pd)])

    def test_gate_passes_with_no_miss_and_twenty_positives(self):
        rc, out, _ = self.run_gate(n_test_pos=2, n_planted_pos=18)
        self.assertEqual(rc, 0, out)
        self.assertIn("needs-review=20", out)
        self.assertIn("PASS", out)

    def test_gate_fails_on_one_miss(self):
        rc, out, _ = self.run_gate(n_test_pos=2, n_planted_pos=20, planted_miss=1)
        self.assertEqual(rc, 3)
        self.assertIn("FAIL", out)
        self.assertIn("P01", out)

    def test_gate_counts_a_test_split_miss(self):
        rc, out, _ = self.run_gate(n_test_pos=2, n_planted_pos=20, test_miss=1)
        self.assertEqual(rc, 3)
        first = next(str(n) for n in range(1, 2000) if report.split_of(str(n)) == "test")
        self.assertIn(f"gate: FAIL (missed {first})", out)

    def test_gate_fails_below_twenty_positives(self):
        rc, out, _ = self.run_gate(n_test_pos=1, n_planted_pos=18)
        self.assertEqual(rc, 3)
        self.assertIn("needs-review=19", out)
        self.assertIn("FAIL", out)

    def test_gate_ignores_train_labels(self):
        train = [str(n) for n in range(1, 2000) if report.split_of(str(n)) == "train"][:1]
        with tempfile.TemporaryDirectory() as d:
            lp, pp = make_test_split(d, n_pos=0, n_neg=1)
            with lp.open("a") as f:
                f.write(f"{train[0]},needs-review,synthetic,2000-01-01\n")
            with pp.open("a") as f:
                f.write(f"{train[0]},low\n")
            pd = planted_dir(d, {i: "needs-review" for i in pos_ids(20)}, {i: "needs-review" for i in pos_ids(20)})
            rc, out, _ = self.run_main(["gate", "--labels", str(lp), "--predictions", str(pp), "--planted-dir", str(pd)])
        self.assertEqual(rc, 0, out)


class GateRequestsTest(unittest.TestCase):
    """Check requests 1-4 from the report-gate Validation entry."""
    run_main = CliTest.run_main

    def gate(self, d, lp, pp, pd):
        return self.run_main(["gate", "--labels", str(lp), "--predictions", str(pp), "--planted-dir", str(pd)])

    def test_gate_ignores_dev_labels(self):
        dev = [str(n) for n in range(1, 2000) if report.split_of(str(n)) == "dev"][:2]
        with tempfile.TemporaryDirectory() as d:
            lp, pp = make_test_split(d, n_pos=0, n_neg=1)
            with lp.open("a") as f:
                f.writelines(f"{p},needs-review,synthetic,2000-01-01\n" for p in dev)
            with pp.open("a") as f:
                f.write(f"{dev[0]},low\n{dev[1]},needs-review\n")
            pd = planted_dir(d, {i: "needs-review" for i in pos_ids(19)}, {i: "needs-review" for i in pos_ids(19)})
            rc, out, _ = self.gate(d, lp, pp, pd)
        self.assertEqual(rc, 3, out)
        self.assertIn("needs-review=19", out)
        self.assertNotIn("missed", out)

    def test_gate_without_planted_dir_is_bad_input(self):
        with tempfile.TemporaryDirectory() as d:
            lp, pp = make_test_split(d, n_pos=20, n_neg=1)
            rc, out, err = self.gate(d, lp, pp, Path(d) / "planted")
        self.assertEqual(rc, 2)
        self.assertNotIn("PASS", out)
        self.assertIn("planted", err)

    def test_gate_with_no_labels_reports_n0(self):
        with tempfile.TemporaryDirectory() as d:
            lp, pp = make_test_split(d)
            rc, out, err = self.gate(d, lp, pp, planted_dir(d, {}, {}))
        self.assertEqual(rc, 1)
        self.assertNotIn("PASS", out)
        self.assertIn("no labels yet (n=0)", err)

    def test_planted_patch_without_facts_row_is_bad_input(self):
        labels = {"P01": "needs-review", "P02": "needs-review"}
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, labels, {"P01": "low", "P02": "needs-review"}, {"P02": "false"})
            rc, _, err = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 2)
        self.assertIn("P01", err)

    def test_facts_value_must_be_true_or_false(self):
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, {"P01": "needs-review"}, {"P01": "needs-review"}, {"P01": "yes"})
            rc, _, err = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 2)
        self.assertIn("expected true or false", err)

    def test_planted_id_equal_to_a_pr_number_stays_separate(self):
        pr = [str(n) for n in range(1, 2000) if report.split_of(str(n)) == "test"][0]
        with tempfile.TemporaryDirectory() as d:
            lp, pp = Path(d) / "labels.csv", Path(d) / "predictions.csv"
            write_csv(lp, "pr,label,labeler,date", [[pr, "needs-review", "synthetic", "2000-01-01"]])
            write_csv(pp, "pr,prediction", [[pr, "needs-review"]])
            ids = pos_ids(19) + [pr]
            preds = {i: "needs-review" for i in ids} | {pr: "low"}
            rc, out, _ = self.gate(d, lp, pp, planted_dir(d, {i: "needs-review" for i in ids}, preds))
        self.assertEqual(rc, 3, out)
        self.assertIn("needs-review=21", out)
        self.assertIn(f"missed planted:{pr}", out)


    def test_gate_rejects_a_label_id_that_shadows_a_planted_id(self):
        with tempfile.TemporaryDirectory() as d:
            lp, pp = Path(d) / "labels.csv", Path(d) / "predictions.csv"
            write_csv(lp, "pr,label,labeler,date", [["planted:P01", "needs-review", "synthetic", "2000-01-01"]])
            write_csv(pp, "pr,prediction", [["planted:P01", "low"]])
            ids = pos_ids(20)
            with mock.patch.object(report, "split_of", return_value="test"):
                rc, out, err = self.gate(d, lp, pp, planted_dir(d, {i: "needs-review" for i in ids}, {i: "needs-review" for i in ids}))
        self.assertEqual(rc, 2, out)
        self.assertNotIn("PASS", out)
        self.assertIn("planted:P01", err)

    def test_facts_id_listed_twice_is_bad_input(self):
        with tempfile.TemporaryDirectory() as d:
            pd = planted_dir(d, {"P01": "needs-review"}, {"P01": "low"})
            write_csv(pd / "facts.csv", "pr,mechanical_hit", [["P01", "false"], ["P01", "true"]])
            rc, _, err = self.run_main(["planted", "--planted-dir", str(pd)])
        self.assertEqual(rc, 2)
        self.assertIn("twice", err)


if __name__ == "__main__":
    unittest.main()
