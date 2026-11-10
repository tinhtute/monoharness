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


if __name__ == "__main__":
    unittest.main()
