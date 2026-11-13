# 0021 — A consumer-repo verification generator is in scope; ADR 0017 does not cover it

## Status

Accepted 2026-11-13 by the owner, before implementation (see the README exception). Implementation pending in #292.

## Context

ADR 0017 rejected two skills for this repository: one that lists project constraints and one that wraps the existing gate scripts (`docs/decisions/0017-no-project-verification-skill.md`, Decision). Its reason holds for this repository's gates: a skill is prompt text and cannot enforce what a script and a CI job do.

It did not judge a third thing. pstack's `create-verification-skill` is a generator: it interviews a repository and writes a project-local skill that drives the real app, with Launch, Doctor, Drive, Evidence and Cleanup sections and a feature map ([cursor/plugins@24621db `create-verification-skill/SKILL.md`](https://github.com/cursor/plugins/blob/24621dbcc59e205a7faadb0e06d540f91712b5cc/pstack/skills/create-verification-skill/SKILL.md)). Its partner `maintain-verification-skill` keeps that skill in line with the code.

The gap it fills is in `skills/stages/check/references/check-exercise.md:9`: a consumer repository with no run skill and no run commands in `AGENTS.md` ends at `not exercised: no way to run it`. This repository has its own recipe, which `cli/tests/exercise_recipe.rs` runs in CI, so the gap shows only in consumer repositories.

## Decision

1. A generator that writes a verification skill into a consumer repository is in scope. ADR 0017 stays in force for this repository's own gates.
2. Harden the recipe first. `check-exercise.md` now requires usable readiness, a read-only doctor, a dry-run trusted only for what was observed skipped, and cleanup that keeps the evidence (`skills/stages/check/references/check-exercise.md:14-18`).
3. The generated skill is named `verification-<app>`, always with the suffix: a noun, one skill per app. Upstream writes `verify-<app>` (`create-verification-skill/SKILL.md:25` at the pinned commit).

Rejected: copying `verify-<app>` exactly. It would let pstack's `setup-pstack` step 7 find our skill by name, but the owner chose a noun for the skill name.

Rejected: a bare `verification` for single-app repositories. A multi-app repository would then need a second naming rule.

## Consequences

- A consumer without a run recipe can get one instead of a permanent `not exercised`.
- The generated skill becomes a second place that describes how to run the app, beside `AGENTS.md`. The maintain loop exists to keep it honest, and it is part of the same work.
- Next to an installed pstack, `setup-pstack` looks for a `verify-*` skill and may not find ours. `maintain-verification-skill` finds its target by body, so it should.
- Open, tracked in #292: whether to port the formal pair and what to name it; where the skill installs on each host; and whether the noun really avoids a clash with a host's built-in `/verify` (unverified).

## Authority

- The owner's calls, 2026-11-13: harden first, then an issue plus this ADR; the noun name; the `-<app>` suffix.
- `docs/decisions/0017-no-project-verification-skill.md`.
- `skills/stages/check/references/check-exercise.md:9`, `:14-18`.
- `cli/tests/exercise_recipe.rs`.
- [cursor/plugins@24621db `pstack/skills`](https://github.com/cursor/plugins/tree/24621dbcc59e205a7faadb0e06d540f91712b5cc/pstack/skills): `create-verification-skill`, `maintain-verification-skill`, `setup-pstack`.
- Issue #292.
