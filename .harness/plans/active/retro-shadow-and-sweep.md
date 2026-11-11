---
status: active
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
  - R2: `AGENTS.md` § Layout and Pipeline states in one line that repo-wide find/replace and rename sweeps exclude `.harness/plans/completed/`, whose Validation and Log entries the APPEND-ONLY guard keeps immutable. | acceptance: `grep -q "plans/completed/" AGENTS.md && bash scripts/ci/verify-doc-links.sh` | source: retro finding 2
  - R3: Findings 3 (`git grep \b` miss) and 4 (`feat!:` rejected by commit-msg) close with no change, because the doc-link gate and commit-msg hook already caught them in-session; the plan Log records that decision. | acceptance: `grep -q "finding 3" .harness/plans/active/retro-shadow-and-sweep.md && grep -q "finding 4" .harness/plans/active/retro-shadow-and-sweep.md` | source: retro findings 3, 4
- non-goals:
  - NG1: Auto-removing or reordering the shadowing binary; the installer only reports it.
  - NG2: Teaching the commit-msg hook the `type!:` breaking syntax.
  - NG3: Editing any file under `.harness/plans/completed/`.

## Phases and Verification
- approach: make the existing shadow warning fatal (exit 2) in place; rejected: a separate post-install check script, which would be one more thing to remember to run.
- phase_slug: `main`
  status: planned
  - goal: R1, R2, R3 | depends_on: none
  - surfaces: `scripts/install-zharness.sh`, `scripts/ci/test-install-zharness.sh`, `AGENTS.md`, `CHANGELOG.md` | avoided: `.harness/plans/completed/`, `scripts/install-git-hooks.sh`, commit-msg hook
  - phase check: `bash scripts/ci/test-install-zharness.sh && grep -q "plans/completed/" AGENTS.md && bash scripts/ci/verify-doc-links.sh`

## Log
- 2026-11-11 wave spawned: R1 lead (opus), R2 worker (sonnet), each in its own worktree off master `3bfcb1b`.
- 2026-11-11 integrated on fix/retro-shadow-and-sweep: R1 `498d025` (lead also anchored `invoke_install` PATH on the install target so S2-S4 do not trip the new shadow exit on a host with zharness installed; S6 now lacks any `zharness on PATH` line), R2 `bf9a549`. Negative proof (lead): new suite vs old script, S5 fails (exit 0, no error line).
- 2026-11-11 decision: retro finding 3 (`git grep \b` missed 3 files) and finding 4 (commit-msg rejected `feat!:`) close with no change; verify-doc-links and the commit-msg hook caught both in-session.
- 2026-11-11 note: R2 acceptance `grep -q "plans/completed/" AGENTS.md` already matched before R2 (Harness section); the real proof is `grep -q "rename sweeps exclude" AGENTS.md`, which matches only after `bf9a549`.

## Validation

## Current State and Next Action
- active_phase: main
- lifecycle_status: in_progress
- blockers: none
- open_items: R1, R2, R3
- exact_next_action: check full
