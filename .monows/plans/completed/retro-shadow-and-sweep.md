---
status: completed
lane: normal
---
# Retro fixes: shadowed zharness fails install; sweeps skip completed plans

## Goal
- outcome: `install-zharness.sh` fails when another zharness shadows the one it installed, and AGENTS.md tells agents that find/replace sweeps skip `.harness/plans/completed/`.
- success_signal: `bash scripts/ci/test-install-zharness.sh` passes with S5 expecting a non-zero exit, and `bash scripts/ci/verify-doc-links.sh` passes.
- actors: the owner and agents installing or upgrading zharness; agents running repo-wide renames.
- authority: owner approval of the 2026-11-11 retro ("fix hết 4 findings"); retro findings 1–4 in session a21d5afd; `scripts/install-zharness.sh:97`-`:102`; the APPEND-ONLY guard in `scripts/install-git-hooks.sh`.
- requirements:
  - R1: When the zharness first on PATH reports a version different from the freshly installed binary, `scripts/install-zharness.sh` prints an `error:` line naming both paths and versions and exits 2; the binary stays installed. | acceptance: `bash scripts/ci/test-install-zharness.sh` (S5 expects exit 2 and the `error: zharness on PATH is` line; S6 still exits 0 with no such line) | source: retro finding 1
  - R2: `AGENTS.md` § Layout and Pipeline states in one line that repo-wide find/replace and rename sweeps exclude `.harness/plans/completed/`, whose Validation entries and Log blocked/decision entries the APPEND-ONLY guard keeps immutable. | acceptance: `grep -q "rename sweeps exclude" AGENTS.md && bash scripts/ci/verify-doc-links.sh` | source: retro finding 2
  - R3: Findings 3 (`git grep \b` miss) and 4 (`feat!:` rejected by commit-msg) close with no change, because the doc-link gate and commit-msg hook already caught them in-session; the plan Log records that decision. | acceptance: `grep -q "decision: retro finding 3" .harness/plans/active/retro-shadow-and-sweep.md` | source: retro findings 3, 4
- non-goals:
  - NG1: Auto-removing or reordering the shadowing binary; the installer only reports it.
  - NG2: Teaching the commit-msg hook the `type!:` breaking syntax.
  - NG3: Editing any file under `.harness/plans/completed/`.

## Phases and Verification
- approach: make the existing shadow warning fatal (exit 2) in place; rejected: a separate post-install check script, which would be one more thing to remember to run.
- phase_slug: `main`
  status: done
  - goal: R1, R2, R3 | depends_on: none
  - surfaces: `scripts/install-zharness.sh`, `scripts/ci/test-install-zharness.sh`, `AGENTS.md`, `CHANGELOG.md` | avoided: `.harness/plans/completed/`, `scripts/install-git-hooks.sh`, commit-msg hook
  - phase check: `bash scripts/ci/test-install-zharness.sh && grep -q "rename sweeps exclude" AGENTS.md && bash scripts/ci/verify-doc-links.sh`

## Log
- 2026-11-11 wave spawned: R1 lead (opus), R2 worker (sonnet), each in its own worktree off master `3bfcb1b`.
- 2026-11-11 integrated on fix/retro-shadow-and-sweep: R1 `c0ed0cd` (cherry-pick of `498d025`) (lead also anchored `invoke_install` PATH on the install target so S2-S4 do not trip the new shadow exit on a host with zharness installed; S6 now lacks any `zharness on PATH` line), R2 `e779a72` (cherry-pick of `bf9a549`). Negative proof (lead): new suite vs old script, S5 fails (exit 0, no error line).
- 2026-11-11 decision: retro finding 3 (`git grep \b` missed 3 files) and finding 4 (commit-msg rejected `feat!:`) close with no change; verify-doc-links and the commit-msg hook caught both in-session.
- 2026-11-11 verifier requests applied: R2 wording narrowed to Validation entries and Log blocked/decision entries (scripts/install-git-hooks.sh:74-76); R2 and R3 acceptance now fail without the change (`! git show master:AGENTS.md | grep -q "rename sweeps exclude"` confirmed); CHANGELOG notes the skipped `update --check --all`. Optional S5 full-line assert and same-version scenario not taken.

## Validation
- 2026-11-11T15:30Z — phase `main` — verdict: APPROVE_WITH_REQUESTS — mode: full
  - `bash scripts/ci/test-install-zharness.sh` — summary: 6 passed, 0 failed (S5 exit 2 + error line + binary kept; S6 silent)
  - `bash scripts/ci/verify-doc-links.sh` — doc links OK (0 findings)
  - `grep -q "rename sweeps exclude" AGENTS.md` — rc=0 (absent on master)
  - `grep -q "decision: retro finding 3" .harness/plans/completed/retro-shadow-and-sweep.md` — rc=0
  - scope: on target — 5 declared surfaces only; nothing under completed plans except this plan
  - proof_classes: output, unit, integration (S1-S6 run the real installer end to end against a stub gh)
  - requirements: R1 met (S5/S6) | R2 met (grep, negative on master) | R3 met (Log decision)
  - rollback_point: 3bfcb1b3b787cc9e2d75e134e9cc2d699f53c95d
  - requests: 1 R2 wording overstated APPEND-ONLY scope (AGENTS.md:13) — applied; 2 Log cited worktree-only SHAs — repointed; 3 R2/R3 acceptance passed without the change — tightened; 4 optional S5 full-line assert and same-version scenario — not taken
  - judge: independent
  - judge_model: claude-opus-5-5
  - judged_sha: 8b59e821f5092e7a7c01a5cceddb3e4827617082

## Current State and Next Action
- active_phase: none
- lifecycle_status: completed
- blockers: none
- open_items: none
- exact_next_action: none
