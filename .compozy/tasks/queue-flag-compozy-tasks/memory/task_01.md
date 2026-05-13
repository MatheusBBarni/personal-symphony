# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task_01 primitives only: generic Ordered Queue parsing for opaque bare tokens, post-settings raw-to-canonical queue resolution, Compozy bare-slug normalization, and focused tests.

## Important Decisions
- Keep `Ordered_queue.entry.issue_identifier` as the existing serialized queue-state field for compatibility, but treat it as the queue/raw identifier for bare Compozy shortcut entries and add a separate resolved-entry type for canonical tracker identifiers.
- Move duplicate detection into tracker-aware queue resolution so collisions are based on selected tracker canonical identifiers.

## Learnings
- The initial working directory did not contain `AGENTS.md` or `CLAUDE.md`; the implementation repository and PRD docs are under `/Users/matheusbbarni/projects/symphony-orchestrator`.
- Root/backend guidance requires `pnpm test` after OCaml backend runtime behavior changes.
- `Ordered_queue.parse` no longer owns duplicate detection; `Ordered_queue.resolve` reports canonical duplicate collisions after selected-tracker normalization.
- Full `pnpm test` had one transient context-command diagnostic failure on the first run; the isolated failing test passed, and a fresh full rerun passed 343 tests.

## Files / Surfaces
- Touched: `apps/backend/lib/ordered_queue.ml`, `apps/backend/lib/issue_tracker.ml`, `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- Added explicit OCaml record annotations and changed the resolved queue wrapper field to `resolved_entries` to avoid record-label ambiguity with the existing Ordered Queue `entries` field.

## Ready for Next Run
- Later readiness/orchestration tasks should consume `Ordered_queue.resolve` and `Ordered_queue.resolved_identifiers` instead of re-normalizing queue entries locally.
