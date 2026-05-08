# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Update frontend Runtime State consumption from `codex_totals` to `usage_totals`, accept running-row Harness identity, surface it in dashboard issue cards, and refresh live-state tests.

## Important Decisions
- Extracted the browser-side Runtime State -> dashboard snapshot mapping into `apps/frontend/src/RuntimeStateSnapshot.res` so Node live-state tests can exercise provider-neutral token and Harness mapping without importing `Main.res` browser/CSS side effects.

## Learnings
- `apps/frontend/test/liveState.test.mjs` can import generated `.res.js` modules after `rescript build`; pure ReScript modules are safer test targets than `Main.res` because `Main.res` imports CSS and touches `document`.
- Runtime State JSON parsed into plain ReScript records treats missing optional fields as `undefined`, but explicit JSON `null` does not automatically behave like `None`; nullable strings in the frontend mapper need boundary normalization.

## Files / Surfaces
- `apps/frontend/src/Main.res`
- `apps/frontend/src/RuntimeStateSnapshot.res`
- `apps/frontend/src/Pages/Dashboard.res`
- `apps/frontend/test/liveState.test.mjs`

## Errors / Corrections
- Avoided keeping a literal old Runtime State key reference in frontend tests because the task success criterion requires no frontend references to that key.
- Expanded tests caught nullable Runtime State values rendering as `"null"` in the extracted mapper; fixed with string normalization helpers before displaying optional Runtime State fields.

## Ready for Next Run
- Task 06 implementation and verification are complete. Required evidence: `pnpm frontend:test`, `pnpm frontend:build`, `git diff --check`, no frontend source/test references to old Runtime State totals key, and Node coverage for `RuntimeStateSnapshot.res.js` above 80%.
