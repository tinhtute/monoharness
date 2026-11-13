# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Pre-commit guards: committing a merge no longer re-judges `## Validation` entries the other parent already committed. An entry byte-identical to one in a `MERGE_HEAD` parent's copy of the plan is old, so R8 stops rejecting its `judged_sha` as out of range; an entry written into the merge itself is still guarded. The PR and pre-push ranges start at the merge-base and already treated such entries as old; fixtures now cover them and the master push range. The hook reads the guard core from the installer on every run, so no reinstall is needed.
- `test-risk-facts.sh`, `test-risk-verdict.sh` and `test-agent-models.sh` unset the caller's `GIT_*` environment, so re-running them as a proof from a git hook no longer creates branches, moves refs or flips `core.bare` in the calling repository.
- `install-agents.sh` retires a `lead.md` only when it carries the old harness agent's description; a user's own `lead.md` is kept. CI covers both cases.
- `work-fanout.md`: a `BLOCKED (spec)` that names a missing VERIFY or ACCEPTANCE line is the main agent's brief gap (fill it and re-brief), not the owner's; free re-briefs stop at two per unit, and a third `BLOCKED` or brief gap goes to the owner.

### Changed

- Names follow pstack: the `fanout` playbook is now `swarm` (`skills/poteto/playbooks/swarm.md`), `work-fanout.md` is now `work-swarm.md`, and `worker` and `engineer` describe a "swarm wave". `install-agents.sh` still matches the old `lead` description to retire it.
- `check-exercise.md`: readiness means usable, a read-only doctor runs before driving and after a failed drive, a dry-run is trusted only for what you saw it skip, and cleanup stops what the run started by handle and keeps the evidence.
- `mono-write` rules carry stable IDs (`P1`–`P6`, `C1`–`C5`) that reviews can cite; a removed rule leaves a gap.
- Rules ported from pstack: a `work-swarm.md` measurement brief names its method (sample count, what one sample is, order), the report records it with the SHAs, and a worker that proves a defect lists every one; `arena` ships converged candidates without a graft and sends a verify failure back to the frame or the graft; a `check-review.md` failure finding is kept only when re-running its command reproduces it.
- `risk-facts.sh` reports `test_changes.assertions_changed`: each file whose diff both removes and adds assertion or test-case lines, such as `assert x == 5` edited to `assert x is not None`. `assertions_removed` nets such an edit to zero, so the `test-weakening` gate passed it. The `risk-verdict` check now treats the new fact as a hit, so a PR that edits an assertion in place needs the owner's review; `test-weakening` still fails only on a net removal. Over the last 60 merged PRs, the new fact raised one hit, on a PR that already needed review. Not covered: an edit to a continuation line of a multi-line assertion, and an assertion edited in a file that the same diff renames.
- **Breaking:** the `risk-verdict` check accepts a low-risk verdict only when its `**Verdict:**` line ends with `judge_session: <id>`, the judge sub-agent's id as the host reported it to the Lead (`[A-Za-z0-9-]+`, shape only); `judge_session: none` on an independent verdict fails. Re-judge an open PR whose verdict line predates this. The `ship` Land step now has the Lead write the id.
- **Breaking:** the `lead` agent is renamed `engineer`, so it no longer shares a name with the main session's lead role. `install-agents.sh` retires an installed `lead.md` as `lead.md.retired.<timestamp>`; dispatch `engineer` from now on. Reinstall with `bash scripts/install-agents.sh`.
- `engineer` and `worker` own their outcome instead of serving as "a delegate of a mono lead": the brief's approach is a hypothesis, and `BLOCKED` now carries a reason (`spec`, `premise` with evidence and one alternative, or `scope` naming the file it needs, never editing outside SCOPE). A failed DESIGN with an in-SCOPE change that meets every ACCEPTANCE line and changes nothing beyond the GOAL is made and reported as `PASS (DESIGN deviation)`; ACCEPTANCE lines no change can meet together are `BLOCKED (spec)`.
- `work-fanout.md`: the brief gains a `DESIGN` field (a hypothesis or `open`, never the fix in disguise); the main agent answers a `BLOCKED` reason before any retry, and that answer costs no retry, and judges a `PASS (DESIGN deviation)` against GOAL and ACCEPTANCE, never the DESIGN; the same symptom after a retry stops the ladder until the shared mechanism is found.
- **Breaking:** `lead` and `worker` stop with `BLOCKED` on a brief that reads two ways instead of picking a reading, and `worker` refuses a brief with no acceptance command. Reinstall with `bash scripts/install-agents.sh`.
- `scout`'s description asks the main agent to use it proactively in place of the built-in Explore, inside or outside a wave; pair it with `Agent(Explore)` in `permissions.deny` (monoclaudian settings) to enforce it.
- `work-fanout.md` maps each role to its harness agent, drops `haiku` from mechanical edits (`scout` never edits), sends an open spec back to the owner before spawning, and extends the retry ladder: add a real check first, then `effort: high`, then the next model (`worker` → `lead` → `lead` on `fable`), never effort past `high`.

### Added

- `cli/tests/exercise_recipe.rs` runs the AGENTS.md § Exercise recipe on the built `zharness` binary in a fresh `git init` repository with a scratch `XDG_CONFIG_HOME`. After `install` then `uninstall`, `git status --porcelain` is empty, no file is left outside `.git` (ignored ones included), and the repository is no longer registered. A second case runs `install` from a subdirectory and checks that the files land at the git toplevel. The unit tests had covered only the library on a plain tempdir.

## [v0.37.0] — 2026-11-12

### Changed

- **Breaking:** the managed layout moves from `.harness/` to `.monows/` (`WORKFLOW.md`, `PROJECT.md`, `plans/`), matching the skills and the monows consumer layout. `zharness update` renames an existing `.harness/` tree, re-keys the manifest, ownership ledger and captured originals, and refuses before writing when both copies exist. The pre-commit guards, `baseline.sh` and CI watch `.monows/plans/`; APPEND-ONLY resolves a plan moved from `.harness/plans/` to its predecessor. Migrate: run `zharness update` in each managed repo and reinstall skills at the same time (`npx skills add …`); contributors to this repo re-run `bash scripts/install-git-hooks.sh --force`. (#268)

## [v0.36.1] — 2026-11-11

### Added

- Risk-judge eval: owner labels and first predictions (#263).

### Changed

- `install-zharness.sh` exits 2 when another zharness earlier on PATH (for example a mise shim of `~/.cargo/bin`) reports a different version; the new binary stays installed and the final `zharness update --check --all` is skipped. (#266)
- `AGENTS.md`: repo-wide rename sweeps exclude `.harness/plans/completed/`. (#266)

## [v0.36.0] — 2026-11-11

### Added

- Harness agents are tiered by task complexity in `models.json` (scout fast, worker sonnet, lead and verifier opus); the verifier runs on high effort with a fable advisor (#259, #260).
- `AGENTS.md` § Unattended Shipping can declare review-exempt paths for the risk verdict (#262).

### Changed

- **BREAKING:** the entry router skill `mono` is renamed `poteto` (`skills/poteto/`, `/poteto <task>`). Reinstall skills and remove the old `mono` skill.
- **BREAKING:** the harness agents drop the `mono-` prefix: `scout`, `worker`, `lead`, `verifier`. `install-agents.sh` retires the old `mono-*` agents.

## [v0.35.0] — 2026-11-10

### Added

- Pre-commit guards: an allowlisted `judge_model` and in-range `judged_sha` on high-risk and `full` Validation entries (#214), active-plan Goal shape (#217), append-only Validation and Log decisions outside handoff compaction (#218), and a recorded baseline before a plan's first `done` (#219), plus `scripts/workflow/baseline.sh`.
- `scripts/ci/pr-guards.sh` and the `pr-guards` workflow run the secret scan and commit-message check over a PR range; `docs/guides/consumer-ci-guards.md` gives consumers a CI template (#216).
- `mono-verifier` has `maxTurns: 30` and judges inside a read-only worktree from `scripts/workflow/readonly-worktree.sh` (#215).
- `evals/risk-judge/` scaffold (label format, split, TPR/TNR report) and a nightly `cargo mutants` workflow for `cli/src/installer`; labels are pending (#221).

### Changed

- ADR 0010 (local failure ledger) is marked Superseded by `d8ed43e`, which removed `docs/evals/failures.md`; the last ledger is at `d8ed43e^` (#224).
- Pre-commit guards: an R8 `judged_sha` outside the range still passes when a range commit has the same `git patch-id` (a rebase keeps the verdict); PLAN-SHAPE accepts `- authority:` with nested sub-bullets; APPEND-ONLY compares a renamed plan against its rename source; BASELINE requires the baseline in an entry before the first `done`, not inside it. Rerun `bash scripts/install-git-hooks.sh --force`.
- `verify-doc-links.sh`: a directory-wide `.claimignore` entry no longer exempts paths cited by an Accepted ADR; only a per-file entry does.
- `readonly-worktree.sh` creates writable `target/` and `tmp/` siblings, and `mono-verifier` exports them as `CARGO_TARGET_DIR` and `TMPDIR` so gates run inside the read-only worktree.
- CI runs `evals/risk-judge/test_report.py` (skills-ci `risk-facts`).

## [v0.34.0] — 2026-11-09

### BREAKING

- `setup/` moved to the separate repo [monoclaudian](https://github.com/tinhtute/monoclaudian)
  (global `CLAUDE.md`, rules, settings, mods, statusline, `install.sh`).
- The harness agents are renamed `mono-lead`, `mono-worker`, `mono-verifier`, live in
  `agents/` with model policy in `models.json`, and install via `scripts/install-agents.sh`.
- The git hook installer moved to `scripts/install-git-hooks.sh`; rerun
  `bash scripts/install-git-hooks.sh --force`.
- Run `bash scripts/install-agents.sh` to install the renamed agents; it retires the old
  `~/.claude/agents/{lead,worker,verifier}.md` by renaming each to
  `<name>.md.retired.<timestamp>`, so remove those once you no longer need them.
- `tldraw-diagram`, `prompt-leverage`, `create-skill`, `create-cli`,
  `turbo-mono-platform` and the full `write` skill (with its `evals/`) moved to
  [monoclaudian](https://github.com/tinhtute/monoclaudian); `skills/extras/` is gone.
  Install them with
  `npx skills add git@github.com:tinhtute/monoclaudian.git -a claude-code -g -y`; otherwise trash the old copies from `~/.claude/skills/` and `~/.agents/skills/`.
- `brainstorm` 6.0.0 keeps only `explore`, `lock` and `refine`.
  **Migration:** `/brainstorm grill` → `/grill`, `/brainstorm raw` → `/grill raw`.
  Install the new `grill` and `wayfinder` skills.
- The `research` and `ship` playbooks and `learn` now call `mono-write`, a slim skill
  that polishes a research draft and writes CHANGELOG entries and release notes. It
  hands any other writing to monoclaudian's `write` when that skill is installed.
  Reinstall this repo's skills to get `mono-write`.

### Added

- `hillclimb` and `pause` playbooks in `mono`, adapted from upstream
  [cursor/plugins `pstack/`](https://github.com/cursor/plugins/tree/main/pstack).
  `hillclimb` pushes one metric toward a target with a stop predicate that has a
  floor on attempts, a frozen harness, a `decision.tsv` log outside the repo, and
  one keep-or-revert change per attempt on a dedicated branch. `pause` stops at a
  safe boundary, writes Current State through `handoff` (or the commit body when no
  plan is active), and makes one `chore(wip)` commit off the default branch.
- `wayfinder` skill for a Goal whose decisions span sessions. It keeps a `## Map` of
  typed questions (`grill`/`prototype`/`research`/`task`, HITL or AFK, `blocked_by`)
  and `fog:` lines in the active plan, fans out AFK research to sub-agents, settles
  at most one HITL question per session, caps prototypes, and resumes from
  `exact_next_action: wayfinder`. `brainstorm lock` then locks the decided map in
  place and writes the lane's phase. `watzup` shows the map's frontier.
- `grill` skill: the grill loop as its own skill, with `raw` for a fast first pass.
- `session-digest.py --json`; token usage now counts each API message once and
  skips sub-agent records in stream-json traces.
- CI `test-weakening` gate (#212): a PR that deletes a test file, adds a skip marker
  or trivial assertion, or removes more assertion/test-case lines than it adds fails
  unless the owner applies the `allow-test-weakening` label; agents never apply it.
  `risk-facts.sh` reports the new `test_changes.assertions_removed` and runs from the
  base revision in the gate, so a PR cannot neuter it.
- CI `risk-verdict` gate (#213): a PR merges only when its `## Risk` section says
  low risk, judged on the head SHA by an independent judge whose `judge_model` is in
  the base branch's `models.json` `judges` (fable, opus), and the base revision's
  `risk-facts.sh` reports no hit; otherwise the owner applies the `owner-reviewed`
  label after review. The Risk verdict line now carries `judge_model: <model>`.
- Hook guard R7 (#211): an approving `## Validation` entry is rejected when a proof
  cannot fail: only `true`, `:`, `exit 0`, `echo` or `printf`; a `cargo test` run that
  passes 0 tests; or a range that adds a Rust `#[test]` with an empty body. Rerun
  `bash scripts/install-git-hooks.sh --force`.
- `orchestrate` and `autopilot` mono playbooks (ADR 0020): a multi-day program of many
  units or PRs, and a queue of PRs taken to verified, or merged via ship § Land on
  explicit request. The router now lists seventeen playbooks.

### Changed

- `fanout` keeps one in-session wave; multi-day programs go to `orchestrate`.
- `work-fanout` retries a failed agent by cause, at most 2 times.
- PR-owner exception to FORBIDDEN: a PR owner spawned by `orchestrate` or `autopilot`
  may rebase and force-push only its own PR branch under a pinned
  `--force-with-lease`; a respawned or takeover owner pins the SHA the plan Log records.

### Fixed

- Security: the `risk-verdict` and `test-weakening` gates run on `pull_request_target`
  from the base branch, so a PR can no longer rewrite its own gate workflow or script;
  the PR head is fetched as data and never executed, and `test-weakening` no longer runs
  the head copy of `risk-facts.sh`. `cli-ci` jobs get a read-only token.
- CI `hook-guard` runs the guard core from the base revision instead of the commit
  under test (`scripts/ci/hook-guard.sh`), so a commit can no longer neuter its own
  proof guard; a range that edits `scripts/install-git-hooks.sh` must pass both the
  base and the head guard (#210).

## [v0.33.0] — 2026-10-29

### Added

- `ship` land step: an independent judge writes a `## Risk` verdict into the
  PR body; with `Auto-merge: low-risk` in the base branch's `AGENTS.md`, a
  low-risk PR merges after green via `--match-head-commit`, never `--auto`.
  Needs-review PRs print **Where to look** and never merge (#181).
- `check`: exercise proof (`check-exercise.md`) and the risk rubric
  (`check-risk.md`).
- Pre-commit guard R6 LANE-RAISE: a declared lane is raised to high-risk when
  the range touches an always-review path (`AGENTS.md`, `*schema*`, and the
  `AGENTS.md` list); fails closed when no range resolves. Reinstall hooks with
  `bash setup/install-git-hooks.sh --force`.
- `mono`: prior-art step before building (#180).
- Setup: guards and the compaction reminder move into the ninja-kit mod;
  privacy and URL guards wired; statusline token weather icon.
- `create-skill` teaches context engineering and progressive disclosure.

### Changed

- Skills trimmed: repeated context removed, `think`/`hunt` detail moved into
  references.
- Release merges use `AGENTS.md` `Merge method` (default `squash`).

## [v0.32.0] — 2026-10-26

### Changed

- **BREAKING:** the entry router skill is `mono` (`skills/poteto/`, `/mono <task>`),
  not `mono-mode`. Reinstall skills and remove any installed `mono-mode` copy.
- The managed `WORKFLOW.md` names `check.md` § Lane Matrix as the only source
  of lane → required proof, final check mode, and judge independence. Run
  `zharness update` to refresh it.
- `check`: the Lane Matrix is authoritative; normal plans no longer auto-run
  `full`, and the normal-lane gate has no manual review. `work-full` gates
  `stop_if` and `escalate_when` fail-closed.

### Added

- `check`: opt-in multi-model panel review (ADR 0018) with an executable merge
  step, `scripts/panel-merge.py`, and fixture tests in CI (#156).
- `read` and `learn` skills, plus `research`, `ship`, `babysit`, `fanout` and
  the other pstack playbooks in the `mono` router.
- Role agents (`lead`, `worker`, `verifier`, `test-runner`) pinned by
  `setup/models.json`.
- CI validates every tracked `SKILL.md` (#167).

### Fixed

- Secret-scan hook reads binary blobs in the C locale.

## [v0.31.0] — 2026-10-23

### Changed

- **BREAKING:** managed files move from `docs/` to `.harness/`:
  `.harness/WORKFLOW.md`, `.harness/PROJECT.md` and
  `.harness/plans/{active,completed}/`. `zharness update` renames the old
  paths in place, so plan bytes stay identical; it refuses when both the old
  and the new copy exist. Stage skills, the pre-commit plan guards and the
  AGENTS block name only the new paths. Upgrade in this order: install this
  binary, run `zharness update`, reinstall the git hook
  (`bash setup/install-git-hooks.sh --force`), then refresh skills.
- `zharness update --check` reports a repository on the old layout as drift.
- The pre-commit plan guards treat a plan moved from `docs/plans/` to
  `.harness/plans/` as the same plan, so committing the move re-runs only
  entries it adds.
- Repository layout: gate scripts live in `scripts/ci/`, stage helpers in
  `scripts/workflow/`, machine setup (`CLAUDE.md`, rules, hooks, installers,
  statusline) in `setup/`, and guides in `docs/guides/`.

### Removed

- Lean eval: `docs/evals/` and its scripts (`run-lean-trial.sh`,
  `lean-replay-score.sh`, `verify-lean-eval.sh`, `test-lean-eval.sh`,
  `generate-dashboard.sh`, `probes/`). Recover them from the
  `archive/lean-eval-v1` tag.

## [v0.30.0] — 2026-10-23

### Added

- `mono-mode` fanout playbook with an orchestrate-lite section for long
  multi-unit runs.
- `arena` reason skill: a design bakeoff that picks a base and grafts on the
  best parts of the other candidates.
- `work-fanout.md` companion: separate writers, brief and verify handbacks,
  integrate one branch at a time; pinned by a `zharness` contract.

### Changed

- Install warns when an older `zharness` shadows the new one on `PATH`.

## [v0.29.0] — 2026-10-22

### Added

- `mono-mode` router skill with feature, bug-fix, investigation, and
  session-pickup playbooks; handback proof rule; stale-hook and validator
  trip guards in `scripts/test-guards.sh`.
- `work-bounded.md` companion: bounded mode split out of `work`.

### Changed

- Skills regrouped into `router/`, `stages/`, `reason/`, `tools/`, `extras/`;
  `zharness` reference contracts follow the new paths.
- Workflow: pstack principles inlined into stage skills; retro findings
  applied (ref contract gate, handoff plan slicing, brainstorm reads its named
  reference).
- Setup `CLAUDE.md`: mandatory TinyFish web-access rule.

## [v0.28.0] — 2026-10-21

### Added

- Statusline: `★` reads Claude Code's `prompt_cache` (session hit rate, TTL
  countdown, labelled misses); `ϟ` tpm sums deduped output tokens per
  API-minute; `refreshInterval` is 30 so the countdown ticks while idle.
- Evals: lean-v1 protocol (ADR 0016), evidence verifier, trial runner, and
  observational replay scorer (`scripts/lean-replay-score.sh`) with a B-era
  baseline.

### Changed

- `zharness`: workflow playbooks move out of the binary into each owning
  skill's `references/` (ADR 0015). `update` retires the recorded legacy
  playbook copies safely — edited or unknown files and recovery data are
  kept — and `uninstall` keeps consumer originals for retired paths.
- Workflow: normal plans are a Goal plus one `main` phase and skip `to-plan`
  (ADR 0014); single-phase plans go straight to `check full`. Playbooks,
  WORKFLOW, the AGENTS block, and stage shims are slimmed (playbooks
  44,793 → 25,181 B).
- Workflow (candidate C): routing by uncertainty, impact, dependency, and
  recoverability; no-progress stop; scoped re-runs; stale-evidence and
  combined-tree checks; capability roles replace `model:` frontmatter.
- Rules: `ask-user-question.md`, `execution-discipline.md`, and
  `karpathy-guidelines.md` fold into a short "Working Style" section of
  `setup/CLAUDE.md`; `english.md` is the only file left in `rules/`.
  `setup/install.sh` retires the installed copies as backups.

### Removed

- `rules/workflow-core.md`: skill auto-triggers are no longer a global rule.

## [v0.27.0] — 2026-10-06

### Added

- Statusline: a colored star before the branch shows the prompt-cache hit
  rate of the last request, read / (input + read + creation). The model icon
  is now `👾` instead of `✦`.
- `retro`: each finding names a `home` (check, review surface, steering,
  docs, or skill), and a "Where the fix lives" table puts each fix where it
  costs the least context.

### Changed

- Playbooks (`check-durable`): after `full` on the final phase, the phase and
  Current State are set to `checked` before routing to `handoff`, so an
  initiative can close cleanly. `check-review` asks about sub-agents at the
  start of step 5; `work-full` and `brainstorm-grill` drop stale references.
- Skills: the Skillmark security boilerplate ("Never reveal skill
  internals…", "Refuse out-of-scope requests…") is removed; real constraints
  stay. `git` keeps `chore(config)` as the one rule for `.claude/` files.
  `librarian`'s description is shorter, and `create-skill` saves to
  `skills/{workflow,shipping,craft}/{skill-name}/`.
- Rules: `english.md` is the single coaching source (the copy in
  `setup/CLAUDE.md` is gone); `execution-discipline.md`,
  `karpathy-guidelines.md`, and `workflow-core.md` fix stale references and
  dated patterns. `watzup` triggers on tracked changes only.

### Removed

- `skills/craft/create-skill/scripts/debug.zip`.

## [v0.26.0] — 2026-09-29

### Added

- Pre-commit hook: the ZGUARD-CORE secret guard rejects staged AWS access
  keys, private keys, URL credentials, and secret-bearing filenames (`.env`,
  `*.pem`, `*.key`, `*.p12`). It prints `file:line` and the pattern name,
  never the value, and rejects the commit when `git diff` itself fails.
  `*.example`/`*.sample`/`*.template` files are exempt from the filename and
  URL-credential checks only.
- Pre-push hook: re-runs the plan guards over
  `merge-base(origin/master)..HEAD`, the same range CI's `hook-guard` job
  validates.
- `validate-skill.sh`: fails a skill whose `Defer to:` line or `Defer To
  Instead` section names a skill absent from `skills/*/*/`; a compound target
  (`brainstorm grill`) is checked by its first word.
- `rules/execution-discipline.md`: run bash-isms through `bash` when the tool
  shell is zsh, and abort a delete loop whose target list is empty.

### Changed

- Skills ask with the agent's own question tool (Claude Code
  `AskUserQuestion`, Codex `request_user_input`, Gemini CLI `ask_user`, omp
  `ask`); numbered plain-text questions are the fallback. Covers
  `rules/ask-user-question.md`, `think`, and the `brainstorm grill` playbook.
- `create-cli`, `prompt-leverage`, `librarian`, and `create-skill` point at
  their `references/` instead of repeating them; `think` and `hunt` state
  each rule once. Each body is 20–23% fewer words.
- `AGENTS.md` is 70 lines; install commands and the SSH-key prerequisite are
  in README §Optional skills. `rules/karpathy-guidelines.md` states each
  instruction once (357 words).

### Fixed

- `create-skill`, `create-cli`, and `turbo-mono-platform` defer to `check`
  instead of the nonexistent `review` skill.

## [v0.25.0] — 2026-09-27

### Added

- `to-plan`: tasks are sliced as tracer bullets (vertical, one context
  window each, prefactor first; a wide mechanical refactor is its own task),
  and the section records `seams:` — the public interfaces tasks are tested
  at. A new seam is confirmed with the user before the section is written.
- `work` (full): a behavior task runs red → green at its planned seam — a
  failing test first, then the least code that passes. The `done` Log line
  names the test that went red. A test needed at an unplanned seam is a plan
  gap, logged as a `decision`.
- `check`: the `full` review (and a `bounded` diff review) runs on two axes
  kept apart — Spec (requirements missing, partial, wrong, or scope creep)
  and Standards (repo standards, Security/Performance/Architecture/Quality,
  a Fowler smell baseline, and test anti-patterns) — reported without
  cross-axis reranking. One agent runs both axes by default; `full` uses two
  parallel sub-agents only when the request asks for them or the user picks
  them at a one-time prompt. `bounded` never spawns sub-agents unless asked.
- `skills`: `retro`, a user-invoked session retrospective. It reads a
  session through `scripts/session-digest.py` (token and compaction
  totals, tool-call counts, errors, repeated calls, largest results, user
  prompts, structured-question answers), checks the repo's existing
  guards and review surface first, reports at most 5 evidence-cited findings
  ranked `S1`–`S3` with one marked `Next`, and — only after the user approves
  it — fixes that one finding as a guard or as a rerun-gated experiment.
- `brainstorm` 5.0.0: subcommands `explore` (default), `grill`, `raw`,
  `lock`, `refine`. `grill` walks a design tree in frontier rounds: each
  round asks every decision whose prerequisites are settled, with a
  recommended answer on each question. The agent looks up facts itself; only
  decisions go to the user; decisions only an absent person can make become
  `open_question: … | owner: …`. Each round also stress-tests terms, edge
  cases, and code contradictions. The grill is done when the frontier is
  empty and `to-plan` could plan from the Goal without a single question;
  it flags `adr candidate` decisions, then offers a lock. `raw` runs at most
  2 rounds and prints decided / assumed / open.

### Removed

- `cli`: the golden replay test (`tests/golden.rs`), the Go-manifest
  compatibility test (`tests/go_manifest_compat.rs`), and their fixtures under
  `cli/testdata/golden/`. Every edit to an embedded playbook forced a hand
  re-bless of those fixtures. CLI output and exit codes, and reading a
  manifest written by Go v0.23.1, are no longer covered end to end;
  `projection_parity` and the unit tests remain.
- `skills`: `encode-invariant` and `improve-harness`, folded into `retro` as
  its guard and experiment fix modes. Their references moved unchanged to
  `skills/workflow/retro/references/`. **Migration:** reinstall the skills;
  invoke `/retro` where you invoked either removed skill. A plan already at
  `docs/plans/active/harness-improvement-{slug}.md` keeps working as is.
- `skills`: `interview`, folded into `brainstorm grill` (deep) and
  `brainstorm raw` (fast). Its separate validated-spec template is gone; a
  grill writes the plan's `## Goal` directly on an approved lock.
  **Migration:** invoke `/brainstorm grill [idea|plan path]` where you
  invoked `/interview`, and `/brainstorm raw` for `mode:fast`.

### Changed

- Workflow token slim, phase 1 (`git show 3bab3c0:docs/audit/workflow-token-slim-audit.md`
  R1, R4–R7, R9): `git` carries the commit flow in `SKILL.md` and reads
  `references/workflow.md` only for `pr`/`merge`; `AGENTS.md` drops the
  directory tree and pipeline prose for a pointer to
  `skills/workflow/README.md`; `rules/` folds the restated discipline
  sections into a new `karpathy-guidelines.md` §5; `hunt` reads only the
  matching section of `failure-patterns.md`; `think` carries its four core
  lenses inline. Workflow `SKILL.md` frontmatter keeps one `version:`, and
  `hunt`/`think` attribution moves to each skill's `NOTICE.md`.

- Workflow token slim, phase 2 (audit R2, R3): `check.md` and
  `brainstorm.md` split by branch. `check-durable.md` holds the preflight,
  owned plan state, and gate steps 4 and 8–11; `check-review.md` holds the
  two review axes; "What the Guards Cannot Check" moves to
  `check-validation.md`. `brainstorm-grill.md` holds the Grill loop and
  `brainstorm-lock.md` the Plan Skeleton and lock steps 4–10. `zharness
  update` delivers the four new files as managed playbooks; every pinned
  contract phrase moved byte for byte. Known gap: `zharness update`
  records no installer ownership for the four new files, so a later
  `zharness uninstall` keeps them as provenance-unknown; delete them by
  hand if needed.

- Workflow token slim, phase 3 (audit R8): `hunt` loads by mode. Steps 5–7
  move to `references/fix.md` (read by `fix`, and by `sweep` for step 6);
  Bisect and Regression move to `references/bisect-regression.md`;
  `triage` follows `references/triage.md` instead of steps 2–7.
  `diagnose` now reads only steps 1–4.

## [v0.24.0] — 2026-09-22

### Changed

- The CLI is rewritten from Go to Rust. The crate lives in `cli/`; the Go
  sources, `go.mod`, `go.sum`, and `.goreleaser.yaml` are gone. The three
  verbs, their flags, their exit codes, the bytes they write, and the
  `.zharness/base/manifest.json` schema are unchanged — a manifest written by
  Go v0.23.1 is read, updated, and uninstalled without a forced reinstall.
  **Migration:** install the new binary the same way; nothing in a consumer
  repository changes. Building from source is now `cd cli && cargo build
  --release` instead of `go build ./cmd/zharness`.
- Help, usage, and error text now comes from clap, not cobra: `Available
  Commands:` and `Flags:` render as `Commands:` and `Options:`, and clap adds
  its own `-h, --help  Print help` line. Exit codes are unchanged — 0 for
  help and for a bare invocation, 1 for a usage error, not clap's default 2.
  **Migration:** anything parsing help text must be updated; anything
  checking exit codes needs no change.
- Releases publish under the `cli/vX.Y.Z` tag itself, named `zharness X.Y.Z`,
  instead of goreleaser's bare `vX.Y.Z` tag. The archives keep their
  `zharness_{os}_{arch}.tar.gz` names and `checksums.txt` is still written.
  **Migration:** `scripts/install-zharness.sh` already resolves the latest
  release by name, so it needs no change; a script that downloads by bare tag
  must switch to the `cli/v...` tag.
- darwin/amd64 is no longer built. Apple discontinued x86_64 macOS and GitHub
  is retiring its Intel runners, so the matrix ships darwin/arm64 and both
  linux architectures. **Migration:** Intel Mac users run the arm64 binary
  under Rosetta 2, or build from source with
  `cd cli && cargo build --release --target x86_64-apple-darwin`.
- The size target is enforced in CI: the `size-gate` job fails if the
  linux/amd64 stripped binary exceeds 1,850,000 bytes. The local release
  build is 732,648 bytes (823,888 for musl), against the Go v0.23.1 baseline
  of 3,715,506.

### Removed

- `cli/cmd/`, `cli/internal/`, `cli/go.mod`, `cli/go.sum`, and
  `cli/.goreleaser.yaml`. **Migration:** none for consumers; contributors
  build with cargo.

## [v0.23.1] — 2026-09-21

### Changed

- Every live instruction that routed agents to write scratch or reports into
  `.kit/` now points at the correct home: per-machine cache to
  `.zharness/cache/` (already gitignored for every consumer), durable plans
  to `docs/plans/active/`, and durable evidence to `docs/audit/`,
  `docs/research/`, or `docs/templates/`. `TestNoLegacyKitPaths` guards
  against the path reappearing in `skills/`, `rules/`, `scripts/`, or docs.
  No CLI runtime behavior changed; historical records describing `.kit/` as
  it was are left untouched.

## [v0.23.0] — 2026-09-19

### Added

- `zharness update --check [--all]` reports drift from the running binary
  without writing and exits 1 on drift; `--all` checks every repository in
  `~/.config/zharness/repos`, which `install`/`update` register and `uninstall`
  removes. `scripts/install-zharness.sh` runs it after an upgrade, and
  `scripts/install-git-hooks.sh` replaces a stale zharness-owned pre-commit hook.
- `update` migrates a single 9-section active plan to the 5-section format in
  place, `## Validation` bytes unchanged (ADR 0012). Any other heading set, or
  more than one active plan, is left alone with a `notice`.
- Plans carry spec and evaluation criteria as fields: Goal `success_signal:`,
  `actors:` and a per-requirement `acceptance:`; tasks `output:`/`check:`/
  `stop_if:`, high-risk phases `escalate_when:`; `to-plan` traces every
  requirement to a check; `check` records `requirements:` coverage and
  `rollback_point:` in Validation.

### Changed

- `update` no longer merges. `docs/PROJECT.md` is written only when absent. The
  `AGENTS.md` block is replaced between its markers; if it was edited since the
  last write, `update` prints the diff, writes nothing, and exits 1 unless
  `--force` (ADR 0011).
- The plan is five sections — Goal, Phases and Verification, Log, Validation,
  Current State and Next Action — scaled by lane (`tiny` needs no plan). Phase
  `status:` is a bare line under `phase_slug:`. Closing `handoff` compacts Log
  and Validation and writes `lifecycle_status: completed`.
- `check` has three modes: `gate`, `full`, `bounded`.
- Stages name model tiers (deep/standard/fast) instead of model names.

### Removed

- Three-way merge, `update --continue`/`--abort`, the update stash,
  `.zharness/conflicts.json`, and `.zharness/base/upstream/` (deleted on the
  next `update`).
- `intake_id`/`story_id` and the unused check/handoff/spec/plan templates.

**Upgrade:** run `zharness update` in each consumer repository, or
`zharness update --check --all` to list the ones that drift. Anyone scripting
`update --continue`/`--abort` must drop it.

## [v0.22.1] — 2026-09-19

### Changed

- Repository guidance is consolidated into a single `AGENTS.md`; the root
  `CLAUDE.md` is deleted. `scripts/verify-doc-links.sh` now scans `AGENTS.md`
  instead of `CLAUDE.md`. No `zharness` behavior change. Consumers that want
  Claude Code to load `AGENTS.md` keep a thin `CLAUDE.md` containing `@AGENTS.md`.

## [v0.22.0] — 2026-09-17

### Changed

- `WORKFLOW.md`: cite `docs/playbooks/*.md` and `docs/WORKFLOW.md` by section
  and step number, never by line (`:NN`) — `zharness update` fresh-overwrites
  these files, so line anchors drift silently and the doc-link guard never
  validates the `:NN` suffix. Run `zharness update` in consumer repositories
  to pick up the convention.

## [v0.21.0] — 2026-09-15

### Changed

- Playbooks: `zharness install`/`update` now write 8 playbooks. Full-mode `work`
  execution moves to `playbooks/work-full.md`, and the Validation entry format
  moves to `playbooks/check-validation.md`. Each is loaded only by the mode that
  needs it, so bounded `work` reads 3142 bytes instead of 9813 and bounded or
  review `check` reads 9718 instead of 15597. Run `zharness update` in consumer
  repositories to pick up the split.
- The 6 spine playbooks, `WORKFLOW.md`, and their `SKILL.md` triggers are
  trimmed per `git show 3bab3c0:docs/audit/playbook-token-audit.md` with no change in behavior.

### Fixed

- `work`: the in-session gate sets a clean non-final phase `checked`. The final
  phase stays `in-progress` for an independent `check full`, which rejects a
  `checked` phase.
- `watzup`: section reads fall back to `awk` when `scripts/plan-slice.sh` is absent.
- `brainstorm`: step 7 checks for any non-empty active plan before locking.

## [v0.20.1] — 2026-09-15

### Fixed

- `work`: auto mode selects durable execution only when the request names or
  continues an initiative. Direct bounded work no longer requires an active plan.
- `check`: default to auto mode. Direct changes select bounded; initiative checks
  validate the total active-plan count, selected phase, and Current State before
  selecting gate. Invalid initiative state stops instead of falling back to bounded.
- `check`: announce the resolved mode after read-only preflight and before checks
  or writes; re-read required state after compaction. Full review remains explicit.

### Changed

- Update the work skill to 1.4.1 and check skill to 1.7.0. Skills are installed
  separately from the CLI; run `zharness update` in consumer repositories to refresh
  their managed playbooks after upgrading the binary.
- Record the context-cost audit and ten routing smoke scenarios, including the
  corrected multiple-plan ambiguity. Runtime compaction and cost savings remain
  unproven experiments.

## [v0.20.0] — 2026-09-08

Remediates the 2026-09-07 third-party integrity review
(`git show 3bab3c0:docs/audit/2026-09-07-integrity-review.md`). Its eight findings collapse into
three root causes, each fixed as a mechanism rather than as a patch: ownership
inferred from filesystem state, stash restore written as a loop rather than a
transaction, and revision selection made ad hoc at each guard call site. See
ADR 0008 and ADR 0009.

### Added

- `feat(installer)`: `.zharness/base/ownership.tsv` — a durable ledger fixing each
  managed path's origin (`created_by_installer` / `preexisting`) on first decision
  and never revising it. All provenance is decided and persisted before the first
  managed byte is written, so an interrupted install cannot leave unattributed
  files behind. An installation predating the ledger is seeded from the manifest
  and `.orig` evidence the previous code already relied on.
- `feat(guards)`: `zharness_guard_revspec` — one revision selector for all three
  events (`staged` / `push` / `pr`), replacing three ad-hoc call sites. It fails
  closed when no base revision resolves rather than silently guarding an empty
  range. Companions `zharness_guard_plan_paths` and `zharness_guard_old_blob`.
- `docs`: `check.md` gains **What the Guards Cannot Check** — `judge: independent`
  is testimony rather than attestation, an unrecognized entry format is ignored
  rather than rejected, and a range guard only compares endpoints.

### Fixed

- `fix(installer)` (F01): creating `AGENTS.md` no longer confers ownership of prose
  written into it later; uninstall strips the managed block and keeps the rest.
- `fix(installer)` (F06): a reinstall no longer captures the first install's
  generated bytes as that file's pre-install original.
- `fix(installer)` (F07): uninstall removes only the `.gitignore` lines it added and
  leaves an identical rule the consumer already had.
- `fix(installer)` (F04): `stash.tsv` gains an existence column. v1 collided "absent"
  with "present but empty" into a zero-byte blob and restore read zero bytes as a
  deletion request, so aborting an update deleted a file that had merely been empty.
  A v1 stash is now reported as ambiguous instead of resolved by a guess.
- `fix(installer)` (F05): stash restore validates the whole inventory and reads every
  payload before touching the working tree, and names exactly what failed instead of
  half-applying. The stash directory survives any failure.
- `fix(guards)` (F02/F03/F08): a push of more than one commit was guarded only at
  `HEAD~1`; everything earlier in the range went unchecked. CI now checks out full
  history (`fetch-depth: 0`) and passes the event SHAs in explicitly.

### Changed

- `refactor(installer)`: uninstall reports what it removed and what it kept, with a
  reason per kept path, replacing the unconditional claim that "consumer-owned files
  were never touched". Unknown provenance is kept, never resolved by deleting.
- `ci`: the two `HEAD~1 HEAD` guard steps collapse into one range-guarded step, and
  the guard-core extraction check asserts the new selector functions are present.

## [v0.19.0] — 2026-09-08

### Added

- `feat(guards)`: New pre-commit/CI guard `zharness_guard_completed_plan_phases_done`
  rejects a plan staged or pushed under `docs/plans/completed/` whose `Current
  State` declares `lifecycle_status: completed` while any phase in `## Phases
  and Verification` is not `status: done`.

## [v0.18.0] — 2026-09-07

### Added

- `feat(installer)`: Identity template now defines explicit slots for `run from:`,
  `tests:`, `types:`, `lint:`, `build:`, and `format:` (accepting `n/a`). Deliberately
  conflicts on `zharness update` for repositories using the legacy template to prompt
  owner re-configuration.
- `test(cli)`: Automated embedded-to-projected parity test `TestProjectionParity`
  under `cli/docs/embedded/parity_test.go` running in CI to enforce the byte-identical
  playbook invariant.
- `skills`: Payload-local `references/` directories added to `encode-invariant` and
  `improve-harness` to eliminate external doc-tree dependencies in consumer checkouts.

### Changed

- `docs/PROJECT.md`: Format gate changed from bare `gofmt -l cli` to `test -z "$(gofmt -l cli)"`
  so unformatted Go files reliably fail the gate.
- `git` skill: Dynamic base branch resolution for `/git pr` and `/git merge` verifying
  remote tracking branches (`refs/remotes/origin/`) before local heads; stack-neutral
  staging and lockfile grouping for Go (`go.mod`/`go.sum`), Rust (`Cargo.toml`/`Cargo.lock`),
  and Python (`pyproject.toml`/`uv.lock`/`poetry.lock`); co-located tests commit with the source they cover.
- `playbooks`: Proof re-execution contract in `check.md` explicitly documents inherited
  exported environment variables; `watzup.md` resolves base branch dynamically;
  `brainstorm.md` adds a `zharness install` absence branch for consumer checkouts.

### Fixed

- `git` skill: PR creation no longer collapses `$BASE` to current branch `$HEAD` in
  single-branch, shallow, or worktree checkouts lacking a local default branch checkout.

## [v0.17.0] — 2026-09-03

### Fixed

- `zharness update`: a playbook or `docs/WORKFLOW.md` with no recorded
  merge base — `.zharness/base/` lost, or predating base tracking — used to
  stay stuck on stale content forever (R18 refused to invent an ancestor).
  These files are pure upstream mirrors, never a legitimate consumer
  customization surface, so `install`/`update` now fresh-overwrite them
  unconditionally: no diff, no compare, no conflict. Three-way merge stays
  for `docs/PROJECT.md` and the marked `AGENTS.md` block, the two managed
  files consumers do own. See `docs/decisions/0007-fresh-overwrite-for-playbooks-and-workflow.md`.

### Changed

- Hand-edits to a playbook or `WORKFLOW.md` are now silently discarded on
  the next `zharness update`, with no conflict marker warning first — the
  accepted cost of the fix above.

## [v0.16.3] — 2026-09-02

### Changed

- `check.md` gate: if `scripts/record-check.sh` exists, run proofs through
  it (timeout → gtimeout → unbounded; 3-line pass / 10-line fail tail).
  If it is absent, capture to a temp file, print the same tails, and keep
  the command's exit code. Nested Validation bullets still cite the raw
  commands so the hook re-executes them.

### Fixed

- `scripts/record-check.sh`: same timeout resolver as the pre-commit hook,
  so stock macOS no longer fails with `timeout: command not found`.

### Added

- `git show 3bab3c0:docs/audit/wave-session-ab-protocol.md`: paired worktree A/B for
  same-session vs wave-boundary restart. Does not change `work.md` step 11.

## [v0.16.2] — 2026-08-30

### Changed

- Handoff close: after absorb and `git mv`, a completed plan is a run log
  (cite the ADR or guard, never the completed path). It may later be deleted
  when no recovery audience remains; if unsure, keep. Deletion is not part
  of close.

## [v0.16.1] — 2026-08-30

### Added

- `escalate_when` on `work.md` and `WORKFLOW.md`: ask the owner and stop
  when locked schema or requirements would change, the same verification
  command failed twice, or a product rule conflicts. Retry cap stays one
  targeted fix. Not a plan field. Not a hook.

## [v0.16.0] — 2026-08-30

### Added

- Handoff absorb gate: an initiative cannot `git mv` to `completed/` without
  an `absorb:` line in `## Decisions` (`absorb: none` is valid). A
  class-of-failure or expensive-to-reverse decision must already live in an
  ADR or a native guard.
- Pre-commit R5: at most one non-empty file under `docs/plans/active/`; zero
  is a valid idle state.
- Pre-commit H3: a newly added `mode: full` Validation entry that also
  declares `judge: same-session` is rejected. Full checks require an
  independent judge.
- Source-repo skills `encode-invariant` and `improve-harness` (not part of
  `zharness install`).
- `LICENSE` (MIT), `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  and `.github/dependabot.yml`.

### Changed

- Consumer `README.md` and `AGENTS.md` rewritten around the three-verb
  installer. Workflow diagrams no longer mention `zharness init` or a local
  database.
- Live contract and architecture describe the v0.16 protocol. The binary
  surface is unchanged from v0.15: `install` / `update` / `uninstall`.

### Fixed

- Guard entry hashes no longer depend on trailing blank lines, which had
  re-executed the previous Validation entry on every append.
- Skill validation actually runs on `skills/<category>/<name>/SKILL.md`.
  Load-time errors stay fail-closed; format checks are warnings.

## [v0.15.1] — 2026-08-28

### Fixed

- Pre-commit guard: the verdict token is read from a Validation entry's first
  line and now matches the repository's `verdict \`APPROVED\`` grammar —
  previously every real APPROVED entry was silently skipped by the guard.
- Pre-commit guard: Validation entries without a leading timestamp are now
  visible to both fail-closed guards.
- Installer: `.zharness/base/original/` naming is collision-free (with a
  legacy fallback so v0.15.0-captured originals still restore), and diff3
  falls back to a conservative whole-side hunk above an 8M-cell LCS cap.
- Non-spine `git`/`interview` skills no longer reference binary commands
  deleted in v0.15.
- Pre-commit guard: proof re-execution no longer depends on GNU `timeout`
  being installed. The wrapper is resolved at call time (`timeout`, else
  `gtimeout`, else the command runs unbounded with a warning), so a proof's
  verdict follows its own exit code. On stock macOS every proof previously
  exited 127 (`timeout: command not found`) and the guard rejected each
  honest APPROVED entry.
- Guard fixture suite: the entry-count assertion compares numerically, so
  BSD `wc -l` padding can no longer produce a false FAIL on macOS.
- Pre-commit guard: the old-side entry set no longer uses a bash 4
  associative array. The hook's shebang is `#!/bin/bash`, which on macOS is
  bash 3.2: `local -A` failed there, the hex hash was then evaluated as an
  arithmetic array subscript, and the shell died with "value too great for
  base" on the first old-side entry — so every commit touching a plan that
  already had a Validation entry was rejected with an opaque error. Membership
  is now a hash file plus `grep -Fxq`, identical on every bash.
- Guard fixture suite: the decisive accept and reject cases are re-run under a
  legacy bash 3.x when one is present, so the guard core cannot regress into a
  bash-4-only construct.

## [v0.15.0] — 2026-08-28 (breaking)

### Changed

- **BREAKING**: the entire `zharness` lifecycle command surface (init,
  migrate, import, db rebuild/status, query views, intake, story, trace add,
  decision add, memory, run create, plan complete/abandon, resume, preflight,
  check record, handoff record, validate, audit) and SQLite are deleted from
  source. The binary is being reduced to install / update / uninstall.
- State lives in git-committed markdown alone (`docs/plans/**`). Lifecycle
  bookkeeping is hand-appended markdown gated by the repository's pre-commit
  hook, which now owns both fail-closed guarantees: proof re-execution for
  APPROVED Validation entries and the independent-judge rule for high-risk
  lanes (`scripts/install-git-hooks.sh`; CI re-runs the same guards).

### Removed

- The SQLite database (`harness.db`) is no longer created, read, or written
  by the binary.

### Upgrade guidance

- **Pin `v0.14.x`** if you still need the old lifecycle binary — that line
  keeps a fully working product with its own `harness.db`.
- Your existing `harness.db` (and its `-wal`/`-shm` sidecars) is
  **consumer-owned bytes**: nothing in this or future releases deletes it.
- New consumers need no initialization at all: markdown plus git is the whole
  system of record.
