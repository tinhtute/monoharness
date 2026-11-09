# Playbook: pause

The write-side twin of [session-pickup](session-pickup.md): leave a checkpoint a cold-start agent resumes from. Runs only on an explicit pause ("pause", "stop here", "save state for later"). "Keep going", "don't stop" or "going to bed, keep going" is not a pause: continue the current playbook.

1. Stop at a safe boundary: finish the current atomic step or back it out; start nothing new; stop every running sub-agent and confirm each stop.
2. Pause with reversible actions only: open no PR and push nothing that was not already pushed; leave branches, bases and worktrees as they are.
3. `handoff` — with an active plan, write `## Current State and Next Action`: intent, what is verified and by which command, what is unverified, blockers, key files and one exact next action. Without an active plan, those same fields go into the step 4 commit body, which `session-pickup` reads on resume; create no other resume file.
4. `git` — the pause request counts as the owner's commit ask: one `chore(wip): <what>` commit, overriding the `git` skill's split by kind, staging only the paths this session changed. On the default branch, create a branch first; never commit wip to the default branch. A broken tree is stated in one body line. The commit goes through the hooks; a hook rejection is reported with its output, never bypassed with `--no-verify`. Nothing to commit and no active plan → say the reply is the only record.

Reply: where the work stopped, what is on disk versus only in this session (paths, no diff dumps), the commit SHA and whether the tree is clean, and the first action on resume. This is a pause, not a completion report.
