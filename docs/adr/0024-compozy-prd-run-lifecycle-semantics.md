# Persist Compozy PRD Run lifecycle semantics

## Status

Accepted

## Context

The Compozy-backed Local Issue Tracker treats one `.compozy/tasks/<task_name>/` directory as a Compozy PRD Run and treats `task_NN.md` files as Compozy Task Steps inside the same work item. Step frontmatter already records task-step progress such as `pending`, `in_progress`, `completed`, `failed`, and `skipped`, but that progress does not tell an operator whether the whole Compozy PRD Run is planning, executing, reviewing, blocked, completed, failed, skipped, not-PR-ready, or in pull-request handoff.

Operators need Runtime State, the Terminal Console, and the Web Dashboard to answer both questions: what lifecycle state the Compozy PRD Run is in, and whether the run is eligible for a Batch Pull Request. The answer must preserve the existing Pull Request Policy defaults, avoid GitHub API requirements for Compozy status visibility, and keep batch mode aggregate instead of creating per-step pull requests.

## Decision

Personal Symphony persists Compozy PRD Run lifecycle metadata under Runtime Home state and exposes it through the existing Runtime State Compozy progress summary. The Compozy PRD Run lifecycle is run-level state. Compozy Task Step frontmatter remains the source for current step selection and step counts.

The lifecycle states are `pending`, `in_planning`, `in_execution`, `in_review`, `blocked`, `completed`, `failed`, `skipped`, `not_pr_ready`, and `pr_handoff`. Pull-request eligibility is represented separately as Compozy PR Readiness: `disabled`, `not_ready`, `ready`, `handoff_attempting`, `handoff_completed`, or `handoff_failed`.

For active Compozy Task Steps, tracker-facing dispatch state comes from the Compozy PRD Run lifecycle, not directly from the task-step `status` field. When lifecycle metadata is missing for a runnable Compozy PRD Run, backfill initializes `dispatch_state` from the configured dispatch start status when one exists, falling back to task-step-derived run state only for configurations without a dispatch start status. Sequential relaunches preserve the existing lifecycle dispatch state so the next Compozy Task Step stays in the same Stage Agent lane unless the Runtime Contract explicitly moves the run-level dispatch state.

Lifecycle metadata is persisted Runtime Home cache derived from Compozy Task Step files. Tracker polling repairs corrupt or partially written per-run lifecycle JSON by backfilling that Compozy PRD Run from task files. If repair fails, only that run is skipped; one bad lifecycle file must not abort discovery or dispatch for every Compozy PRD Run.

Batch Pull Request readiness requires successful Compozy PRD Run completion plus safe final integration and an enabling Pull Request Policy. Failed, skipped, blocked, or terminal Compozy Task Step progress does not imply Batch Pull Request readiness. In `batch` Pull Request Mode, Symphony may open or reuse at most one aggregate Batch Pull Request for the Compozy PRD Run and must not open per-step pull requests for Compozy Task Steps. `handoff_attempting` remains eligible for a later attempt so a restart after recording the attempt but before completing handoff can recover without manual lifecycle-file edits; `handoff_completed` remains terminal for aggregate handoff.

## Consequences

Operators can distinguish whole-run lifecycle from task-step execution progress without inspecting task files or implementation logs.

Runtime State, the Terminal Console, and the Web Dashboard can present the same run-level lifecycle, PR readiness, handoff status, and reason text while preserving older Compozy progress counts.

Runtime Home now contains persisted lifecycle metadata that may need reconciliation when Compozy Task Step files are edited manually. Reconciliation must prefer safe non-ready states over presenting failed, skipped, blocked, or stale terminal progress as PR-ready.

Documentation must use the glossary terms Compozy PRD Run, Compozy Task Step, Compozy PRD Run Lifecycle, Compozy PR Readiness, Pull Request Policy, and Batch Pull Request when explaining this behavior.
