# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03 readiness-only minibeads adapter: selected by `tracker.kind = "minibeads"`, checks configured `mb` command availability, checks configured local store root, reports deterministic readiness diagnostics, and avoids full issue parsing/status writes.

## Important Decisions
- Keep this task limited to readiness. Fetch, lookup, blocker mapping, and status mutation will return deterministic "not implemented in this task" results or remain GitHub-only until task 04+.
- Startup readiness now asks the selected `Issue_tracker` for tracker gaps. Ordered Queue validation remains GitHub-only for now and is skipped for non-GitHub trackers until the queue task updates selected-tracker validation.
- The minibeads readiness command is intentionally minimal: check executable availability, check configured store root exists as a directory, then run the configured command with `--version` from the Workspace Repository root. Command output and exceptions are sanitized into deterministic readiness diagnostics.

## Learnings
- Baseline code had config support for minibeads from task 01 and a GitHub-only `Issue_tracker` boundary from task 02; this task added the minibeads adapter selection.
- Baseline startup readiness in `apps/backend/bin/main.ml` called `Github_tracker.remote_readiness_gaps` directly when local config gaps were clear; this task now routes tracker readiness through `Issue_tracker`.
- No coverage-specific command is configured in this repository; validation evidence for this task is focused Alcotest additions plus the full `pnpm test` backend suite.

## Files / Surfaces
- Expected source surfaces: `apps/backend/lib/minibeads_tracker.ml`, `apps/backend/lib/issue_tracker.ml`, `apps/backend/bin/main.ml`, `apps/backend/test/test_backend.ml`.
- Touched source surfaces: `apps/backend/lib/minibeads_tracker.ml`, `apps/backend/lib/issue_tracker.ml`, `apps/backend/bin/main.ml`, `apps/backend/test/test_backend.ml`.
- Tracking/memory surfaces: current task memory, shared workflow memory, task 03 tracking, and master task table.

## Errors / Corrections
- Initial focused test run exposed assertion issues, not adapter behavior: macOS temp paths differed by `/private` canonicalization, and the runtime readiness test expected no unrelated local config gaps. Assertions were tightened to the task contract.

## Ready for Next Run
- Verification evidence after final code change: `pnpm test` exited 0 and ran 168 Alcotest backend tests, including five new minibeads readiness cases and the selected-adapter case.
- Follow-up for task 04: implement real minibeads candidate fetch, lookup, blocker mapping, and status updates using the existing injected runner pattern.
