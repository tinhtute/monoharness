---
status: active
lane: high-risk
---
# Supervisor–Lead–Peer: decide the audit's three options

## Goal
- outcome: the Lead can no longer self-accept at Land without a traceable independent judge session; a read-only Architect returns alternatives before an `adr candidate` trade-off is locked; a `fast`-tier `retro` supervisor reviews each fanout wave and `orchestrate` round and spot-checks `judge_session` claims
- success_signal: the acceptance commands of R1–R3 pass on `master`, and `agents/` still holds both `worker.md` and `engineer.md` (Q6)
- actors: the owner; the main agent as Lead; the `scout`, `worker`, `engineer`, `verifier` agents and the new `architect`; the risk judge
- authority: the decided `## Map` below (owner, 2026-11-13); ADR 0020 (`docs/decisions/0020-orchestrate-and-autopilot.md`); `skills/stages/check/references/check-risk.md`; `skills/stages/work/references/work-fanout.md`; audit `docs/research/2026-11-12-supervisor-lead-peer-audit.md`
- requirements:
  - R1: `scripts/ci/risk-verdict.sh` passes a low-risk verdict only when its `**Verdict:**` line also carries `judge_session: <id>` (the judge's transcript id), and `check-risk.md` § Risk Section documents the field | acceptance: `bash scripts/ci/test-risk-verdict.sh` with a fixture where a verdict without `judge_session` fails and one with it passes | source: Q3
  - R2: `agents/architect.md` is a read-only agent (tools: Read, Grep, Glob, Bash) listed in `models.json` `agents` and `readOnly`, and `grill`/`brainstorm` dispatch it only for a trade-off marked `adr candidate`, before the lock | acceptance: `bash scripts/ci/test-agent-models.sh` and `cd cli && cargo test` | source: Q4
  - R3: `retro` has a supervisor mode that skips step 2, reads only the digest and the plan, and returns at most 3 findings in the Observation / Evidence / Suspected mechanism / Impact / Question for Lead / Recommendation / Escalation shape or "no finding"; `work-fanout.md` and `orchestrate.md` trigger it after each wave and round, never per PR, on the `fast` tier; a local pre-check over the digest calls the model only on a signal (errored results, repeated calls, an auto-merged low-risk PR whose `judge_session` needs a spot-check) | acceptance: `bash scripts/ci/test-skill-scripts.sh` with one fixture digest that has a signal and one that has none, and `cd cli && cargo test` | source: Q5, Q2
- non-goals:
  - NG1: an independent judge on `check bounded` or the `normal` lane gate (Q3 keeps them same-session)
  - NG2: a standing multi-repo Supervisor session; the audit already defers it to multi-repo or multi-day runs
  - NG3: merging `worker` and `engineer` into one profile (Q6)
  - NG4: CI proving the judge session exists; CI cannot read local transcripts, so the R3 spot-check does it

## Map
- Q1: Where does the Lead self-accept today without an independent judge: only PR Land, or also `check` on bounded low-risk changes the main agent wrote itself? | type: research | by: AFK | blocked_by: none | status: decided → wider than Land: same-session acceptance is allowed on `work bounded` → `check bounded` (no plan, no hook sees it) and on `tiny`/`normal` lane gates by design; at Land, CI checks only the text of the `judge: independent` claim, so an author can type it without a judge running; the hook enforces an independent judge (shape only) only for `full` checks and `high-risk` plan entries; the high-risk fanout verifier is prose only | evidence: scripts/ci/risk-verdict.sh:43-52, scripts/install-git-hooks.sh:468-507 and :850-855, skills/stages/work/references/work-full.md:35, skills/stages/check/references/check-validation.md:34, scout 2026-11-13
- Q2: Can a separate Claude Code session read the Lead's live `~/.claude/projects/<project>/*.jsonl` and relay one finding to it through `SendMessage`, end to end? | type: research | by: AFK | blocked_by: none | status: decided → yes, both halves work separately: the live jsonl grows during the session and `session-digest.py` parses it mid-run; `SendMessage` reached another local session and got a reply. Gaps: sub-agent logs sit in `<session>/subagents/` and the digest skips them; compaction markers in a live file are untested; the two halves have not run together in one Supervisor round | evidence: scout 2026-11-13 (fce501b1 jsonl 368→372 lines in 30 s; digest exit 0); cross-session reply to `monoengine` 2026-11-13
- Q3: Option 1 — which path must get an independent judge so the Lead never accepts its own work, given that a judge cannot lower an always-review verdict (as on #273): `check bounded`, the `normal` lane gate, or proof at Land that the judge actually ran (CI now takes the `judge: independent` line on trust)? | type: grill | by: HITL | blocked_by: Q1 | status: decided → Land only (the `ci-required` ruleset already forces every change through a PR and `risk-verdict`); `check bounded` and the `normal` lane gate stay same-session; the verdict adds a `judge_session` field (the judge's jsonl id) that `risk-verdict` requires, and the audit in Q5 spot-checks that the session exists and judged that SHA | evidence: user 2026-11-13; rulesets `ci-required` and `protected` via gh api 2026-11-13
- Q4: Option 2 — adopt an Architect disposition, and if so, as a new read-only agent file or as a `verifier` brief mode? | type: grill | by: HITL | blocked_by: none | status: decided → adopt, as a new `agents/architect.md` (tools: Read, Grep, Glob, Bash; own model in `models.json`), dispatched only when `grill`/`brainstorm` marks a trade-off `adr candidate`, before the lock | evidence: user 2026-11-13
- Q5: Option 3 — adopt the event-triggered `retro` as a light Supervisor, and on which events (fanout wave end, `orchestrate` round), given that it must also spot-check `judge_session` claims at Land (Q3)? | type: grill | by: HITL | blocked_by: Q2 | status: decided → adopt a `retro` supervisor mode: skip retro step 2 (guardrails), read only the digest and the plan, return at most 3 findings in the Observation / Evidence / Suspected mechanism / Impact / Question for Lead / Recommendation / Escalation shape or "no finding"; trigger after each fanout wave and each `orchestrate` round, never per PR; run on the haiku tier; call the model only when the local digest shows a signal (errored results, repeated calls, an auto-merged low-risk PR to spot-check `judge_session`); give it Read/Grep on repo files so verification is not blocked | evidence: user 2026-11-13; trial run 2026-11-13 on session fce501b1: haiku scout, 33 s, 6 tool calls, ~24k peak context, ~27k tokens, "no finding"; its Bash `sed` was denied by auto mode
- Q6: Collapse `worker` and `engineer` into one Peer profile at two model tiers, or keep both files? They differ in model, `maxTurns`, and `worker`'s missing-VERIFY `BLOCKED (spec)` line | type: grill | by: HITL | blocked_by: none | status: decided → keep both files: `worker` takes light mechanical tasks with a stated acceptance command; `engineer` takes a bounded outcome that needs its own judgment | evidence: user 2026-11-13

## Phases and Verification
- approach: not-planned

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: none
- exact_next_action: to-plan
