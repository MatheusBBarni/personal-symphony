# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire Ordered Queue readiness diagnostics so bare Compozy-style slugs under non-Compozy tracker modes produce guided tracker-mismatch remediation while structural parse errors remain parse-stage gaps.

## Important Decisions
- Keep mismatch remediation in `Ordered_queue.resolve` so readiness and later orchestration users share the same raw-to-canonical queue contract.
- Check mixed bare/canonical Compozy styles before duplicate detection so MVP mixed-style guidance wins for `example-feature,compozy:example-feature`.

## Learnings
- Pre-change startup signal: a ready minibeads workspace running `symphony --once --queue example-feature` blocks with a generic minibeads identifier remediation, not a guided Compozy tracker-mismatch message.
- Task 01 already added `Ordered_queue.resolve` and readiness currently calls `Ordered_queue.validation_gaps` after tracker selection; task 02 can stay focused on diagnostic classification and coverage.
- Post-change startup signal: the same ready minibeads `--once --queue example-feature` path reports one Readiness Gap naming `tracker.kind = "minibeads"` and the required `tracker.kind = "compozy_tasks"` for bare slugs.

## Files / Surfaces
- Touched `apps/backend/lib/ordered_queue.ml` for queue style remediation and mixed-style precedence.
- Touched `apps/backend/test/test_backend.ml` for readiness/startup coverage around mismatch, mixed style, parse-stage separation, resolved duplicates, and canonical Compozy validation.

## Errors / Corrections
- Correction: an initial parallel `pnpm backend:build` plus `pnpm test` attempt hit Dune's single-instance lock. Re-ran `pnpm test` by itself and it passed.

## Ready for Next Run
- Final verification evidence: focused runtime-state queue tests passed; real temporary-workspace `symphony --once --queue example-feature` showed guided readiness output; post-tracking `pnpm backend:build`, `pnpm test`, explicit full Alcotest run, and `git diff --check` all exited 0.
