# Notice

`playbooks/ship.md` (landing steps), `refactoring.md`, `perf.md`, `babysit.md` and `prototype.md` adapt poteto-mode playbooks from [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude).

`playbooks/hillclimb.md` and `pause.md` adapt poteto-mode playbooks from [cursor/plugins `pstack/`](https://github.com/cursor/plugins/tree/main/pstack) (v0.15.36, MIT, Copyright 2026 Lauren Tan).

`playbooks/orchestrate.md` and `autopilot.md` adapt poteto-mode playbooks from [cursor/plugins `pstack/`](https://github.com/cursor/plugins/tree/main/pstack) (v0.15.36, `6b03002`, MIT, Copyright 2026 Lauren Tan).

## Names that differ from pstack

Theirs is [cursor/plugins `pstack/`](https://github.com/cursor/plugins/tree/main/pstack) v0.15.36. Since is the commit where our current name first appeared. Add a row in the commit that introduces a new divergence.

Kinds:
- `rename`: ours maps to theirs under another name; Why says where the two differ.
- `split`: one of ours maps to two of theirs.
- `homonym`: same name, different concept.
- `rewrite`: same name and concept, our own text.
- `parallel`: our name predates the pstack import; the concepts overlap.

| Ours | Theirs | Kind | Why | Since |
|---|---|---|---|---|
| skill `poteto` | `poteto-mode` | rename | `poteto-mode` would collide when pstack is installed beside it | `375862d` 2026-11-11 |
| playbook `perf` | `perf-issue` | rename | shorter and already unambiguous | `7b48396` 2026-10-23 |
| playbook `ship` | `shipping` | rename | ours lands one PR behind a risk verdict; theirs lands a verified stack bottom-up | `e83c556` 2026-10-23 |
| playbook `pause` | `pause-safely` | rename | shorter | `13b36da` 2026-11-09 |
| playbook `swarm` | skill `swarm` | rewrite | a playbook over `work-swarm.md` that runs on `work full`; theirs is one skill | pending (renamed from `fanout`, `96d9318` 2026-10-23) |
| playbook `autopilot` | `autopilot-full`, `autopilot-stack` | split | one file; the `full` mode decides whether it merges | `f5fdfd7` 2026-11-09 |
| skill `ambition` | `sharpen` | rename | adds lenses and a prompt linter | `0974b3e` 2026-10-30 |
| skill `mono-write` | `unslop`, `technical-writing` | split | covers only research drafts and changelogs | `e2adba3` 2026-11-06 |
| skill `arena` | `arena` | rewrite | six steps on `work-swarm.md`, plus an output template | `96d9318` 2026-10-23 |
| agent `architect` | skill `architect` | homonym | ours challenges a design read-only in one sealed report; theirs sketches types, then implements | `1cace0a` 2026-11-13 |
| skill `retro` | `reflect` | parallel | ours keeps a durable ledger and one gated fix; theirs keeps nothing | `5a25914` 2026-09-25 |
| skill `watzup` | `ketchup`, `recall` | parallel | older name, kept | `ab26b38` 2026-05-02 |
| skill `handoff` | playbook `pause-safely` | parallel | ours writes the plan's Current State; theirs writes a `wip:` commit and a `/tmp` note | `ab26b38` 2026-05-02 |
