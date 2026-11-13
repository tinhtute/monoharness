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
- Q2: Can `claude plugin eval` run this repo's evals: does it load `agents/*.md` (shipped by `scripts/install-agents.sh`) or only skills; can it compare a candidate SHA against master at the same n instead of its with/without-plugin ablation; can code graders read a scaffolded git repo's diff and the agent's report token; can the judge be fable or opus instead of the haiku default; does it report pass^k? If not, which runner pieces must be built? | type: research | by: AFK | blocked_by: none | status: decided → yes as the runner: it loads the plugin's `agents/*.md` (as `<plugin>:scout`, on its frontmatter model when `--model` is unset) and skills, `--judge-model` sets the LLM grader, and per-run results come back in `--json`; build two pieces around it: a grader over the `--keep-temp` workspace for git diff and SCOPE (no code or shell grader type exists, and `tool_used` matches a call even when it errors), and two plugin dirs for candidate against master (its ablation is with against without plugin) | evidence: probe 2026-11-13, claude 2.1.323, 2 cases, about $0.23
- Q3: How does one trial load exactly the candidate SHA's agents and skills and nothing from `~/.claude` (global CLAUDE.md, rules, installed agents, memory, settings)? | type: research | by: AFK | blocked_by: none | status: decided → `claude plugin eval` gives each run a fresh `CLAUDE_CONFIG_DIR` and `HOME` with only the plugin under test loaded; the no-plugin arm got `Agent type 'scout' not found` despite `scout` in `~/.claude/agents`, and no reply carried the global CLAUDE.md marker | evidence: probe 2026-11-13, claude 2.1.323
- Q4: What does the deleted `evals/rsi/` (`git show aa7100d^:evals/rsi/`, issues #192–#196, #203) show: cost and wall time per trial, which pieces are reusable (`fixture.sh`, the evaluator-only oracle, `split.py`, `cost.py`, `accept.py`), and what made it unused? | type: research | by: AFK | blocked_by: none | status: decided → about $0.17–0.19 per sonnet trial (#194), wall time not recorded, 1200 s timeout; the real limit was subscription quota (the 5-hour cap voided 15+15 trials, #192, #193); it graded coding-task output on a toy repo with tokens in the score, flaky tasks (D03) never separated candidates, n=3 to 5 made IQR gates fail on noise (±15% median tolerance proposed, #192), env leaks took about 6 PRs to seal; reuse the fixture builder, the evaluator-only oracle and the "fresh fixture fails, reference passes" self-test; drop `accept.py` and `cost.py`; it lived 5 days, changed no shipped prompt, and nothing triggered it | evidence: `docs/research/2026-11-13-behavioral-eval-seed-audit.md` Part 1; `git show aa7100d^:evals/rsi/`, #192, #193, #194, #233
- Q5: Which behaviors does the first suite cover: agent role contracts (report token, SCOPE, no test hacking), skill procedures (`poteto` routing, `check` gates, `check-risk` verdict), or both; and is #274's worker-deviation eval its first case set or settled separately first? | type: grill | by: HITL | blocked_by: none | status: decided → both, agents as the core: agent role contracts (report token, SCOPE, no test hacking) plus a thin `poteto` routing slice that runs on the built-in graders while the workspace grader is built; no `check` gates or HITL skills in the first suite; #274 is the first case set (F3, F3b, F4, premise-else, behaviour-widening, committed as cases) and closes when the suite runs candidate against master at n≥3 | evidence: user 2026-11-13
- Q6: Which real failures seed the cases: the #272/#273 fixtures (F3, F3b, F4, premise-else), `retro` findings, #288 drift-guards Q8 and Q9, pre-commit guard rejections, `session-digest.py` output? | type: research | by: AFK | blocked_by: Q5 | status: decided → 13 candidates, 6 on explicit incidents: worker widens a decision beyond the GOAL (`completed/orchestrate-autopilot.md` Log 04:42Z, matches #274 behaviour-widening), deviation over a missing citation (same plan, 04:27Z), verifier able to mutate the judged branch (#215), self-acceptance and unrequested scope (#288 Q8/Q9, self-reported), planted hollow proof (#211) and planted test weakening (#212), both auditor-run; 7 inferred from rules (missing VERIFY line, brief reads two ways, verifier trusts pasted output, stale artifact, scout cites lines, architect sealed report); no `poteto` misroute is documented, so the routing slice is rule-derived | evidence: `docs/research/2026-11-13-behavioral-eval-seed-audit.md` Part 2; `.monows/plans/completed/orchestrate-autopilot.md:77,81`, #211, #212, #215, #288
- Q7: Are graders code only (git diff, report token, files touched against SCOPE), or are LLM graders allowed, and if so on which model and calibrated against what? | type: grill | by: HITL | blocked_by: Q2 | status: open
- Q8: Which statistic and threshold decide that a prompt change lands: pass^k at which k, candidate against master at the same n, and are regression cases held to a different bar than capability cases? | type: grill | by: HITL | blocked_by: Q1, Q2 | status: open
- Q9: Train/val/test with a test split read once (like RSI and `evals/risk-judge/`), or a regression-only suite; who tunes prompts against which split? | type: grill | by: HITL | blocked_by: Q5 | status: open
- Q10: What references and runs the suite so it cannot rot unreferenced like RSI: a `check` step for PRs touching `agents/**` or `skills/**`, a CI job, a nightly workflow, a `risk-facts.sh` fact? | type: grill | by: HITL | blocked_by: Q1, Q8 | status: open
- Q11: If Q10 puts paid runs in CI, the owner adds the API key secret and reviews the `.github/**` change. | type: task | by: HITL | blocked_by: Q10 | status: open
- Q12: Real incidents seed about 6 cases against the 20–50 the destination implies; may the rest be planted or rule-derived cases (marked as such), and do they count toward the pass rule the same as incident cases? | type: grill | by: HITL | blocked_by: none | status: open
- Q13: Does each case record a sync commit (the SHA at which it last matched the prompt it tests), and does a change to that prompt run drift triage before the suite (no effect, case stale, promise changed on purpose with cited evidence, promise may be broken), updating the case from the prompt rather than from the result, as pstack's `maintain-formal-verification-skill` steps 1 and 3–5 do? | type: grill | by: HITL | blocked_by: none | status: open | evidence: https://github.com/cursor/plugins/blob/24621dbcc59e205a7faadb0e06d540f91712b5cc/pstack/skills/maintain-formal-verification-skill/SKILL.md; owner decision 4, 2026-11-13
- fog: headless evaluation of HITL skills (`grill`, `brainstorm`, `wayfinder`) that stop on the question tool
- fog: how "eval before the prompt change" is enforced mechanically rather than written as prose
- fog: non-Claude hosts (Codex, omp); RSI had an omp runtime and the README claims portability

## Phases and Verification
- approach: not-planned

## Log
- 2026-11-13 decision: `claude plugin eval` is the runner (runner and isolation questions); `--keep-temp` leaves its run dirs read-only, so cleanup runs `chmod -R u+rwx` before `trash`

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: 11 map lines
- exact_next_action: wayfinder
