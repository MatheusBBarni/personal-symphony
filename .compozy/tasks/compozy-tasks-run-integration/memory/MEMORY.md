# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- Compozy tracker config parsing intentionally does not validate that `tracker.compozy.root` exists; file/directory validation belongs to later readiness/tracker tasks.
- The repository has no configured backend coverage command or Bisect instrumentation; Compozy backend tasks have been verifying coverage expectations with focused Alcotest cases plus the full `pnpm test` suite unless coverage tooling is later added.
- The frontend package also has no configured coverage command; Compozy frontend tasks should use focused live-state/render assertions plus `pnpm frontend:test` and `pnpm frontend:build` unless coverage tooling is added.
- Do not run Dune commands such as `pnpm test` and `pnpm backend:build` concurrently, and do not run ReScript commands such as `pnpm frontend:test` and `pnpm frontend:build` concurrently; both toolchains use shared build state and can fail from runner contention.
- CLI readiness state construction now lives in `Runtime_readiness`; `main.ml` delegates readiness state assembly there so startup readiness can be tested through the backend library.
- Compozy task-step frontmatter mutations during orchestration must be applied to the Agent Worktree copy so Stage Commit and Task Branch Integration can carry the persisted task-step status changes.

## Open Risks

## Handoffs
- The Compozy `Issue_tracker` adapter currently fetches runnable PRD-run candidates and reports local readiness, but `update_status` is intentionally no-op until the sequential task-step orchestration task wires frontmatter transitions.
