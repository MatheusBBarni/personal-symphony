# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions
- Runtime State Compozy progress preserves lifecycle absence as optional null/absence when no lifecycle metadata exists; it does not synthesize lifecycle text during progress construction.
- Runtime State `handoff_status` is derived from Compozy lifecycle `pr_readiness` values `handoff_attempting`, `handoff_completed`, and `handoff_failed`; task_01 lifecycle metadata does not persist a separate raw handoff status.

## Shared Learnings
- Compozy tracker discovery/lookup now lazy-backfills lifecycle metadata under Runtime Home. Git-backed test fixtures that poll the Compozy tracker must have Runtime Home ignored before polling, or clean-worktree dispatch checks will correctly see the new runtime files as dirt.
- Do not run Dune-backed verification commands concurrently in this repository, such as `pnpm test` and `pnpm backend:build`; they share `_build` and can trip Dune's global lock.

## Open Risks

## Handoffs
