---
status: active
lane: high-risk
---
# Behavioral evals for agents and skills

## Goal
- outcome: changes to `agents/*.md` and `skills/**` are developed eval-first: a suite of behavioral cases drawn from real failures runs on the candidate and on master, and its result decides whether a prompt change lands
- success_signal: (draft, numbers from the grill) one command runs the suite on a candidate SHA and on master at the same n and prints per-case pass^k; a prompt change with a planted regression fails it; the workflow step that gates prompt changes references and runs it
- actors: the owner; the Lead session that edits prompts; the harness agents (`scout`, `worker`, `engineer`, `verifier`, `architect`); CI if the cadence puts runs there
- authority: owner decision user 2026-11-13 (destination: full eval-driven dev); gap 1 of the scratchpad note `learn/agent-verification/harness-verification-gap-analysis.md`; s1 https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- requirements: none until the map is decided
- non-goals:
  - NG1: token or cost as the score; cost is a budget only (user 2026-11-13: the deleted `evals/rsi/` measured the wrong thing)
  - NG2: the `zharness` Rust CLI's behavior; `cargo test` owns it
  - NG3: risk-judge calibration; #221 and `evals/risk-judge/` own it

## Map
- Q1: What per-trial and per-suite cost and wall-time ceiling, and which cadence (every prompt PR, nightly, on demand), must the suite fit, given RSI died of cost, wrong measure, finished issues and neglect (user 2026-11-13)? | type: grill | by: HITL | blocked_by: Q4 | status: open
- Q2: Can `claude plugin eval` run this repo's evals: does it load `agents/*.md` (shipped by `scripts/install-agents.sh`) or only skills; can it compare a candidate SHA against master at the same n instead of its with/without-plugin ablation; can code graders read a scaffolded git repo's diff and the agent's report token; can the judge be fable or opus instead of the haiku default; does it report pass^k? If not, which runner pieces must be built? | type: research | by: AFK | blocked_by: none | status: open
- Q3: How does one trial load exactly the candidate SHA's agents and skills and nothing from `~/.claude` (global CLAUDE.md, rules, installed agents, memory, settings)? | type: research | by: AFK | blocked_by: none | status: open
- Q4: What does the deleted `evals/rsi/` (`git show aa7100d^:evals/rsi/`, issues #192–#196, #203) show: cost and wall time per trial, which pieces are reusable (`fixture.sh`, the evaluator-only oracle, `split.py`, `cost.py`, `accept.py`), and what made it unused? | type: research | by: AFK | blocked_by: none | status: open
- Q5: Which behaviors does the first suite cover: agent role contracts (report token, SCOPE, no test hacking), skill procedures (`poteto` routing, `check` gates, `check-risk` verdict), or both; and is #274's worker-deviation eval its first case set or settled separately first? | type: grill | by: HITL | blocked_by: none | status: open
- Q6: Which real failures seed the cases: the #272/#273 fixtures (F3, F3b, F4, premise-else), `retro` findings, #288 drift-guards Q8 and Q9, pre-commit guard rejections, `session-digest.py` output? | type: research | by: AFK | blocked_by: Q5 | status: open
- Q7: Are graders code only (git diff, report token, files touched against SCOPE), or are LLM graders allowed, and if so on which model and calibrated against what? | type: grill | by: HITL | blocked_by: Q2 | status: open
- Q8: Which statistic and threshold decide that a prompt change lands: pass^k at which k, candidate against master at the same n, and are regression cases held to a different bar than capability cases? | type: grill | by: HITL | blocked_by: Q1, Q2 | status: open
- Q9: Train/val/test with a test split read once (like RSI and `evals/risk-judge/`), or a regression-only suite; who tunes prompts against which split? | type: grill | by: HITL | blocked_by: Q5 | status: open
- Q10: What references and runs the suite so it cannot rot unreferenced like RSI: a `check` step for PRs touching `agents/**` or `skills/**`, a CI job, a nightly workflow, a `risk-facts.sh` fact? | type: grill | by: HITL | blocked_by: Q1, Q8 | status: open
- Q11: If Q10 puts paid runs in CI, the owner adds the API key secret and reviews the `.github/**` change. | type: task | by: HITL | blocked_by: Q10 | status: open
- fog: headless evaluation of HITL skills (`grill`, `brainstorm`, `wayfinder`) that stop on the question tool
- fog: how "eval before the prompt change" is enforced mechanically rather than written as prose
- fog: non-Claude hosts (Codex, omp); RSI had an omp runtime and the README claims portability

## Phases and Verification
- approach: not-planned

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: 14 map lines
- exact_next_action: wayfinder
