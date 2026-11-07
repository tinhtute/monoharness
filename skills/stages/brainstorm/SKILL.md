---
name: brainstorm
version: "5.2.0"
description: "Explore trade-offs, grill fuzzy intent or a plan, chart a multi-session decision map, and lock the Goal into `.harness/plans/active/{slug}.md`. Use for ideation, architecture decisions, grill/interview requests, and RFC/PRD-to-spec work."
license: MIT
argument-hint: "[explore|grill|raw|chart|lock|refine] [idea, @file refs, plan path, or trade-off question]"
compatibility: Designed for Claude Code
---

Lead with the recommendation, then the key trade-off.

Resolve the mode, then follow [references/brainstorm.md](references/brainstorm.md) (`.harness/WORKFLOW.md` IF routing is unclear).

Resolve cross-stage transitions through the host's skill metadata; do not assume a shared installation parent. Resolve data paths from the consumer repository root. If a required skill or reference is unavailable, report the missing dependency and stop; retained legacy playbooks are not a fallback.

Defer to: `to-plan` after an approved high-risk lock, `work` after a normal one; `check` for quality gates after implementation.
