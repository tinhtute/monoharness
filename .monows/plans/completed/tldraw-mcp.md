---
status: completed
lane: normal
---
# Move tldraw-diagram from tldraw offline to the tldraw MCP

## Goal
- outcome: the `tldraw-diagram` skill (owned by monoclaudian `skills/tldraw-diagram/`) draws through the hosted tldraw MCP (`https://mcp.tldraw.com/mcp`, OAuth to a tldraw.com account) instead of the local tldraw offline HTTP server; the offline app stays as a fallback when the MCP is missing (Q10)
- success_signal: the skill routes to the MCP first and to `scripts/tl.sh` only when the MCP is missing; one diagram is redrawn through MCP and its PNG sits at the path `README.md:116` cites (`site/assets/architecture.png`)
- actors: owner (draws and reviews diagrams); agents running `tldraw-diagram`; readers of README and `site/`
- authority: owner decision 2026-11-27 (MCP first, map in mono-harness; offline fallback added the same day, Q10); https://mcp.tldraw.com capability list; monoclaudian `skills/tldraw-diagram/` (installed copy at `~/.claude/skills/tldraw-diagram` is identical)
- requirements:
  - R1: `tldraw-diagram` drives the tldraw MCP tools first; the offline scripts run only in the fallback section | acceptance: `rg -n 'mcp__tldraw__get_cluster_screenshot' skills/tldraw-diagram/SKILL.md && ! rg -n 'lib\.js' skills/tldraw-diagram` (run in a monoclaudian checkout) | source: Q2, Q8, Q10
  - R2: the skill checks repo visibility and stops for a private or unknown repo | acceptance: `rg -n 'visibility' skills/tldraw-diagram/SKILL.md` (run in a monoclaudian checkout) | source: Q3
  - R3: the light-pill style is restated as apply_ops ops (box card, ellipse pill, path band, connect arrows) | acceptance: `rg -n 'apply_ops|kind' skills/tldraw-diagram/styles/light-pill.md && jq -e '.ops|length>0' skills/tldraw-diagram/assets/architecture.ops.json` (run in a monoclaudian checkout) | source: Q7
  - R4: the PNG is written by decoding get_cluster_screenshot's image from a script, with a manual tldraw.com export as the fallback | acceptance: `rg -n 'get_cluster_screenshot' skills/tldraw-diagram/SKILL.md && rg -n 'base64 -d' skills/tldraw-diagram/SKILL.md` (run in a monoclaudian checkout) | source: Q5
  - R6: when no tldraw MCP tools are connected, the skill draws the same ops file in tldraw offline and exports a PNG | acceptance: `rg -n '## Offline fallback' skills/tldraw-diagram/SKILL.md && test -x skills/tldraw-diagram/scripts/tl.sh && rg -n "op === 'connect'" skills/tldraw-diagram/scripts/ops-offline.js` (run in a monoclaudian checkout) | source: Q10
  - R5: the architecture diagram is redrawn on a tldraw.com board, README cites that board URL, and its offline source is trashed | acceptance: `rg -n 'tldraw.com/f/' README.md && test -f site/assets/architecture.png && test ! -e site/assets/diagrams/mono-harness-architecture.tldraw` | source: Q4, Q9, success_signal
- non-goals:
  - NG1: editing the vendor-installed `tldraw-offline` skill or agent (`installed-by:tldraw-desktop-agent-skills`); only keep or uninstall
  - NG2: adopting an unofficial tldraw MCP (tldraw-page-mcp, tldraw-mcp-server forks)
  - NG3: drawing tldraw diagrams for private or work repos (Q3)
  - NG4: uninstalling the vendor `tldraw-offline` skill and agent (Q6)
  - NG5: a second offline-only style or ops format; the fallback reads the same apply_ops ops file

## Map
- Q1: add the tldraw MCP server to Claude Code and sign in with the tldraw.com account | type: task | by: HITL | blocked_by: none | status: out-of-scope for the map (no decision hangs on it now that tldraw's source answered Q2; it becomes the redraw phase's precondition)
- Q2: what does mcp.tldraw.com's real `tools/list` expose: raw-record or JS `exec` access or only typed shape tools; can a screenshot/export be written to a file path; which tools need the file open in a browser tab; can a file be downloaded as `.tldr`/`.tldraw` | type: research | by: AFK | blocked_by: none | status: decided → 14 tools (search_boards, list_workspaces, create_board, rename_board, get_board_info, get_page_info, get_cluster_info, get_cluster_screenshot, apply_ops, get_user_state, get_board_users, read_page_comments, write_comment, send_feedback); no JS or raw-record access, only typed apply_ops ops (add/place/label/connect/rename/restyle/resize/remove/untangle/path/duplicate) with color/fill/dash/size and no font, arrow bend or anchor control; get_cluster_screenshot returns a base64 PNG (longer side ≤2560px) in the tool result, not a file; no .tldr download; get_page_info, get_cluster_info, get_cluster_screenshot and apply_ops need the board open at tldraw.com/f/:slug (apply_ops: in view) | evidence: https://github.com/tldraw/tldraw/blob/main/apps/dotcom/sync-worker/src/routes/tla/boardTools.ts @ main 2026-11-27, packages/dotcom-shared/src/canvasOpsJsonSchema.ts
- Q3: what diagram content may be sent to tldraw.com (public-repo diagrams only, or private-repo topology too) | type: grill | by: HITL | blocked_by: none | status: decided → only diagrams of public repos go to tldraw.com; for a private or work repo the skill says so and stops | evidence: user 2026-11-27
- Q4: where does a diagram's source of truth live after the move: a tldraw.com file whose link the repo records, or a `.tldraw` file kept in git next to the PNG | type: grill | by: HITL | blocked_by: Q2 | status: decided → the tldraw.com board is the source; the repo records its URL where it cites the PNG (no download exists, so MCP-only leaves no .tldraw in git) | evidence: Q2 + user 2026-11-27 (MCP-only, "lock it")
- Q5: how does the committed PNG reach `site/assets/`: an MCP export the agent writes to disk, a manual browser export by the owner, or another route | type: grill | by: HITL | blocked_by: Q2 | status: decided → a REPL script calls get_cluster_screenshot and decodes its base64 image to the PNG path; where the host has no script runtime, the owner exports from tldraw.com | evidence: Q2 (toolPageResult returns {type:'image', data, mimeType:'image/png'}) + user 2026-11-27
- Q6: keep or uninstall the vendor `tldraw-offline` skill and agent once `tldraw-diagram` is MCP-only | type: grill | by: HITL | blocked_by: Q2 | status: out-of-scope (the rewritten skill no longer depends on it; uninstalling is a separate owner action)
- Q7: how does light-pill map onto apply_ops: card = box (black, fill semi, dash draw, text = body lines), pill = add shape geo ellipse at (x+14, y-17) in the role color, band = path rule + ellipse dot + label, arrows = connect with role color | type: research | by: AFK | blocked_by: Q2 | status: decided → as stated; draw font, pill text scale, arrow bend/elbow and pinned anchors are dropped; layout checks move from getLints to the apply_ops result plus a screenshot look | evidence: canvasOpsJsonSchema.ts
- Q8: how does a redraw stay safe on a cloud board shared with others | type: research | by: AFK | blocked_by: Q2 | status: decided → one board per diagram made with create_board; a redraw removes only the skill's own ids (remove targets by id), never clears the page | evidence: apply_ops remove targets; lib.js:1 cleared the page
- Q10: what does the skill do on a machine without the tldraw MCP | type: grill | by: HITL | blocked_by: none | status: decided → fall back to tldraw offline, interpreting the same ops file through the app's local API, only when the MCP is missing; the Q3 public-repo gate still stops a private repo (letting offline draw private repos, since nothing is uploaded, is pending owner confirmation) | evidence: user 2026-11-27 ("thêm lại cái vẽ bằng tldraw offline làm fallback khi không có mcp")
- Q9: what happens to site/assets/diagrams/mono-harness-{architecture,workflow}.tldraw and README.md:118-120 | type: grill | by: HITL | blocked_by: Q4 | status: decided → redraw architecture through MCP (success signal), then point README at the board URL and trash the redrawn .tldraw; the workflow .tldraw stays until it is redrawn | evidence: user 2026-11-27 success_signal

## Phases and Verification
- approach: rewrite the skill around apply_ops batches stored as JSON; rejected: an unofficial exec-capable MCP (NG2), a separate offline drawing library (NG5); offline returns as a fallback over the same ops (Q10)
- phase_slug: `main`
  status: done
  - goal: R1, R2, R3, R4, R5, R6 | depends_on: none
  - surfaces: monoclaudian `skills/tldraw-diagram/**`; mono-harness `README.md`, `site/assets/architecture.png`, `site/assets/diagrams/` | avoided: `~/.claude/skills/tldraw-offline`, `~/.claude/agents/tldraw-offline.md` (NG1, NG4)
  - phase check: each requirement's acceptance command; R5 needs Q1 (owner signed in, board open in a browser tab)

## Log
- 2026-11-27 main: rewrote monoclaudian `skills/tldraw-diagram` (SKILL.md v2.0.0, styles/light-pill.md as apply_ops ops, assets/architecture.ops.json); trashed `scripts/` and the three `.js` examples; README.md:41 skill row updated. Uncommitted in monoclaudian. architecture.ops.json validated against canvasOpsJsonSchema.ts @ main (34 ops, 0 errors). Executor read (canvas-ops/ops.ts, actions.ts @ main): ids persist as shape:<id>; add on an existing id errors; one unknown id fails a whole remove op, so a redraw removes one id per op; a geo label grows its shape, so the pill text is a separate label.

- 2026-11-27 R5 live run: tldraw MCP added at user scope and signed in; board created; first layout had a writes/install crossing, so columns were reordered (guards, skills, zh / host / plans, managed) and redrawn by per-id remove (35 removed incl. arr_skills_host-label); added a white margin path because the screenshot clipped bottom borders. Claude Code's REPL returns the screenshot as a saved file path ([Image: source: …]), not base64; SKILL.md export section updated to match.

- 2026-11-27 main: committed monoclaudian 71f9e56 (branch feat/tldraw-diagram-mcp, PR https://github.com/tinhtute/monoclaudian/pull/12); R1–R4 acceptance repointed to paths relative to a monoclaudian checkout.
- 2026-11-27 main: offline-style parity pass (owner: "fix all theo offline style"): cards left-aligned via add align:'start'; pills drawn as closed stadium paths (no oval geo in apply_ops) at x+12,y-16, w 10n+40, h 30, text at x+24,y-14 resized to scale 0.9; host and consumer rows moved 30 down so "install" stays on its shaft in black; margin_top + margin give 32px padding; plans padded with a trailing newline. Board redrawn (36 removed, 42 applied, 0 errors); PNG re-exported. Vertical text alignment and arrow bend still have no op.
- 2026-11-27 main: merged monoclaudian #12 as 6e4750f and mono-harness #309 as 687a175 (risk-verdict: independent judge, low risk on 66f6226); plan closed
- 2026-11-27 main: offline fallback (Q10): monoclaudian SKILL.md v2.2.0 adds routing and an Offline fallback section; scripts/tl.sh (draw, png, exec, search), scripts/ops-offline.js (interprets add/path/resize/connect/remove; closed path → oval geo; replaces only the ops' ids) and scripts/export-png.js (padding 0, scale 2); monoclaudian README row updated.

## Validation
- 2026-11-27 R1 pass: rg offline terms empty, scripts/ absent (rc=0)
- 2026-11-27 R2 pass: SKILL.md:32 visibility check
- 2026-11-27 R3 pass: light-pill.md cites apply_ops/kind; jq .ops length>0 → true
- 2026-11-27 R4 pass: SKILL.md:26 get_cluster_screenshot, SKILL.md:54 base64 -d
- 2026-11-27 monoclaudian `bash scripts/validate-skills.sh` → skills OK (6 skills)
- 2026-11-27 R5 pass: README.md:119 cites https://www.tldraw.com/f/kSlGDIpz4cDe1Fy2IOkds; site/assets/architecture.png (2000px, from get_cluster_screenshot) present; mono-harness-architecture.tldraw trashed; verify-doc-links OK
- 2026-11-27 R1–R4 re-run after the live fixes: pass; ops schema check 35 ops, 0 errors
- 2026-11-27 R6 pass: tl.sh draw architecture.ops.json into a scratch .tldraw → success, 42 applied, 36 shapes, 0 lints; drawn twice to prove the id-scoped redraw; tl.sh png → 2000×1296 PNG reviewed against the MCP export
- 2026-11-27 R6 edge cases: an existing .tldraw not open in the app → tl.sh opens it, draw rc=0 and png rc=0; an unsupported op (untangle) → rc=1, error "ops[1]: untangle is not supported offline"; private repos still stop at the visibility check
- 2026-11-27 R1 re-check after Q10: MCP tools cited, no lib.js; monoclaudian validate-skills OK (6 skills)
- 2026-11-27 parity pass: ops file 42 ops, schema check 0 errors; apply_ops 42 applied, 0 errors, no "beside it" label; monoclaudian validate-skills OK (6 skills); screenshot reviewed against the offline PNG

## Current State and Next Action
- active_phase: none
- lifecycle_status: completed
- blockers: none
- open_items: none; letting the offline fallback draw private repos stays open for the owner (Q10)
- exact_next_action: none; the plan is closed
