# Preserve legacy intake compatibility for ready-status admission

## Status

Accepted

## Context

The ready-status intake work adds `project.readyStatus` as a tracker-owned first-admission control. New Runtime Contracts may set this field to require exact ready-status admission, but existing Workspace Repositories may already rely on `project.activeStates` for GitHub intake or on Compozy `_tasks.md` files that contain only a task table.

If Symphony treated the default ready-status value as explicit for every Runtime Contract, legacy GitHub-backed repositories could stop admitting `Todo` or `In Progress` issues. If Compozy required a run-level ready-status line in every existing `_tasks.md`, older Compozy PRD Runs could become parse-blocked even though their task-step files are otherwise runnable.

## Decision

Runtime Settings parsing distinguishes an explicit `project.readyStatus` from the default effective ready-status value. GitHub first admission uses exact `project.readyStatus` matching only when the Runtime Contract explicitly sets the field; otherwise, GitHub preserves legacy active-state first admission. GitHub candidate visibility includes the explicit ready status so ready issues are fetched before the first-admission decision runs.

Compozy first admission continues to prefer a run-level `_tasks.md` ready status when present. For compatibility, missing `_tasks.md` files or task-list-only `_tasks.md` files without a run-level ready-status line fall back to the existing runnable-run admission path. Malformed ready-status declarations still produce deterministic parse-blocked intake evaluations.

## Consequences

Existing Runtime Contracts keep admitting work according to their active-state and task-step rules until they opt into `project.readyStatus`.

New Runtime Contracts that include `project.readyStatus` get exact ready-status first admission without relying on `project.activeStates` to make ready issues visible.

Compozy `_tasks.md` remains the run-level intake source for ready-status-aware runs, while legacy task-list files avoid a surprise parse_blocked state.
