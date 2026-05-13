# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 05 in the Product Repository: keyboard-first Terminal Console navigation, contextual help/footer, UI-only filtering/search, non-mutating refresh, Web Dashboard handoff guidance, and validated read-only local path inspection aids.
- Preserve the MVP boundary that Terminal Console key handlers must not call task lifecycle mutation paths such as retry, pause, resume, merge, push, tracker status update, cleanup, pull request creation, or `Server.serve`.

## Important Decisions
- Kept keyboard interactions in `Terminal_console_mosaic` as a UI-local reducer (`apply_key`) that returns allowlisted safe-aid requests instead of calling orchestration, tracker, server, or lifecycle functions.
- Web Dashboard handoff is CLI guidance only: `main.ml` passes the effective port into the Terminal Console runtime, and the key handler only renders `symphony --web --port <port>` plus the local URL.
- Local path inspection validates existing paths against configured Workspace Repository surfaces (`Workspace Repository` and `Runtime Home`) and only emits a `Show_path` safe-aid request after validation; the handler does not read or modify file contents.

## Learnings
- The implementation files named by the task live in `/Users/matheusbbarni/projects/symphony-orchestrator`, not the initial `/Users/matheusbbarni/projects/pi-agent-native` working directory.
- Repository-local `AGENTS.md`/`CLAUDE.md` require `pnpm test` for backend runtime behavior changes and narrowly scoped additions to the existing large `apps/backend/test/test_backend.ml`.
- Existing `terminal_console_mosaic.ml` only handled `q`, `Escape`, and `r` before this task; task detail selection was fixed to the first active row.

## Files / Surfaces
- `apps/backend/bin/terminal_console_mosaic.ml` — interaction state, key reducer, contextual footer/help, filtering, refresh/handoff/path safe aids, path validation, rendering selection markers.
- `apps/backend/bin/terminal_console_runtime.ml` — runtime handoff now carries optional safe-aid handler, Web Dashboard handoff guidance, and allowed local surfaces.
- `apps/backend/bin/main.ml` — supplies the effective Web Dashboard port plus Workspace Repository/Runtime Home local surfaces to the Terminal Console runtime.
- `apps/backend/lib/terminal_console_model.ml` — projects `Show_path` safe-aid descriptors from Runtime State diagnostic/workspace paths.
- `apps/backend/test/test_backend.ml` — focused reducer and safe-aid tests, plus fake runtime safe-aid handler integration coverage.

## Errors / Corrections
- The initial filtering test used `r` and then `y`, both of which matched more than one projected row because details include generated branch/context text; the test now filters by the retry row identifier digit.

## Ready for Next Run
- Verification passed after implementation: `pnpm test` (310 tests) and `pnpm backend:build`.
- Code/test changes were committed locally as `3193227 feat: add terminal console keyboard aids`; tracking and memory files remain uncommitted by workflow rule.
- No durable cross-task memory promotion was needed; the remaining Task 06 documentation work can inspect the committed code and task tracking for details.
