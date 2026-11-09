---
status: active
lane: high-risk
---
# Orchestrate and autopilot playbooks

## Goal
- outcome: `mono` routes a multi-day program to a new `orchestrate` playbook and a queue of PRs to a new `autopilot` playbook (`stack` by default, `full` merging only via `ship` § Land). Both are ported from upstream cursor/plugins pstack and mapped onto Claude Code and the plan `## Log`. `fanout` keeps one in-session wave. `work-fanout.md` retries by cause (max 2) and has a scoped force-push exception for PR owners.
- success_signal: `bash scripts/ci/validate-skills.sh`, `bash scripts/ci/verify-doc-links.sh` and `cd cli && cargo test` pass; the grep acceptance in each requirement holds; an independent judge approves each phase.
- actors: the owner (therealtinhtute) running `/mono`; the main agent acting as coordinator; `mono-lead`/`mono-worker` as PR owners; `mono-verifier` as the per-PR verifier.
- authority:
  - The owner's decisions on 2026-11-09 (merge authority, owner force-push, split delivery, file shape, retry scope, runtime).
  - Upstream `cursor/plugins` `pstack/` v0.15.36 (6b03002), `skills/poteto-mode/playbooks/{orchestrate,autopilot-full,autopilot-stack}.md`.
  - AGENTS.md § Unattended Shipping.
  - `skills/mono/playbooks/ship.md` § Land.
  - `skills/stages/work/references/work-fanout.md`.
  - `docs/research/pstack-concepts-audit.md`, which rejected event-driven orchestration.
- requirements:
  - R1: ADR `docs/decisions/0020-orchestrate-and-autopilot.md` records each owner decision, the reversal of the earlier skip, and the dropped upstream pieces. | acceptance: `test -f docs/decisions/0020-orchestrate-and-autopilot.md && grep -c "force-with-lease\|ship.md#land\|session-pickup\|event" docs/decisions/0020-orchestrate-and-autopilot.md` ≥ 4 | source: owner decisions 2026-11-09
  - R2: `skills/mono/playbooks/orchestrate.md` defines a multi-day program: a canary unit end to end before fan-out; 2 levels only (root, workers); a rolling window of ≤10; a different-family verifier per PR with a verdict bound to its head SHA; live state from `gh` before any report; every worker accounted for; the owner asked only for real decisions; all state in the plan `## Log`; runtime in-session plus `/loop`, with `session-pickup` respawning owners from the Log. | acceptance: `grep -c "canary\|session-pickup\|## Log\|/loop\|head SHA" skills/mono/playbooks/orchestrate.md` ≥ 5 | source: upstream orchestrate.md, owner decisions
  - R3: `fanout.md` drops its `## Orchestrate-lite` section and points long runs to `orchestrate`. | acceptance: `! grep -q "Orchestrate-lite" skills/mono/playbooks/fanout.md && grep -q "orchestrate.md" skills/mono/playbooks/fanout.md` | source: owner decision (file shape)
  - R4: `work-fanout.md` Aggregate retries by cause, at most 2: smaller scope after a context limit, the same brief after a dropped connection, a different model after a tool error. After that the unit is `blocked`. FORBIDDEN gains the PR-owner exception: rebase and force-push only its own branch, with `--force-with-lease` pinned to its last pushed SHA. | acceptance: `grep -q "force-with-lease" skills/stages/work/references/work-fanout.md && grep -qi "by cause" skills/stages/work/references/work-fanout.md && (cd cli && cargo test)` | source: owner decisions (retry everywhere, owner push)
  - R5: `skills/mono/playbooks/autopilot.md` defines modes `stack` (default: stop at verified, no merge) and `full` (every merge through `ship.md` § Land; an owner never merges by itself); one full verification at the code-ready head, then a single verifier per later head; verdicts carried by `git patch-id`; stacking only when a PR builds on another; a `/loop 1h` audit judging agents by side effects; a stop that halts every agent and logs `decision: hold`; agents never apply `owner-reviewed` or `allow-test-weakening`. | acceptance: `grep -c "stack\|full\|ship.md#land\|patch-id\|decision: hold\|owner-reviewed" skills/mono/playbooks/autopilot.md` ≥ 6 | source: upstream autopilot-full/stack, owner decision (merge authority)
  - R6: The `mono` router lists seventeen playbooks with separate rows for fanout (one wave), orchestrate (program) and autopilot (PR queue); README, CHANGELOG and NOTICE are updated. | acceptance: `grep -q "seventeen" skills/mono/SKILL.md && grep -q "orchestrate.md" skills/mono/SKILL.md && grep -q "autopilot.md" skills/mono/SKILL.md && bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh` | source: owner decisions
- non-goals:
  - NG1: No cloud routines, scheduled remote agents, background processes, or event/webhook subscriptions.
  - NG2: No sub-coordinator level: `mono-lead` cannot spawn sub-agents.
  - NG3: No task database or state outside the plan file and git/forge.
  - NG4: No change to `ship.md` § Land, `check-risk.md`, CI workflows, hooks or always-review paths.
  - NG5: No `site/` update (hand-authored; next site pass).

## Phases and Verification
- approach: Port upstream orchestrate and autopilot as procedure text in two new `mono` playbooks. Ship policy (merge, retries, owner push) goes in an ADR first, and the shared reference `work-fanout.md` is changed once, so all three fan-out playbooks read one rule. The rejected alternative extends `fanout` in place: fanout gets long, and routing between a wave, a program and a PR queue blurs.
- risks:
  - autopilot `full` merges a bad PR. Mitigation: it never merges outside `ship.md` § Land (head-bound risk verdict, independent judge, opt-in from the base's AGENTS.md); `stack` is the default. Stop the phase and ask the owner if any text lets an owner merge directly.
  - The owner force-push exception leaks to ordinary workers. Mitigation: the exception names the PR-owner role, its own branch, and `--force-with-lease` pinned to its last pushed SHA. Its fixture is a grep that FORBIDDEN still bans plain workers.
  - Editing `work-fanout.md` breaks a `cargo test` text contract. Mitigation: run `cargo test` per task. If it fails twice, stop and read `cli/src/embedded.rs` before changing any wording.
  - Recovery: every phase is docs-only; revert that phase's commit.
- seams: `skills/mono/SKILL.md` router table; `skills/mono/playbooks/{fanout,ship}.md`; `skills/stages/work/references/work-fanout.md` (§ Aggregate, the brief's FORBIDDEN line); `cli/src/embedded.rs` + `cli/tests/skill_reference_resolution.rs` text contracts; `scripts/ci/validate-skills.sh`; `scripts/ci/verify-doc-links.sh`.
- constraints: the branch stacks on PR #252 (`feat/hillclimb-pause-playbooks`) because the router count goes 15 → 17, so rebase onto master after #252 merges. Follow `docs/guides/prompt-engineering-principles.md` for all playbook text. Make no edits under NG4 paths.
- recovery: a failed phase check, or a judge verdict of REJECT, reverts the phase commit and records it as `blocked` in `## Log`.
- phase_slug: `adr`
  status: checked
  - goal: R1 | depends_on: none
  - surfaces: `docs/decisions/0020-orchestrate-and-autopilot.md` (new), `docs/decisions/README.md` index | avoided: skills
  - escalate_when: an owner decision conflicts with an accepted ADR (0016, 0018, 0019) in a way the ADR text cannot reconcile
  - wave 1:
    - T1 write ADR 0020 covering: context (upstream orchestrate/autopilot, the earlier skip); decisions (merge authority, owner force-push, retry by cause everywhere, 2 levels, in-session runtime, file shape); dropped pieces (cloud VMs, event subscriptions, sub-coordinators, Project store, Cursor-only skills); consequences. Owner: lead, writes the ADR and the README index line only. Output: the ADR. Check: `grep -c "force-with-lease\|ship.md#land\|session-pickup\|event" docs/decisions/0020-orchestrate-and-autopilot.md && bash scripts/ci/verify-doc-links.sh`. stop_if: the link check fails.
  - phase check: `test -f docs/decisions/0020-orchestrate-and-autopilot.md && bash scripts/ci/verify-doc-links.sh`
- phase_slug: `orchestrate`
  status: checked
  - goal: R2, R3, R4 | depends_on: adr
  - surfaces: `skills/mono/playbooks/orchestrate.md` (new), `skills/mono/playbooks/fanout.md`, `skills/stages/work/references/work-fanout.md` | avoided: `ship.md`, `babysit.md`, the router
  - escalate_when: a `cargo test` contract pins `work-fanout.md` wording that R4 must change
  - wave 1:
    - T2 `work-fanout.md`: Aggregate step 3 becomes retry by cause, max 2, then `blocked`; FORBIDDEN gains the PR-owner exception. Owner: lead, writes `work-fanout.md` only. Output: the reference text. Check: `grep -q "force-with-lease" skills/stages/work/references/work-fanout.md && grep -qi "by cause" skills/stages/work/references/work-fanout.md && (cd cli && cargo test)`. stop_if: cargo test fails twice.
  - wave 2:
    - T3 write `orchestrate.md` per R2 (upstream orchestrate.md mapped to Claude Code: `mono-lead`/`mono-worker` owners, `mono-verifier`, plan `## Log`, `/loop`, `session-pickup`), and move fanout's Orchestrate-lite rules into it. Owner: lead, writes `orchestrate.md` and `fanout.md` only. Output: playbook and trimmed fanout. Check: `grep -c "canary\|session-pickup\|## Log\|/loop\|head SHA" skills/mono/playbooks/orchestrate.md && ! grep -q "Orchestrate-lite" skills/mono/playbooks/fanout.md && grep -q "orchestrate.md" skills/mono/playbooks/fanout.md`. stop_if: a rule would need state outside the plan or forge.
  - phase check: `bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh && (cd cli && cargo test)`
- phase_slug: `autopilot`
  status: checked
  - goal: R5, R6 | depends_on: orchestrate
  - surfaces: `skills/mono/playbooks/autopilot.md` (new), `skills/mono/SKILL.md`, `README.md`, `CHANGELOG.md`, `skills/mono/NOTICE.md` | avoided: `ship.md` § Land, `check-risk.md`, AGENTS.md § Unattended Shipping
  - escalate_when: `full` mode needs any change to Land or to AGENTS.md § Unattended Shipping
  - wave 1:
    - T4 write `autopilot.md` per R5 (upstream autopilot-full and autopilot-stack, with merges routed to `ship.md#land`). Owner: lead, writes `autopilot.md` only. Output: playbook. Check: `grep -c "stack\|full\|ship.md#land\|patch-id\|decision: hold\|owner-reviewed" skills/mono/playbooks/autopilot.md && ! grep -nE "gh pr merge" skills/mono/playbooks/autopilot.md`. stop_if: the text needs a direct merge command.
  - wave 2:
    - T5 router rows (fanout = one wave, orchestrate = program, autopilot = PR queue; "seventeen"), README table and alt text, CHANGELOG Unreleased Added, NOTICE line. Owner: worker, writes those 4 files only. Output: docs. Check: `grep -q "seventeen" skills/mono/SKILL.md && grep -q "autopilot.md" skills/mono/SKILL.md && bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh`. stop_if: validate-skills fails.
  - phase check: `bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh && (cd cli && cargo test)`
- validation: a final `check full` with an independent judge on a different model family. Dry-run `/mono` routing on 3 prompts ("run these 4 independent tasks in parallel", "drive this 20-PR migration over the week", "take these 5 PRs to verified") and expect fanout, orchestrate and autopilot respectively.

## Log
- 2026-11-09T04:20Z — plan — decision — owner (AskUserQuestion, 2026-11-09): run the plan through `fanout`; one local commit per gated phase on `feat/orchestrate-autopilot`, no push or PR until asked. Workers run in worktrees; each phase commits before the next so worktrees see prior output.
- 2026-11-09T04:20Z — orchestrate — decision — `cli/src/embedded.rs:405` pins "A second miss → log `blocked`" in `work-fanout.md`; this matches the phase's escalate_when ahead of time. Owner answered (2026-11-09): update the pin — `cli/src/embedded.rs` joins T2's surfaces and the pinned string is replaced by the new retry-by-cause wording with equal strength. `fanout.md` step 4 ("one fresh retry") is a second copy of the rule and joins T3's scope.
- 2026-11-09T04:20Z — adr — start — escalate_when not matched: ADR 0016 decision 1/3 requires a new authority record before a boundary rule (FORBIDDEN, outward permission) changes; ADR 0020 is that record, and 0018/0019 decisions do not conflict. Baseline `bash scripts/ci/verify-doc-links.sh` rc=0. The ADR is written before implementation, so T1 may also amend the README "Exception" sentence to name 0020.
- 2026-11-09T04:27Z — adr/T1 — done — mono-lead (opus), branch `worktree-agent-a4831d2bc8793a65b` commit `14a6a9f`, cherry-picked as `fd1b7e0` onto `feat/orchestrate-autopilot`. Check on the main checkout at HEAD `fd1b7e0`, clean tracked tree: `grep -c "force-with-lease\|ship.md#land\|session-pickup\|event" docs/decisions/0020-orchestrate-and-autopilot.md` → 10; `bash scripts/ci/verify-doc-links.sh` rc=0. Surfaces: the ADR (new) and `docs/decisions/README.md` (index row + Exception sentence). stop_if: not matched.
- 2026-11-09T04:27Z — adr — decision — worker deviations accepted: the concepts audit itself has no orchestration finding, so the ADR cites `docs/research/2026-10-22-pstack-retro-5.md:44`/`:47` and the completed `pstack-lessons` plan instead; repository line citations pin to base `5210571`. Gap carried to T2: a respawned PR owner has no "last pushed" SHA; T2 pins the lease to the SHA logged in `## Log` for that branch and only after `git ls-remote` shows that SHA as the remote head, else `blocked`. Carried to T4: map upstream `ketchup`/`show-me-your-work`/`no-comments` to this repo's skills or drop them.
- 2026-11-09T04:31Z — adr — done — gate APPROVED by an independent mono-verifier (fable); entry in `## Validation`. Non-blocking requests carried to phase `orchestrate`: (1) ADR 0020 line 72 cites `README.md:129`, which is :131 on this branch — fix the citation; (2) T2's respawned-owner lease rule (Log 04:27) widens Decision 2, so `docs/decisions/0020-orchestrate-and-autopilot.md` joins T2's surfaces for a matching amendment.
- 2026-11-09T04:35Z — orchestrate — start — escalate_when matched ahead of time and resolved by the owner (Log 04:20: update the pin). Baseline phase check rc=0 at `34572a1`. T2 surfaces now: `work-fanout.md`, `cli/src/embedded.rs`, `docs/decisions/0020-orchestrate-and-autopilot.md` (Decision 2 respawned-owner clause, Consequences bullet, `README.md:131` citation).
- 2026-11-09T04:42Z — orchestrate/T2 — done — mono-lead (opus), branch `worktree-agent-a9fda857dd2c6e389` commits `2420e70`, `ab21542`, cherry-picked as `962e7ac`, `f5ae14e`. Checked on the main checkout: force-with-lease + "by cause" greps rc=0; FORBIDDEN prefix count 1; "A second miss" absent; verify-doc-links rc=0; `cargo fmt --check` + `cargo test` rc=0 (84/3/2). Diff in SCOPE: work-fanout.md, embedded.rs work-fanout pins (1 → 4), ADR 0020. stop_if: not matched.
- 2026-11-09T04:42Z — orchestrate — decision — accepted T2 deviation: ADR 0020 Decision 3 gains a fourth cause ("rejected result → consolidated scope", the existing rule kept) so the reference stays within its authority. The respawned-owner lease rule is a coordinator decision, recorded as such in the ADR; surfaced to the owner for veto before the phase commit.
- 2026-11-09T04:43Z — orchestrate/T3 — done — mono-lead (opus), branch `worktree-agent-a606d30ee17ab98d0` commits `999f372`, `9177bee`, cherry-picked as `b5533c6`, `cd1135d`. Checked on the main checkout: R2 grep → 6; R3 check rc=0; no `gh pr merge`/cloud; validate-skills (19 valid), verify-doc-links, cargo test (84/3/2) rc=0. Diff in SCOPE: orchestrate.md (new), fanout.md (Orchestrate-lite removed, step 4 → retry by cause). Remaining old-wording hit: babysit.md:9 "one fresh run" is the CI-flake rule, left. `autopilot` named without a link until T4 creates it. stop_if: not matched.
- 2026-11-09T04:46Z — orchestrate — done — gate APPROVED by an independent mono-verifier (fable); entry in `## Validation`. Non-blocking requests carried to phase `autopilot` as task T6 (mono-worker, wave 2 beside T5, disjoint files): orchestrate.md — state that the program request covers PR owners pushing their own branch and opening its PR, add a short resume clause (session-pickup respawns from Log branch/SHA/model; live `gh pr view` first; lease rule in work-fanout.md), fold rule bullets toward 5–8, link `autopilot.md`; work-fanout.md:48 "The owner's brief" → "The PR owner's brief"; a default retry when the cause is unknown (dropped connection → same brief). Also: Log timestamp 04:50 for T3 corrected to 04:43 (the gate's clock read 04:44).
- 2026-11-09T04:47Z — autopilot — start — escalate_when not matched: ship.md § Land already holds the head-SHA risk judge, the base-AGENTS.md opt-in and the only `gh pr merge`; `autopilot full` links to it and changes neither Land nor AGENTS.md § Unattended Shipping. Baseline phase check rc=0 at `a09ad26`. Wave 1: T4 (autopilot.md) ∥ T6 (orchestrate gate follow-ups: orchestrate.md + work-fanout.md, disjoint files, no autopilot link yet). Wave 2: T5 (router, README, CHANGELOG, NOTICE) also links `autopilot.md` at orchestrate.md:3.
- 2026-11-09T04:48Z — autopilot/T6 — done — mono-worker (sonnet), branch `worktree-agent-a169b5af860b95ee1` commit `3853a3c`, cherry-picked as `fe65ca8`. Checked: orchestrate grep → 6; cargo test 5 suites ok; diff limited to orchestrate.md (11 → 8 rule bullets, push/PR scope, resume clause) and work-fanout.md ("The PR owner's brief"; unknown cause → same brief, once). Note for the gate: the unknown-cause default sits under the "dropped connection" cause; ADR 0020 Decision 3 lists causes without it.
- 2026-11-09T04:51Z — autopilot/T4 — done — mono-lead (opus), branch `worktree-agent-a32de74782e4930fa` commits `bb4f55d`, `b6611b9`, cherry-picked as `f5fdfd7`, `69ce467`. Re-checked on the main checkout: grep → 12; no `gh pr merge`; `allow-test-weakening` present; validate-skills 19 valid; doc links 0 findings. Upstream mapping: owners → mono-lead/mono-worker per worktree; swarm → `check full` with mono-verifier; show-me-your-work → plan `## Log`; ketchup → Reply line; owner merge → ship.md § Land; deslop/no-comments/control-*/Graphite/forge approvals dropped.
- 2026-11-09T04:51Z — autopilot — decision — Takeover lease (T4 open item): an owner spawned onto an already-open PR has pushed nothing and is not a respawn. Coordinator decision: at spawn the coordinator logs that PR's head SHA, and the owner follows the respawn clause (pin the logged SHA only after `git ls-remote` shows it as the remote head; otherwise `blocked`, no push). Folded into T5: work-fanout.md exception paragraph and ADR 0020 decision 2. Owner may veto.
- 2026-11-09T04:53Z — autopilot/T5 — done — mono-worker (sonnet), branch `worktree-agent-ac979c9276071d8a8` commit `5a2f566`, cherry-picked as `804c7ec`. Re-checked on the main checkout: router says seventeen (15 → 17 rows: fanout one wave, orchestrate program, autopilot PR queue); work-fanout.md "already-open PR" present with the embedded.rs pin intact; validate-skills 19 valid; doc links 0 findings; cargo test 5 suites ok. Deviation: `site/assets/workflow.png` still shows fifteen playbooks (alt text updated); outside scope, left for the owner.
- 2026-11-09T04:57Z — autopilot — done — gate APPROVED by an independent mono-verifier (fable); entry in `## Validation`. Correction to 04:53: `site/assets/workflow.png` reads twelve playbooks (pre-existing drift, NG5). Non-blocking requests (ADR Decision 2/3 wording, NOTICE version) go to a final-pass commit before `check full`.

## Validation
- 2026-11-09T04:30Z — phase `adr` — verdict: APPROVED — mode: gate
  - `test -f docs/decisions/0020-orchestrate-and-autopilot.md && grep -c "force-with-lease\|ship.md#land\|session-pickup\|event" docs/decisions/0020-orchestrate-and-autopilot.md` — prints 10, rc=0 (R1 threshold ≥ 4)
  - `bash scripts/ci/verify-doc-links.sh` — "doc links OK (0 findings; 4 claim(s) under known-removed v0.15 surfaces)", rc=0
  - `cd cli && cargo test` — lib 84 passed; projection_parity 3 passed; skill_reference_resolution 2 passed; 0 failed, rc=0 (regression proof; the ADR touches no Rust)
  - scope: on target — diff adds the ADR and edits the README index row plus the Exception sentence (Log 04:20 allowed the latter); no skills touched
  - proof_classes: output, unit, integration
  - requirements: R1 met (file exists; acceptance grep → 10; all 8 owner decisions recorded with a rejected alternative each; reversal of the earlier skip cited; 5 dropped upstream pieces each with a reason; five headings present)
  - rollback_point: 6d6e8a5
  - requests: minor, non-blocking — (1) ADR line 72 cites `README.md:129`, now :131 on this branch; (2) T2's respawned-owner lease rule needs a matching ADR 0020 Decision 2 amendment. Both carried to phase `orchestrate` (Log 04:31).
  - judge: independent
  - judge_model: claude-fable-5-1
- 2026-11-09T04:44Z — phase `orchestrate` — verdict: APPROVED — mode: gate
  - `grep -q "force-with-lease" skills/stages/work/references/work-fanout.md && grep -qi "by cause" skills/stages/work/references/work-fanout.md && grep -c "canary\|session-pickup\|## Log\|/loop\|head SHA" skills/mono/playbooks/orchestrate.md` — prints 6, rc=0 (R2 threshold ≥ 5; R4 greps hold)
  - `bash scripts/ci/validate-skills.sh` — "19 skill(s) valid", rc=0
  - `bash scripts/ci/verify-doc-links.sh` — "doc links OK (0 findings; 4 claim(s) under known-removed v0.15 surfaces)", rc=0
  - `cd cli && cargo test` — lib 84 passed; projection_parity 3 passed; skill_reference_resolution 2 passed; 0 failed, rc=0 (work-fanout pins 1 → 4)
  - `cd cli && cargo fmt --check` — clean, rc=0
  - scope: on target — work-fanout.md, embedded.rs (test pins only), ADR 0020 amendments, orchestrate.md (new), fanout.md; ship.md, babysit.md, router and NG4 paths untouched. R3 check rc=0. FORBIDDEN prefix count 1; exception scoped to PR owners spawned by orchestrate/autopilot; no worker merges.
  - proof_classes: output, unit, integration
  - requirements: R2 met (all properties present; step 5 lands only via ship.md § Land; NG1–NG4 honored), R3 met (lite rules mapped; Land-as-verified replaced by Land per Decision 1), R4 met (four causes, max 2, then `blocked`; fanout.md:6 matches; pins stronger; respawned-owner rule labeled coordinator decision, no wider than owner intent)
  - rollback_point: 34572a1
  - requests: non-blocking — push/PR clause and resume clause in orchestrate.md; "The PR owner's brief" at work-fanout.md:48; default retry for unknown cause; fold rule bullets. Carried to phase `autopilot` T6 (Log 04:46).
  - judge: independent
  - judge_model: claude-fable-5-1

- 2026-11-09T04:56Z — phase `autopilot` — verdict: APPROVED — mode: gate
  - `grep -c "stack\|full\|ship.md#land\|patch-id\|decision: hold\|owner-reviewed" skills/mono/playbooks/autopilot.md && ! grep -nE "gh pr merge" skills/mono/playbooks/autopilot.md` — prints 12 (R5 threshold ≥ 6); no direct merge command, rc=0
  - `grep -q "seventeen" skills/mono/SKILL.md && grep -q "orchestrate.md" skills/mono/SKILL.md && grep -q "autopilot.md" skills/mono/SKILL.md && bash scripts/ci/validate-skills.sh && bash scripts/ci/verify-doc-links.sh` — R6 acceptance; "19 skill(s) valid", "doc links OK (0 findings; 4 claim(s) under known-removed v0.15 surfaces)", rc=0
  - `cd cli && cargo test` — lib 84 passed; projection_parity 3 passed; skill_reference_resolution 2 passed; 0 failed (work-fanout pins at embedded.rs:405-408 hold), rc=0
  - `cd cli && cargo fmt --check` — clean, rc=0
  - `grep -c "canary\|session-pickup\|## Log\|/loop\|head SHA" skills/mono/playbooks/orchestrate.md && ! grep -q "Orchestrate-lite" skills/mono/playbooks/fanout.md && grep -q "orchestrate.md" skills/mono/playbooks/fanout.md && grep -q "force-with-lease" skills/stages/work/references/work-fanout.md && grep -qi "by cause" skills/stages/work/references/work-fanout.md && test "$(grep -c "^FORBIDDEN  no merge, rebase, force-push" skills/stages/work/references/work-fanout.md)" -eq 1` — R2/R3/R4 regression after T6/T5 edits: prints 6, FORBIDDEN prefix count 1, rc=0
  - `test -z "$(git diff --name-only a09ad26..HEAD | grep -E "skills/mono/playbooks/ship.md|check-risk.md|^\.github/|^scripts/ci/|install-git-hooks|^site/")"` — NG4 and NG5 paths untouched in the range, rc=0
  - scope: on target — autopilot.md (new), SKILL.md router, README, CHANGELOG, NOTICE, carried T6 edits (orchestrate.md, work-fanout.md:48/:62) and the Log-04:51 takeover-lease clause (work-fanout.md:48, ADR 0020 Decision 2 + Consequences), no wider than the accepted respawn rule. Unknown-cause retry default is a method rule under ADR 0016 Decision 1; max 2 then `blocked` kept. No text lets any agent merge outside ship.md § Land.
  - proof_classes: output, unit, integration
  - requirements: R5 met (both modes, owner never merges, labels banned, one full verification then one verifier per head, patch-id carry, stack only on dependency, `/loop 1h` by side effects, stop → `decision: hold`; grep 12), R6 met (router "seventeen" with separate fanout/orchestrate/autopilot rows; README 17 rows; CHANGELOG Added + Changed; NOTICE line)
  - rollback_point: a09ad26
  - requests: non-blocking — (1) ADR 0020 Decision 2 "names only the last pushed SHA" beside two Log-SHA clauses: rephrase; (2) optional Decision 3 note for the no-report default; (3) Log 04:53: workflow.png reads "twelve", pre-existing drift, next site pass; (4) NOTICE.md:7 add v0.15.36. Applied in the final pass (Log 04:58).
  - judge: independent
  - judge_model: claude-fable-5-1

## Current State and Next Action
- active_phase: autopilot
- lifecycle_status: in-progress
- blockers: none
- open_items: none
- exact_next_action: apply gate nits, then final check full + routing dry-run
