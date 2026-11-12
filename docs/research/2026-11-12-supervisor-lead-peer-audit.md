# Supervisor–Lead–Peer audit (draft, for brainstorm)

Design note, 2026-11-12. Source: a Vietnamese deep dive on Demonthorn's agent orchestration model ("Agent Orchestration theo Demonthorn — Deep Dive v1", 2026-08-02, a local file outside this repository). Line numbers in `doc:N` refer to that file. Its profiles and templates are labelled **[SYNTHESIS]**, not Demonthorn's own words (`doc:70-73`), and its early `human > supervisor > root > peer` line was later withdrawn by the author (`doc:83-91`).

Status: input for a brainstorm, not a decision. Nothing here changes behavior.

**Verdict:** after #272 and #273, the Lead–Peer half of the harness matches the model closely. Two real gaps remain:

1. **No Supervisor.** The owner currently plays it.
2. **The Lead implements and accepts its own work** (the doc's §8.7 self-acceptance).

A standing Supervisor session still looks like ceremony (§8.11) for one owner and one repo.

## Role mapping

| Demonthorn | Harness today | Match |
|---|---|---|
| Human / owner | the owner: override labels, merge, `grill` (AGENTS.md § Unattended Shipping) | yes |
| Lead (binding arbiter) | the main agent as coordinator (`skills/poteto/playbooks/orchestrate.md:3`, ADR 0020 decision 4) | partial, see below |
| Peer: one profile plus a disposition per task (`doc:546-555`) | four pinned profiles: `scout`, `worker`, `engineer`, `verifier` | different shape, with a reason |
| Supervisor (`doc:319-428`) | none | no |
| Paseo (control plane) | Claude Code's Agent tool, the plan `## Log`, git and `gh` (`orchestrate.md` State rule) | yes |
| Three layers: profile / Workspace Protocol / task prompt (`doc:251-288`) | `agents/*.md` / `work-fanout.md` plus AGENTS.md § Unattended Shipping plus the plan's Standing Orders / the brief template (`skills/stages/work/references/work-fanout.md:40-50`) | yes |

Closed since #272 and #273:

- Peers own the outcome and the DESIGN is a hypothesis (`doc` §7.1, §8.2).
- `BLOCKED (spec | premise | scope)` covers the doc's REOPEN, DEPENDENCY and BLOCKED requests (`doc:454`).
- The same-symptom brake (`doc` §8.3).
- The `lead` agent is renamed `engineer` (`doc:527-538`).
- Free re-briefs are bounded.

## Peer: four profiles vs one thin profile

The doc recommends one Peer profile with the disposition in the task prompt, and says "role name does not decide the model tier; task risk does" (`doc:426-428`).

The harness splits them for a reason: Claude Code pins `model:` and `tools:` per agent file, and `tools: Read, Grep, Glob, Bash` is the only tool-enforced read-only boundary (`scout`, `verifier`). `worker` and `engineer` differ only in model and `maxTurns`, so in practice they are one Peer at two tiers.

**Gap: no Architect disposition.** The doc's Architect (`doc:612-622`, §8.12) is read-only and returns alternatives, the strongest counterargument and reversal conditions in a sealed report. Nothing here covers it:

- `engineer` can write.
- `verifier` judges a diff.
- `think` and `arena` run inside the main agent and inherit the Lead's framing.

## Lead: self-acceptance

The doc's Lead is read-only (`doc:495`). When the Lead both implements and accepts, "separation of judgment disappears" (`doc:462-463`).

The harness main agent implements bounded changes itself ("A bounded change needs no plan: implement and validate", AGENTS.md § Harness). The safety nets exist but are not on every path:

- Land requires an independent risk judge (`skills/poteto/playbooks/ship.md`).
- High-risk phases require a verifier (`work-fanout.md:87`).

Evidence: #273 was written by the main agent, and the same agent wrote its `## Risk` section with no judge run. The harm was small, because the always-review path `.github/workflows/cli-ci.yml` already forced needs-review, but it is the §8.7 pattern.

## Supervisor: why nothing qualifies

The doc's criteria for a Supervisor:

- it stands outside the execution flow;
- it runs as a fresh session, not a fork (§8.13);
- it observes the Lead;
- it owns no acceptance (`doc:349-355`).

How each candidate fares:

- **`orchestrate` step 6 and the `/loop 1h` audit:** the Lead supervising Peers, inside the flow.
- **`verifier` and the risk judge:** a Reviewer disposition on one candidate; they do not watch the workflow.
- **`retro`:** the closest fit. It reads session transcripts (`skills/stages/retro/references/retro.md:15-17`) and returns evidence-cited findings. But it is post-hoc and runs only when the owner invokes it.
- **The `fable` advisor:** it reads the Lead's whole transcript, so it inherits the Lead's framing (§8.13). It advises the Lead; it does not supervise it.
- **The owner:** plays Supervisor and talks to the Lead directly, which is the doc's §8.14 Root attention dilution. With one repo, that cost is acceptable.

**Open feasibility question.** The doc's Supervisor needs timeline and session access (`doc:357-363`). Claude Code seems to provide the pieces, but nothing has shown them working end to end:

- session transcripts live at `~/.claude/projects/<project>/*.jsonl`;
- `ListAgents` and `SendMessage` reach other local sessions.

Check: ask `claude-code-guide`, or run a separate session that reads the Lead's jsonl and relays one finding through `SendMessage`.

## Options for the brainstorm

1. **Lead never self-accepts (recommended first).** Every PR the main agent wrote gets an independent judge before Land, even when an always-review path already forces needs-review.
2. **Architect disposition.** A read-only agent, or a brief template that dispatches `verifier` in a "reconstruct the problem, alternatives, reversal conditions" mode. Use it only for hard-to-reverse decisions.
3. **Light Supervisor, no standing session.** Run `retro` on events (after a fanout wave or an `orchestrate` round), with output in the doc's shape: Observation, Evidence, Suspected mechanism, Impact, Question for Lead, Recommendation, Escalation (`doc:367-375`). `feedback` memories, which carry a **Why**, serve as the causal notebook. A real Supervisor session is worth it only for multi-repo or multi-day runs, the direction in [2026-10-12-lead-peer-contract.md](2026-10-12-lead-peer-contract.md).

**What would change this:**

- Frequent multi-repo or multi-day `orchestrate` runs would justify a Supervisor session.
- So would retros on real waves that show the Lead repeating anti-patterns the owner missed.
- If Claude Code cannot give a separate session the Lead's timeline, option 3 is the ceiling.
