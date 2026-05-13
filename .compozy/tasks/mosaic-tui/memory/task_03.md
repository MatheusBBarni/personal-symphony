# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire default Terminal Console mode so Mosaic owns the foreground loop while orchestration runs in a background thread when readiness permits dispatch.
- Preserve `--once`, `--web`, readiness-blocked inspection, and Manual Task Merge behavior without adding task lifecycle mutation controls.

## Important Decisions
- Keep runtime coordination in a small executable-side module, leaving `Orchestrator`, `Runtime_state`, and `Server` semantics unchanged unless a missing seam appears.
- Use explicit synchronization for the in-process Runtime State handoff; document and test latest-state semantics instead of relying on sleeps.
- The Terminal Console runtime starts orchestration through a `start_orchestration ~notify_state` callback before launching the UI, so the UI initial state can reflect the orchestrator's initial snapshot.
- The handoff uses latest-state semantics: updates published before subscription are coalesced to the latest snapshot.

## Learnings
- The current Terminal Console branch renders static text and then runs `Orchestrator.run_forever` in the foreground.
- Existing Web Dashboard mode already starts orchestration on a background thread through `Orchestrator.make ~notify_state`.
- Existing `.compozy` task tracking for task 02 is modified in the worktree and should be preserved.
- `dune build @fmt` is not usable in this environment because `ocamlformat` is missing; backend build and test commands are the reliable verification gates available here.

## Files / Surfaces
- Planned: `apps/backend/bin/main.ml`, executable-side Terminal Console runtime module, `apps/backend/bin/dune`, and focused additions to `apps/backend/test/test_backend.ml`.
- Touched: `apps/backend/bin/terminal_console_runtime.ml`, `apps/backend/bin/main.ml`, `apps/backend/bin/dune`, `apps/backend/test/test_backend.ml`.

## Errors / Corrections

## Ready for Next Run
- Verification passed after implementation with `pnpm backend:build` and `pnpm test`; the test run reported 294 passing backend tests.
- Task tracking is marked complete in `task_03.md` and `_tasks.md`.
- Automatic commit should include implementation files only; workflow memory and `.compozy` tracking files remain tracking context unless explicitly staged by the operator.
