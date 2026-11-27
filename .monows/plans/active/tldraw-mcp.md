---
status: active
lane: normal
---
# Move tldraw-diagram from tldraw offline to the tldraw MCP

## Goal
- outcome: the `tldraw-diagram` skill (owned by monoclaudian `skills/tldraw-diagram/`) draws through the hosted tldraw MCP (`https://mcp.tldraw.com/mcp`, OAuth to a tldraw.com account) instead of the local tldraw offline HTTP server; the offline path is retired
- success_signal: `rg -n 'server.json|tl.sh|localhost' skills/tldraw-diagram` in monoclaudian returns nothing; one diagram is redrawn through MCP and its PNG sits at the path `README.md:116` cites (`site/assets/architecture.png`)
- actors: owner (draws and reviews diagrams); agents running `tldraw-diagram`; readers of README and `site/`
- authority: owner decision 2026-11-27 (MCP-only, map in mono-harness); https://mcp.tldraw.com capability list; monoclaudian `skills/tldraw-diagram/` (installed copy at `~/.claude/skills/tldraw-diagram` is identical)
- requirements:
  - R1: `tldraw-diagram` drives only the tldraw MCP tools; the offline scripts are gone | acceptance: `! rg -n 'server\.json|tl\.sh|localhost|lib\.js|/api/doc' skills/tldraw-diagram && test ! -e skills/tldraw-diagram/scripts` (run in a monoclaudian checkout) | source: Q2, Q8
  - R2: the skill checks repo visibility and stops for a private or unknown repo | acceptance: `rg -n 'visibility' skills/tldraw-diagram/SKILL.md` (run in a monoclaudian checkout) | source: Q3
  - R3: the light-pill style is restated as apply_ops ops (box card, ellipse pill, path band, connect arrows) | acceptance: `rg -n 'apply_ops|kind' skills/tldraw-diagram/styles/light-pill.md && jq -e '.ops|length>0' skills/tldraw-diagram/assets/architecture.ops.json` (run in a monoclaudian checkout) | source: Q7
  - R4: the PNG is written by decoding get_cluster_screenshot's image from a script, with a manual tldraw.com export as the fallback | acceptance: `rg -n 'get_cluster_screenshot' skills/tldraw-diagram/SKILL.md && rg -n 'base64 -d' skills/tldraw-diagram/SKILL.md` (run in a monoclaudian checkout) | source: Q5
  - R5: the architecture diagram is redrawn on a tldraw.com board, README cites that board URL, and its offline source is trashed | acceptance: `rg -n 'tldraw.com/f/' README.md && test -f site/assets/architecture.png && test ! -e site/assets/diagrams/mono-harness-architecture.tldraw` | source: Q4, Q9, success_signal
- non-goals:
  - NG1: editing the vendor-installed `tldraw-offline` skill or agent (`installed-by:tldraw-desktop-agent-skills`); only keep or uninstall
  - NG2: adopting an unofficial tldraw MCP (tldraw-page-mcp, tldraw-mcp-server forks)
  - NG3: drawing tldraw diagrams for private or work repos (Q3)
  - NG4: uninstalling the vendor `tldraw-offline` skill and agent (Q6)

## Map
- Q1: add the tldraw MCP server to Claude Code and sign in with the tldraw.com account | type: task | by: HITL | blocked_by: none | status: out-of-scope for the map (no decision hangs on it now that tldraw's source answered Q2; it becomes the redraw phase's precondition)
- Q2: what does mcp.tldraw.com's real `tools/list` expose: raw-record or JS `exec` access or only typed shape tools; can a screenshot/export be written to a file path; which tools need the file open in a browser tab; can a file be downloaded as `.tldr`/`.tldraw` | type: research | by: AFK | blocked_by: none | status: decided → 14 tools (search_boards, list_workspaces, create_board, rename_board, get_board_info, get_page_info, get_cluster_info, get_cluster_screenshot, apply_ops, get_user_state, get_board_users, read_page_comments, write_comment, send_feedback); no JS or raw-record access, only typed apply_ops ops (add/place/label/connect/rename/restyle/resize/remove/untangle/path/duplicate) with color/fill/dash/size and no font, arrow bend or anchor control; get_cluster_screenshot returns a base64 PNG (longer side ≤2560px) in the tool result, not a file; no .tldr download; get_page_info, get_cluster_info, get_cluster_screenshot and apply_ops need the board open at tldraw.com/f/:slug (apply_ops: in view) | evidence: https://github.com/tldraw/tldraw/blob/main/apps/dotcom/sync-worker/src/routes/tla/boardTools.ts @ main 2026-11-27, packages/dotcom-shared/src/canvasOpsJsonSchema.ts
- Q3: what diagram content may be sent to tldraw.com (public-repo diagrams only, or private-repo topology too) | type: grill | by: HITL | blocked_by: none | status: decided → only diagrams of public repos go to tldraw.com; for a private or work repo the skill says so and stops | evidence: user 2026-11-27
- Q4: where does a diagram's source of truth live after the move: a tldraw.com file whose link the repo records, or a `.tldraw` file kept in git next to the PNG | type: grill | by: HITL | blocked_by: Q2 | status: decided → the tldraw.com board is the source; the repo records its URL where it cites the PNG (no download exists, so MCP-only leaves no .tldraw in git) | evidence: Q2 + user 2026-11-27 (MCP-only, "lock it")
- Q5: how does the committed PNG reach `site/assets/`: an MCP export the agent writes to disk, a manual browser export by the owner, or another route | type: grill | by: HITL | blocked_by: Q2 | status: decided → a REPL script calls get_cluster_screenshot and decodes its base64 image to the PNG path; where the host has no script runtime, the owner exports from tldraw.com | evidence: Q2 (toolPageResult returns {type:'image', data, mimeType:'image/png'}) + user 2026-11-27
- Q6: keep or uninstall the vendor `tldraw-offline` skill and agent once `tldraw-diagram` is MCP-only | type: grill | by: HITL | blocked_by: Q2 | status: out-of-scope (the rewritten skill no longer depends on it; uninstalling is a separate owner action)
- Q7: how does light-pill map onto apply_ops: card = box (black, fill semi, dash draw, text = body lines), pill = add shape geo ellipse at (x+14, y-17) in the role color, band = path rule + ellipse dot + label, arrows = connect with role color | type: research | by: AFK | blocked_by: Q2 | status: decided → as stated; draw font, pill text scale, arrow bend/elbow and pinned anchors are dropped; layout checks move from getLints to the apply_ops result plus a screenshot look | evidence: canvasOpsJsonSchema.ts
- Q8: how does a redraw stay safe on a cloud board shared with others | type: research | by: AFK | blocked_by: Q2 | status: decided → one board per diagram made with create_board; a redraw removes only the skill's own ids (remove targets by id), never clears the page | evidence: apply_ops remove targets; lib.js:1 cleared the page
- Q9: what happens to site/assets/diagrams/mono-harness-{architecture,workflow}.tldraw and README.md:118-120 | type: grill | by: HITL | blocked_by: Q4 | status: decided → redraw architecture through MCP (success signal), then point README at the board URL and trash the redrawn .tldraw; the workflow .tldraw stays until it is redrawn | evidence: user 2026-11-27 success_signal

## Phases and Verification
- approach: rewrite the skill around apply_ops batches stored as JSON; rejected: an unofficial exec-capable MCP (NG2), keeping offline as a fallback (owner chose MCP-only)
- phase_slug: `main`
  status: done
  - goal: R1, R2, R3, R4, R5 | depends_on: none
  - surfaces: monoclaudian `skills/tldraw-diagram/**`; mono-harness `README.md`, `site/assets/architecture.png`, `site/assets/diagrams/` | avoided: `~/.claude/skills/tldraw-offline`, `~/.claude/agents/tldraw-offline.md` (NG1, NG4)
  - phase check: each requirement's acceptance command; R5 needs Q1 (owner signed in, board open in a browser tab)

## Log
- 2026-11-27 main: rewrote monoclaudian `skills/tldraw-diagram` (SKILL.md v2.0.0, styles/light-pill.md as apply_ops ops, assets/architecture.ops.json); trashed `scripts/` and the three `.js` examples; README.md:41 skill row updated. Uncommitted in monoclaudian. architecture.ops.json validated against canvasOpsJsonSchema.ts @ main (34 ops, 0 errors). Executor read (canvas-ops/ops.ts, actions.ts @ main): ids persist as shape:<id>; add on an existing id errors; one unknown id fails a whole remove op, so a redraw removes one id per op; a geo label grows its shape, so the pill text is a separate label.

- 2026-11-27 R5 live run: tldraw MCP added at user scope and signed in; board created; first layout had a writes/install crossing, so columns were reordered (guards, skills, zh / host / plans, managed) and redrawn by per-id remove (35 removed incl. arr_skills_host-label); added a white margin path because the screenshot clipped bottom borders. Claude Code's REPL returns the screenshot as a saved file path ([Image: source: …]), not base64; SKILL.md export section updated to match.

- 2026-11-27 main: committed monoclaudian 71f9e56 (branch feat/tldraw-diagram-mcp, PR https://github.com/tinhtute/monoclaudian/pull/12); R1–R4 acceptance repointed to paths relative to a monoclaudian checkout.

## Validation
- 2026-11-27 R1 pass: rg offline terms empty, scripts/ absent (rc=0)
- 2026-11-27 R2 pass: SKILL.md:32 visibility check
- 2026-11-27 R3 pass: light-pill.md cites apply_ops/kind; jq .ops length>0 → true
- 2026-11-27 R4 pass: SKILL.md:26 get_cluster_screenshot, SKILL.md:54 base64 -d
- 2026-11-27 monoclaudian `bash scripts/validate-skills.sh` → skills OK (6 skills)
- 2026-11-27 R5 pass: README.md:119 cites https://www.tldraw.com/f/kSlGDIpz4cDe1Fy2IOkds; site/assets/architecture.png (2000px, from get_cluster_screenshot) present; mono-harness-architecture.tldraw trashed; verify-doc-links OK
- 2026-11-27 R1–R4 re-run after the live fixes: pass; ops schema check 35 ops, 0 errors

## Current State and Next Action
- active_phase: main
- lifecycle_status: in-progress
- blockers: none
- open_items: none
- exact_next_action: after monoclaudian PR #12 and this PR merge, complete the plan (move to `.monows/plans/completed/`)
