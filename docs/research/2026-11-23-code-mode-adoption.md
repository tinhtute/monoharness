# Code Mode adoption

Research note for the Code Mode plan. Sources: the Claude Code Code Mode docs, the Claude Code issue tracker, Anthropic and Cloudflare engineering posts, the `claude plugin eval` docs, and probes run on claude 2.1.330. Date: 2026-11-23.

## 1. Executive summary

- **Code Mode is experimental and Claude Code only.** It runs in an interactive terminal, and Anthropic may change or remove it in any release. This plan adopts it as conditional guidance, not as a requirement.
- **Four steps and one script adopt it.** Four workflow steps get a one-line note for shell-side batching and filtering, and the `orchestrate` and `autopilot` ticks read PRs through one checked-in script. With Code Mode off, every procedure reads and runs unchanged.
- **Code takes the mechanical work; the model keeps the judgment.** Loops, fan-out, filtering and chains of three or more dependent calls move into a script. Anything the model must reason over stays a model turn.
- **A script may launch only `scout`, `test-runner` and `verifier`, and no note asks it to.** An `Agent` call from a script returns `async_launched`, so the script cannot collect the report. Writers keep their existing spawn path.
- **Evals cannot run Code Mode.** Each eval trial is a non-interactive child session, so evals cover only the Code Mode off arm. Code Mode behavior is proved in interactive sessions.
- **Pending:** the first full `orchestrate` or `autopilot` tick in Code Mode.

## 2. Code Mode facts a harness designs around

Sources: https://code.claude.com/docs/en/code-mode; https://github.com/anthropics/claude-code/issues/111259; probes on claude 2.1.330 on 2026-11-23.

- **Time limits.** A script stops after 10 minutes while Claude waits. Background code runs up to 2 hours, and only in `auto` or `bypassPermissions` mode.
- **Permissions.** Each call a script makes goes through deny and ask rules and through PreToolUse hooks under its usual tool name. MCP tools appear as `mcp__server__tool`.
- **Auto-mode review.** The auto-mode classifier reviews the code, not each call, and never sees run-time values.
- **Hook routing.**
  - A hook can match `REPL`. It sees `tool_input.code` and `tool_response`, and it can rewrite the output with `updatedToolOutput`.
  - Since 2.1.329, a call from code runs after a hook failure unless the hook sets `onFailure: "block"`.
  - A `git push` can reach a hook as `cd 'app' && git push`, so a matcher that expects the command at the start of the string can miss it.
  - A mod's `classic.PostToolUse` never fires for `REPL` (issue 111259).
- **Surfaces.** Interactive terminal only. VS Code panel, Desktop, cloud and background jobs do not run it.
- **Subagents.**
  - In the probe session, an `Agent` call from a script returned `async_launched`, and the report arrived as a task notification, not as a return value.
  - `scout` and `worker` subagents run in Code Mode with `REPL` and `Poll`.
  - The scout's `tools.list()` held only Read, Bash, Glob and Grep. Release 2.1.328 fixed read-only subagents being offered write and edit tools.

## 3. Practice: what moves into code and what stays judgment

Sources: https://www.anthropic.com/engineering/advanced-tool-use; https://www.anthropic.com/engineering/code-execution-with-mcp; https://blog.cloudflare.com/code-mode/; https://www.adlc.io/. The ADLC pages were read as search snippets only, so treat that source as weak. ADLC here means the SDLC run by agents: human judgment, agent execution, real evidence. That is what this harness already is.

Moves into code:
- Loops, fan-out and filtering.
- Chains of three or more dependent calls.
- Logic used more than once, which is promoted to a checked-in `scripts/` file that both modes run.

Stays model judgment:
- Anything the model must reason over. The script returns a compact result and the model reads it.

Rules for the scripts themselves:
- Return compact results.
- Isolate failure per call, for example with `.nothrow()`, so one failed call does not drop the others.
- Script output is the leak surface. Redact it with a `REPL` PostToolUse hook.
- Protect actions with rules and hooks, never with the auto-mode classifier.
- The sandbox covers shell commands only.

No source says how to brief a subagent from a script. This plan therefore adds no such note.

## 4. Why evals cannot cover Code Mode

Sources: https://code.claude.com/docs/en/plugin-evals.md (Isolation); https://code.claude.com/docs/en/code-mode (Requirements).

- `claude plugin eval` runs each trial as a `claude -p` child in a fresh non-interactive session.
- Code Mode needs an interactive terminal.
- The child environment allowlist does not name `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE`.

So evals can cover only the Code Mode off arm. The existing CI gates cover that reading. Code Mode behavior is proved by cited interactive sessions (section 8).

## 5. Launch rule for scripts

Source: owner decision 2026-11-23, with the `async_launched` fact from section 2.

- A script may launch only `scout`, `test-runner` and `verifier`, which are read-only.
- `worker` and `engineer` keep the existing spawn path, one brief at a time.
- `test-runner` comes from the monoclaudian machine setup, not from this repo's `agents/`. A consumer repo may lack it.
- A script cannot collect an agent report, because the call returns `async_launched`.
- Because of that last fact, no note in this plan tells a script to launch an agent.

## 6. Adopted and not adopted

Adopted:
- Four conditional notes, each opening "On Claude Code in Code Mode" and naming `REPL` and `Poll`. Each moves only shell-side batching and filtering into one script.
  - `recall`: transcript filter and topic match, so only matching regions return.
  - `work-swarm` write-set check: grep the write sets, so only shared files return.
  - `work-swarm` aggregate: each worker tree's diff and acceptance exit code and output, with judgment staying with the Lead.
  - `retro` codify: digests for the window, with scouts briefed using scratch paths.
- `skills/poteto/scripts/pr-state.sh`: reads each PR with one `gh pr view --json` call, in parallel, and prints one row per PR. The `orchestrate` and `autopilot` ticks stay on `/loop`, each tick running this one script inside the 10-minute limit with no permission-mode change.

Not adopted now (NG5), with reasons:
- `wayfinder` research fan-out: its research needs `read`, `learn` or `librarian`, which `scout` cannot run.
- The `check` gate: `scripts/workflow/record-check.sh` already batches it.
- `hillclimb`, `check-exercise`, `librarian` and `read`: fits the inventory found, not adopted now.
- The writer wave spawn (work-swarm.md:60 and swarm.md step 3) and the MCP subagent in recall.md: both would launch agents from a script, which the launch rule forbids.

Also kept as model turns: the "a report is a claim" acceptance, the fresh-context risk judge, requirement judging, the in-session phase gate, `grill` and `architect` trade-offs, and merge.

Not made required: Code Mode is not required or the default for consumer repos (NG1).

## 7. Guard gaps

A separate monoclaudian guard plan owns the guard fixes. Its PR must merge before any PR from this plan.

## 8. Sessions

The real interactive Code Mode sessions for each adopted procedure are recorded in this section.

## 9. Pending

- The first full `orchestrate` or `autopilot` tick in Code Mode has not run yet. It is listed here until its first later run.
