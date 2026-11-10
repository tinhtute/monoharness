# Playbook: check (Validation evidence)

Loaded by [check-durable.md](check-durable.md) step 8.

## Validation Entry Format

```markdown
- <UTC> — phase `<phase-slug>` — verdict: APPROVED — mode: gate
  - `<command>` — <result in at most 3 lines>
  - scope: on target | drift | incomplete — <one line>
  - proof_classes: output, unit, integration (the lane's required proof, [check.md](check.md) § Lane Matrix)
  - requirements: R1 met (<proof>) | R2 not met (<gap>) | R3 partial (→ <phase>)
  - rollback_point: <commit the phase can be reverted to>
  - requests: none | <numbered findings with path:line>
  - not_independently_verified: <aspect> (same-session only)
  - judge: independent | same-session
  - judge_model: <model identifier>
  - judged_sha: <full SHA of the commit the judge reviewed>
```

Every Validation entry must include timestamp, stable phase slug, exact command/result and concise output, plus every field above. Two positions are load-bearing, so the commit-time guard can find them:

- The first line carries the anchored token `verdict: <VERDICT>`. Anywhere else it is silently skipped.
- An approvable entry on a plan with a `lane:` lists every class that lane requires in `proof_classes:`; a missing class is rejected by name.
- Each proof is a sub-bullet indented two or more spaces that starts with the bare command in single backticks: no label before it, no double backticks, no backtick inside the command.
- A verdict entry at the effective `high-risk` lane or in mode `full` carries `judge: independent`, a `judge_model:` from `judges` in the range base's `models.json` (a family name admits its versions: `fable` admits `claude-fable-5-1`), and a `judged_sha:` inside the range: the base itself or a commit HEAD contains that the base does not. At commit time the base is the default branch's merge-base.

Validation is append-only from an entry's first commit; never replace committed evidence. The one exception is closing compaction (`handoff.md` step 6), which keeps the last entry per phase byte-identical. An uncommitted entry may still be reshaped.

**Proof re-execution contract** — each proof re-runs from the repository root under `sh -c` on a bare checkout: no prior `cd`, virtualenv, or alias (carry them inline: `cd cli && cargo test`; bash-only syntax → `bash -c '…'`). It must not depend on environment variables, binary presence, or OS version. Timeout 300 s when `timeout`/`gtimeout` exists. A proof must be able to fail: the hook rejects one built only from `true`, `:`, `exit 0`, `echo` or `printf`, a `cargo test` run that passes 0 tests, and any entry in a range that adds a Rust `#[test]` with an empty body.

## What the Guards Cannot Check

Name any that applies in `proof_gaps:`: `judge: independent` is testimony (the guard checks that `judge_model:` is allowlisted and `judged_sha:` is in range, not that a separate session ran the review); an unparsed verdict is ignored, not rejected; an entry added and removed inside one push is unseen; a `requirements:` line is testimony, and the proof it cites re-runs only as a proof sub-bullet.
