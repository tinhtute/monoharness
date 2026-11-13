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
- approach: three phases, one PR each: R1 lands first because R3's spot-check reads the `judge_session` field it adds; R2 touches nothing R1 or R3 touch, so it can be built in parallel; the PRs still merge one at a time because each one edits this plan file. `judge_session` is the judge sub-agent's `agentId`, which the Agent tool result shows the Lead (its transcript is `<lead-session>/subagents/agent-<agentId>.jsonl`; a Claude Code reading of Q3's "the judge's jsonl id"), so CI checks only the field's shape and the R3 supervisor checks it exists locally. Rejected: one PR for all three, which mixes an always-review CI gate with docs and an agent file and runs over 400 counted lines
- constraints: `scripts/ci/**` is always-review, so the `judge-session` PR needs the owner's `owner-reviewed` label; editing `skills/stages/*/references/` requires `cd cli && cargo test` (embedded contracts pin that text); `worker` and `engineer` stay unchanged (NG3)
- risks: R1 makes every open PR's existing verdict line fail `risk-verdict` → land it when no open PR relies on an automatic low-risk verdict, or re-judge those PRs; R3's digest skips `subagents/` logs, so the supervisor misses sub-agent errors → accepted gap from Q2, named in the retro mode text
- recovery: each phase is one merge commit; revert that merge to roll the phase back; the `judge-session` revert restores the old verdict regex, and nothing else reads `judge_session` until `retro-supervisor` lands
- seams: `scripts/ci/risk-verdict.sh <base> <head> <body-file>` and its fixtures in `scripts/ci/test-risk-verdict.sh`; `scripts/ci/test-agent-models.sh` over `agents/*.md` and `models.json`; the `session-digest.py` CLI and its fixtures in `scripts/ci/test-skill-scripts.sh`; the embedded reference contracts under `cli/tests/`
- phase_slug: `judge-session`
  status: planned
  - goal: R1 | depends_on: none
  - surfaces: `scripts/ci/risk-verdict.sh`, `scripts/ci/test-risk-verdict.sh`, `skills/stages/check/references/check-risk.md` | avoided: `skills/stages/check/scripts/risk-facts.sh`, `models.json`, `.github/**`
  - escalate_when: the gate cannot read `judge_session` without changing `.github/workflows/risk-verdict.yml`, or an open PR would lose a valid low-risk verdict at merge
  - wave 1:
    - T1 require `judge_session: <id>` (`[A-Za-z0-9-]+`) after `judge_model` on the `**Verdict:**` line; a low-risk verdict without it fails; the check-risk § Risk Section template and the judge brief tell the Lead to record the judge sub-agent's `agentId` (owner: `engineer`, writes `scripts/ci/risk-verdict.sh`, `scripts/ci/test-risk-verdict.sh`, `skills/stages/check/references/check-risk.md` only) — output: the fixture without the field fails, the fixture with it passes, all old fixtures updated — check: `bash scripts/ci/test-risk-verdict.sh && bash scripts/ci/test-risk-facts.sh && (cd cli && cargo test)` — stop_if: a fixture must be deleted or weakened to pass
  - phase check: `bash scripts/ci/test-risk-verdict.sh && bash scripts/ci/test-risk-facts.sh && (cd cli && cargo test)`
- phase_slug: `architect`
  status: planned
  - goal: R2 | depends_on: none
  - surfaces: `agents/architect.md`, `models.json`, the agent lists in `AGENTS.md`, `CONTRIBUTING.md` and `README.md`, `skills/stages/grill/references/grill.md`, `skills/stages/brainstorm/references/brainstorm.md` | avoided: `agents/worker.md`, `agents/engineer.md`, `scripts/install-agents.sh`
  - escalate_when: the architect needs a tier other than `default`, or a write tool
  - wave 1:
    - T2 add `agents/architect.md` (tools: Read, Grep, Glob, Bash; `maxTurns`; returns alternatives, the strongest counterargument and reversal conditions in one sealed report) and its `models.json` entry (tier `default`, listed in `readOnly`); add it to the agent lists in `AGENTS.md`, `CONTRIBUTING.md` and `README.md` (owner: `engineer`, writes `agents/architect.md`, `models.json`, `AGENTS.md`, `CONTRIBUTING.md`, `README.md` only) — output: the policy test counts 5 agents — check: `bash scripts/ci/test-agent-models.sh` — stop_if: the test needs a change to pass
    - T3 `grill` Done and `brainstorm` step 3 dispatch `architect` only for a trade-off marked `adr candidate`, before the lock (owner: `worker`, writes `skills/stages/grill/references/grill.md`, `skills/stages/brainstorm/references/brainstorm.md` only) — output: one dispatch sentence in each file — check: `grep -n architect skills/stages/grill/references/grill.md skills/stages/brainstorm/references/brainstorm.md && (cd cli && cargo test)` — stop_if: a `required` string in `cli/src/embedded.rs` would have to change
  - phase check: `bash scripts/ci/test-agent-models.sh && (cd cli && cargo test) && bash scripts/ci/verify-doc-links.sh`
- phase_slug: `retro-supervisor`
  status: planned
  - goal: R3 | depends_on: judge-session
  - surfaces: `skills/stages/retro/scripts/session-digest.py`, `scripts/ci/test-skill-scripts.sh`, `skills/stages/retro/references/retro.md`, `skills/stages/work/references/work-fanout.md`, `skills/poteto/playbooks/orchestrate.md` | avoided: `agents/*.md`, `models.json`, `scripts/ci/risk-verdict.sh`
  - escalate_when: the pre-check cannot tell a signal from noise on the fixture digests, or the supervisor needs a tool beyond `scout`'s
  - wave 1:
    - T4 add `session-digest.py --signals <session>`: prints one `signal:` line per errored tool result, repeated identical call, or `gh pr merge` call, and nothing when clean; exit 0 either way (owner: `engineer`, writes `skills/stages/retro/scripts/session-digest.py`, `scripts/ci/test-skill-scripts.sh` only) — output: one fixture with each signal and one clean fixture — check: `bash scripts/ci/test-skill-scripts.sh` — stop_if: the change alters the default digest output
  - wave 2:
    - T5 add the `retro` supervisor mode (skip step 2; read the digest and the plan; at most 3 findings in the Observation / Evidence / Suspected mechanism / Impact / Question for Lead / Recommendation / Escalation shape, or "no finding"; for a `gh pr merge` signal, confirm `subagents/agent-<judge_session>.jsonl` exists and names the merged SHA; sub-agent logs are not in the digest) and the triggers: after each fanout wave in `work-fanout.md` § Aggregate and each `orchestrate` round, run `--signals` and dispatch `scout` only on a signal, never per PR (owner: `worker`, writes `skills/stages/retro/references/retro.md`, `skills/stages/work/references/work-fanout.md`, `skills/poteto/playbooks/orchestrate.md` only) — output: the mode section and two trigger sentences — check: `(cd cli && cargo test) && bash scripts/ci/verify-doc-links.sh` — stop_if: a `required` string in `cli/src/embedded.rs` would have to change
  - phase check: `bash scripts/ci/test-skill-scripts.sh && (cd cli && cargo test) && bash scripts/ci/verify-doc-links.sh`

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: none
- exact_next_action: work full phase judge-session
