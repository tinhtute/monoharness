---
status: active
lane: high-risk
---
# Move the zharness managed layout from .harness/ to .monows/

## Goal
- outcome: zharness, its router, the pre-commit guards, CI and this repo use `.monows/` wherever they used `.harness/`, keeping the rest of each path, so they match the skills in PR #268 and the monows consumer layout. `zharness update` moves an existing `.harness/` tree to `.monows/` the same way v0.31.0 moved `docs/` to `.harness/`.
- success_signal: the AGENTS.md gate commands pass on one branch stacked with #268, `git grep -I '\.harness' -- ':!.harness/plans/completed' ':!.monows/plans/completed' ':!CHANGELOG.md' ':!docs/decisions'` finds only migration code and its tests, and the Exercise recipe works on a fresh repo (install creates `.monows/`) and on a repo that still has `.harness/` (update moves it).
- actors: the owner (ní); the main agent; the monows session (ttdvkh-cb), which owns the consumer layout.
- authority: the owner on 2026-11-12: "đổi luôn", a hard switch with no read-both shim (Q21). The monows audit-cleanup plan R17 sets the consumer layout `.monows/{engine,config,state,plans,runs,docs}` and keeps each path's tail. The independent risk judgment on #268 lists the gaps this plan closes.
- decisions (owner, 2026-11-12):
  - Q1: `WORKFLOW.md` and `PROJECT.md` live at `.monows/WORKFLOW.md` and `.monows/PROJECT.md`.
  - Q2: zharness does not create `.monows/{engine,config,state}`; monows owns them.
  - Q3: ship as 0.37.0, stacked on #268.
- requirements:
  - R1: the installer's managed targets (`WORKFLOW_TARGET`, `PROJECT_TARGET`, `HARNESS_DIR`, `ACTIVE_PLANS_DIR`) and the `.gitignore`/AGENTS.md projections name `.monows/`. | acceptance: `cd cli && cargo test` passes, with layout tests that assert the `.monows/` paths
  - R2: `zharness update` renames `.harness/WORKFLOW.md`, `.harness/PROJECT.md` and `.harness/plans` to `.monows/` and re-keys the manifest, ownership ledger and captured originals. If both copies exist it refuses before writing anything. The `docs/` → `.harness/` moves become `docs/` → `.monows/`. | acceptance: `cd cli && cargo test --lib installer` passes, with new layout tests for the move, the conflict and the docs-era chain
  - R3: the router `cli/docs/embedded/WORKFLOW.md` and its mirror `.monows/WORKFLOW.md` name `.monows/`. | acceptance: `cd cli && cargo test --test projection_parity` passes
  - R4: the pre-commit guards (R5 one-active, PLAN-SHAPE, APPEND-ONLY, BASELINE, PHASE-DONE, proof re-execution) and `scripts/workflow/baseline.sh` watch `.monows/plans/`. Their fixtures move with them. | acceptance: `bash scripts/ci/test-guards.sh` passes
  - R5: CI paths (`.github/workflows/cli-ci.yml`), `scripts/ci/verify-doc-links.sh`, `scripts/ci/hook-guard.sh` and `.claimignore` name `.monows/`. | acceptance: `bash scripts/ci/verify-doc-links.sh && bash scripts/ci/test-pr-guards.sh`
  - R6: this repo moves its tree with `git mv .harness .monows`, and AGENTS.md, README.md, `docs/` and `site/` describe `.monows/`. Completed plans move as whole files and their bytes stay the same (APPEND-ONLY). | acceptance: `test ! -e .harness && bash scripts/ci/verify-doc-links.sh`
  - R7: PR #268 and this change land together. Either #268's commit moves to this branch, or this branch merges right after #268 with no release in between. | acceptance: `gh pr view <n> --json commits` shows the #268 skills commit, or #268 is merged at this branch's base
- non-goals:
  - NG1: a read-both shim or a `.harness/` fallback in the skills (owner decision, Q21).
  - NG2: creating or owning `.monows/{engine,config,state}` (Q2).
  - NG3: rewriting the text of completed plans. Their old `.harness/` paths stay as history.

## Phases and Verification
- approach: repeat the v0.31.0 `docs/` → `.harness/` migration (`cli/src/installer/layout.rs`) with one more hop, then the guards, CI, and finally this repo's own tree. Rejected: a symlink `.harness → .monows`, which leaves two names for one contract and still needs a guard pass.
- phase_slug: `installer`
  status: done
  - goal: R1, R2, R3 | depends_on: none
  - surfaces: `cli/src/installer/**`, `cli/src/lib.rs`, `cli/src/embedded.rs`, `cli/docs/embedded/WORKFLOW.md`, `cli/tests/**` | avoided: `scripts/**`, the repo's own `.harness/`
  - wave 1:
    - T1 Change the targets and add the `.harness` → `.monows` hop to `layout.rs` and `update.rs`, red tests first (owner: main agent) — output: R1, R2 — check: `cd cli && cargo test --lib installer`
    - T2 Rewrite the router paths and the pinned contract phrases (owner: main agent) — output: R3 — check: `cd cli && cargo test`
  - phase check: `cd cli && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test`
- phase_slug: `guards`
  status: done
  - goal: R4, R5 | depends_on: `installer`
  - surfaces: `scripts/install-git-hooks.sh`, `scripts/ci/**`, `scripts/workflow/**`, `.github/workflows/**`, `.claimignore` | avoided: `cli/**`
  - wave 1:
    - T3 Retarget the guards and their fixtures, then reinstall the hook with `bash scripts/install-git-hooks.sh --force` (owner: main agent) — output: R4 — check: `bash scripts/ci/test-guards.sh`
    - T4 Retarget CI paths and the doc-link script (owner: main agent) — output: R5 — check: `bash scripts/ci/verify-doc-links.sh && bash scripts/ci/test-pr-guards.sh`
  - phase check: every AGENTS.md gate command
- phase_slug: `repo`
  status: done
  - goal: R6, R7 | depends_on: `guards`
  - surfaces: `.harness/` → `.monows/`, `AGENTS.md`, `README.md`, `docs/**`, `site/**` | avoided: completed-plan bytes
  - wave 1:
    - T5 `git mv .harness .monows`, then update docs, run the Exercise recipe on a fresh repo and on a repo with `.harness/` (owner: main agent) — output: R6 — check: `test ! -e .harness && bash scripts/ci/verify-doc-links.sh`
    - T6 Bring #268 onto this branch or line up the merge order, and get an independent `check full` with a risk verdict (owner: main agent, then owner) — output: R7 — check: `gh pr checks <n>`
  - phase check: every AGENTS.md gate command, the Exercise recipe, and the success_signal grep

## Log
- 2026-11-12T09:40Z — main — decision — plan opened from the #268 risk judgment (needs review: guards, installer and router still on `.harness/`); kept under `.harness/plans/active/` until phase `repo` moves it, because the guards watch only that path today
- 2026-11-12T09:45Z — main — decision — owner answered Q1 yes (both files in .monows/), Q2 no (monows owns engine/config/state), Q3 0.37.0 stacked on #268
- 2026-11-12T10:55:35Z — repo — decision — baseline: 10470a891c6b9293144850b6a6a8207ea70cff24 cd cli && cargo test -q rc=0
- 2026-11-12T10:55:50Z — repo — decision — baseline: 10470a891c6b9293144850b6a6a8207ea70cff24 bash scripts/ci/test-guards.sh rc=0
- 2026-11-12T10:55:51Z — repo — decision — baseline: 10470a891c6b9293144850b6a6a8207ea70cff24 bash scripts/ci/verify-doc-links.sh rc=0
- 2026-11-12T10:55Z — main — done — phases installer, guards and repo landed on `chore/skills-monows-paths` with the #268 skills commit (R7: one branch); `update` moves `.harness/` → `.monows/`, refuses on two copies; guard S6c covers APPEND-ONLY across the move

## Validation

## Current State and Next Action
- active_phase: repo
- lifecycle_status: in_review
- blockers: `risk-verdict` needs the owner's `owner-reviewed` label (high-risk lane; agents never apply it)
- open_items: release 0.37.0 after merge
- exact_next_action: owner reviews PR #268 and labels it; then merge and cut 0.37.0
