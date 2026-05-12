# TechSpec: Improve Compozy Task Lifecycle Statuses

## Executive Summary

This implementation adds a dispatch-aware Compozy PRD Run lifecycle layer while preserving existing Compozy Task Step progress. The lifecycle layer lives under Runtime Home `.symphony/state/`, feeds Stage Agent dispatch and readiness decisions, and surfaces through the existing `Runtime_state.compozy_progress` object so Terminal Console, HTTP/WebSocket Runtime State, and the Web Dashboard stay aligned.

The primary technical trade-off is adding a second persistence source for Compozy runs. Compozy Task Step frontmatter remains authoritative for step progress and current-step selection, while Runtime Home lifecycle metadata becomes authoritative for run-level lifecycle, dispatch state, PR readiness, and concise operator reasons. This avoids runtime churn in `.compozy/tasks/<slug>/` files but requires reconciliation to prevent stale Runtime Home state after manual task-file edits or restarts.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Compozy_lifecycle` (new backend module) | Own run-level lifecycle metadata, JSON persistence under Runtime Home, lazy backfill, reconciliation, transition helpers, and PR readiness summaries. | Does not parse task files directly except through `Compozy_tasks_tracker.prd_run` inputs. |
| `Compozy_tasks_tracker` | Continue parsing Compozy Task Step files, deriving step counts, current step, and prompt context. | Task-step progress remains `pending`, `in_progress`, `completed`, `failed`, and `skipped`. |
| `Issue_tracker.compozy` | Fetch Compozy PRD Runs, apply lifecycle metadata to issue state for dispatch, and persist status updates through `Compozy_lifecycle`. | Does not call GitHub APIs. |
| `Orchestrator` | Update lifecycle during dispatch, retry, failure, final completion, Task Branch Integration attention, and Batch Pull Request handoff. | Current-step selection stays in Compozy task-step logic. |
| `Runtime_state` | Extend `compozy_progress` with lifecycle, dispatch, readiness, reason, stage, and handoff summary fields. | Older snapshots without lifecycle fields remain compatible. |
| Terminal Console (`apps/backend/bin/main.ml`) | Render lifecycle and PR readiness alongside current Compozy Task Step progress. | No new CLI mode. |
| HTTP/WebSocket server | Continue serving `/api/v1/state` and live snapshots with the extended Runtime State payload. | No new endpoint. |
| Frontend ReScript Dashboard | Parse extended `compozy_progress` and render lifecycle/readiness in the existing PRD run progress panel. | Edit `.res` sources only. |
| Docs and glossary | Explain lifecycle vs task-step progress and update domain language if new terms are introduced. | No secrets or local `.env` contents. |

### Data Flow

1. Compozy discovery loads Compozy PRD Runs through `Compozy_tasks_tracker.discover_prd_runs`.
2. `Compozy_lifecycle` loads or lazily backfills lifecycle metadata from Runtime Home for each discovered run.
3. `Issue_tracker.compozy` returns issue candidates whose dispatch state comes from lifecycle metadata when present, falling back to task-step-derived state when metadata is absent.
4. `Orchestrator.dispatch_issue` updates lifecycle with the selected Stage Agent phase before launch.
5. Completion, retry, failure, attention, and PR handoff paths update lifecycle state and PR readiness reason.
6. `Runtime_state.compozy_progress_of_prd_run` combines task-step progress with lifecycle metadata.
7. Terminal Console, HTTP/WebSocket snapshots, and Web Dashboard render the same lifecycle and readiness values.

## Implementation Design

### Core Interfaces

The implementation will use OCaml records and functions, but this Go struct documents the cross-component JSON contract that Runtime State and frontend consumers depend on:

```go
type CompozyLifecycle struct {
    RunID          string  `json:"run_id"`
    Slug           string  `json:"slug"`
    LifecycleState string  `json:"lifecycle_state"`
    DispatchState  string  `json:"dispatch_state"`
    StageAgent     *string `json:"stage_agent,omitempty"`
    PRReadiness    string  `json:"pr_readiness"`
    Reason         *string `json:"reason,omitempty"`
    UpdatedAt      string  `json:"updated_at"`
}
```

Backend module contract:

- `Compozy_lifecycle.path_for_run : Config.t -> Compozy_tasks_tracker.prd_run -> string`
- `Compozy_lifecycle.load : Config.t -> Compozy_tasks_tracker.prd_run -> (t option, string) result`
- `Compozy_lifecycle.backfill : Config.t -> Compozy_tasks_tracker.prd_run -> (t, string) result`
- `Compozy_lifecycle.save : Config.t -> t -> (unit, string) result`
- `Compozy_lifecycle.for_runtime : Config.t -> Runtime_state.t -> Compozy_tasks_tracker.prd_run -> (t, string) result`
- `Compozy_lifecycle.mark_stage_started : Config.t -> run -> stage_agent:string option -> dispatch_state:string -> (t, string) result`
- `Compozy_lifecycle.mark_not_pr_ready : Config.t -> run -> reason:string -> (t, string) result`
- `Compozy_lifecycle.mark_pr_handoff : Config.t -> run -> status:string -> reason:string option -> (t, string) result`

All functions return `(value, string) result` to match existing backend error handling. The implementation should keep function names small and idiomatic; exact OCaml signatures may differ as long as the contracts remain.

### Data Models

#### Runtime Home lifecycle JSON

Storage path:

```text
.symphony/state/compozy-lifecycle/<slug>.json
```

Persisted JSON shape:

```json
{
  "version": 1,
  "run_id": "compozy:improve-compozy-task-statuses",
  "slug": "improve-compozy-task-statuses",
  "lifecycle_state": "in_execution",
  "dispatch_state": "In progress",
  "stage_agent": "engineer",
  "pr_readiness": "not_ready",
  "reason": null,
  "updated_at": "2026-05-12T21:00:00Z"
}
```

Allowed `lifecycle_state` values:

| Value | Meaning |
| --- | --- |
| `pending` | Run exists and has not entered active work. |
| `in_planning` | Planner Stage Agent work is active or selected. |
| `in_execution` | Engineering or task-step execution work is active. |
| `in_review` | Reviewer Stage Agent work is active or selected. |
| `blocked` | Run requires operator attention before dispatch should continue. |
| `completed` | Run completed successfully from the lifecycle perspective. |
| `failed` | Run ended with failed task-step or orchestration outcome. |
| `skipped` | Run ended with skipped work and is not PR-ready. |
| `pr_handoff` | Batch Pull Request handoff is attempting, completed, or failed. |
| `not_pr_ready` | Run is stopped or terminal but cannot open a Batch Pull Request. |

Allowed `pr_readiness` values:

| Value | Meaning |
| --- | --- |
| `disabled` | Pull Request Policy does not enable automatic Batch Pull Requests. |
| `not_ready` | Run is not eligible for a Batch Pull Request. |
| `ready` | Run completed successfully and is eligible for one aggregate Batch Pull Request. |
| `handoff_attempting` | Batch Pull Request handoff is in progress. |
| `handoff_completed` | Batch Pull Request handoff completed or reused an existing PR. |
| `handoff_failed` | Batch Pull Request handoff failed and may be retryable. |

`dispatch_state` is the state string used for Stage Agent routing and tracker active/terminal checks. It may use existing configured statuses such as `Backlog`, `To-Do`, `In progress`, `In review`, or `Done`. `lifecycle_state` is the user-facing run category exposed in Runtime State.

#### Extended `Runtime_state.compozy_progress`

Add optional fields to the existing record and JSON output:

- `lifecycle_state : string option`
- `dispatch_state : string option`
- `stage_agent : string option`
- `pr_readiness : string option`
- `reason : string option`
- `handoff_status : string option`

Existing fields remain unchanged:

- `run_id`
- `slug`
- `current_step`
- `completed`
- `failed`
- `skipped`
- `total`

Parsing older Runtime State snapshots must treat missing lifecycle fields as compatible absence.

#### Lazy backfill rules

When lifecycle metadata is missing:

| Compozy Task Step condition | Backfilled lifecycle | Backfilled readiness |
| --- | --- | --- |
| Current step exists with `pending` or `in_progress` | `in_execution` | `not_ready` |
| All steps completed | `completed` | `ready` if policy allows and integration is safe, otherwise `disabled` or `not_ready` with reason |
| Any failed step and no current runnable step | `failed` | `not_ready` with failed-step reason |
| Any skipped step and no current runnable step | `skipped` | `not_ready` with skipped-step reason |
| No valid task steps | `blocked` or `not_pr_ready` | `not_ready` with not-runnable reason |

Task-step progress remains authoritative for current step and counts. Lifecycle reconciliation may downgrade stale `ready` or `completed` metadata to `not_pr_ready`, `failed`, or `skipped` when task files show failed/skipped terminal progress.

### API Endpoints

No new endpoint is required.

Existing surfaces change through Runtime State payloads:

| Surface | Existing entry point | Change |
| --- | --- | --- |
| HTTP | `GET /api/v1/state` | `compozy_progress` includes optional lifecycle fields. |
| WebSocket/live state | Existing state snapshot broadcast | Broadcasts the same extended `compozy_progress` object. |
| Terminal Console | Existing startup/status rendering | Prints lifecycle state, PR readiness, and reason when present. |
| Web Dashboard | Existing Runtime State snapshot parser | Parses and renders lifecycle/readiness fields. |

## Integration Points

No new external service integration is required.

Existing boundaries preserved:

- GitHub API remains unnecessary for Compozy-backed Local Issue Tracker status visibility.
- Batch Pull Request creation continues to use the existing Pull Request Policy and `gh` handoff path when configured.
- Protected Trunk Branch and Batch Branch Push behavior remain unchanged.
- Runtime Home files remain ignored runtime metadata and must not include secrets.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/compozy_lifecycle.ml` | New | Encapsulates lifecycle persistence and reconciliation. Risk: stale metadata if reconciliation is incomplete. | Add module, JSON parsing/writing, lazy backfill, and transition helpers. |
| `apps/backend/lib/compozy_tasks_tracker.ml` | Modified | May need helper functions for deriving lifecycle from `prd_run` without changing task-step semantics. Risk: accidentally changing current-step behavior. | Keep existing status counts stable; add only lifecycle-safe helpers if needed. |
| `apps/backend/lib/issue_tracker.ml` | Modified | Compozy adapter must stop treating status updates as no-op and use lifecycle dispatch state for candidates. Risk: routing regressions. | Integrate `Compozy_lifecycle` load/backfill/save in `compozy` adapter. |
| `apps/backend/lib/orchestrator.ml` | Modified | Dispatch, retry, completion, attention, integration, and PR handoff paths must update lifecycle. Risk: scattered transition writes. | Centralize transition calls through `Compozy_lifecycle` helpers. |
| `apps/backend/lib/runtime_state.ml` | Modified | `compozy_progress` gains optional lifecycle fields. Risk: snapshot compatibility. | Keep optional parsing defaults and JSON compatibility tests. |
| `apps/backend/bin/main.ml` | Modified | Terminal Console prints lifecycle/readiness. Risk: noisy output. | Add compact lines under PRD Run Progress. |
| `apps/frontend/src/RuntimeStateSnapshot.res` | Modified | Parse new optional fields. Risk: ReScript build break. | Edit `.res` only and rebuild generated JS through build command. |
| `apps/frontend/src/Pages/Dashboard.res` | Modified | Render lifecycle/readiness in PRD run progress panel. Risk: confusing copy. | Keep copy short and separate lifecycle from counts. |
| `README.md` and `CONTEXT.md` | Modified | Document lifecycle and any new glossary terms. Risk: documentation drift. | Update Compozy-backed tracker docs and glossary language as needed. |
| `apps/backend/test/test_backend.ml` | Modified | Large test suite gains focused Compozy lifecycle cases. Risk: broad fixture churn. | Add targeted tests near existing Compozy cases; do not split file. |

## Testing Approach

### Unit Tests

Backend unit coverage:

- `Compozy_lifecycle` JSON round-trip for version 1 metadata.
- Missing optional fields remain compatible.
- Lazy backfill for pending/in-progress, completed, failed, skipped, empty, and not-runnable PRD Runs.
- Reconciliation downgrades stale lifecycle metadata when task-step progress shows failed or skipped terminal state.
- `Runtime_state.compozy_progress_of_prd_run` includes optional lifecycle fields when metadata exists and omits them safely when absent.
- `Runtime_state.compozy_progress_from_snapshot_yojson` handles older snapshots.

Frontend unit/live-state coverage:

- Runtime State snapshot parsing accepts lifecycle fields.
- Runtime State snapshot parsing accepts older snapshots without lifecycle fields.
- Dashboard displays lifecycle state, PR readiness, and reason without hiding current-step counts.

### Integration Tests

Backend integration coverage in `apps/backend/test/test_backend.ml`:

- Compozy tracker lazy-backfills lifecycle on discovery when no Runtime Home metadata exists.
- Compozy tracker `update_status` persists dispatch-aware lifecycle metadata.
- Dispatch to planner maps to `in_planning` when the selected Stage Agent is planner.
- Dispatch to engineer maps to `in_execution` while preserving task-step `in_progress` updates.
- Dispatch to reviewer maps to `in_review` when the selected Stage Agent is reviewer.
- Final successful Compozy PRD Run marks lifecycle `completed` and PR readiness `ready` or `disabled` based on Pull Request Policy.
- Failed/skipped terminal runs mark lifecycle `failed`/`skipped` and `pr_readiness = not_ready` with reason.
- Merge attention and protected-path attention mark lifecycle `blocked` or `not_pr_ready` with reason.
- Batch Pull Request handoff mirrors `handoff_attempting`, `handoff_completed`, and `handoff_failed` readiness while preserving existing `pull_request` records.
- Batch mode never opens per-step pull requests for Compozy Task Steps.

Verification commands:

- `pnpm test`
- `pnpm frontend:test`
- `pnpm frontend:build` after ReScript changes
- `pnpm backend:build` if backend module wiring changes are broad

## Development Sequencing

### Build Order

1. Define `Compozy_lifecycle` data model and Runtime Home storage helpers — no dependencies.
2. Add lifecycle lazy-backfill and reconciliation helpers — depends on step 1.
3. Extend `Runtime_state.compozy_progress` and JSON parsing/output with optional lifecycle fields — depends on step 1.
4. Wire `Issue_tracker.compozy` to load/backfill lifecycle and persist status updates — depends on steps 1, 2, and 3.
5. Add dispatch-aware lifecycle updates in `Orchestrator.dispatch_issue` — depends on step 4.
6. Add lifecycle updates for retry, failed step, final completion, blocked, and merge-attention paths — depends on step 5.
7. Mirror Batch Pull Request readiness and handoff status into lifecycle — depends on step 6.
8. Update Terminal Console Compozy PRD Run Progress rendering — depends on step 3 and step 7.
9. Update frontend Runtime State parsing and Web Dashboard PRD run progress panel — depends on step 3 and step 7.
10. Add focused backend tests for lifecycle storage, dispatch, failure, and PR readiness — depends on steps 4, 5, 6, and 7.
11. Add frontend snapshot/render tests — depends on step 9.
12. Update README, CONTEXT glossary language, and examples — depends on steps 8 and 9.
13. Run verification commands and fix root causes — depends on steps 10, 11, and 12.

### Technical Dependencies

- No new third-party packages are required.
- Runtime Home `.symphony/state/` must remain writable in the Workspace Repository.
- Existing `yojson` support is sufficient for lifecycle metadata.
- Existing ReScript/Vite frontend build pipeline remains the frontend path.
- Existing `gh`-based Batch Pull Request handoff remains the pull-request path when policy enables it.

## Monitoring and Observability

Runtime visibility:

- `Runtime_state.compozy_progress.lifecycle_state`
- `Runtime_state.compozy_progress.pr_readiness`
- `Runtime_state.compozy_progress.reason`
- Existing `Runtime_state.pull_request` and `pull_requests` records
- Existing `Runtime_state.task_branch_integrations` attention records
- Existing `Runtime_state.last_error`

Terminal Console should print compact lifecycle lines under `PRD Run Progress`:

- `Lifecycle`
- `Dispatch state`
- `Stage agent` when known
- `PR readiness`
- `Reason` when present

Dashboard should show the same fields in the PRD run progress panel without replacing step-count metrics.

No alerting thresholds are required for V1. Lifecycle state is local operator observability, not an external monitoring system.

## Technical Considerations

### Key Decisions

- **Decision:** Store lifecycle metadata under Runtime Home `.symphony/state/compozy-lifecycle/`.
  - **Rationale:** Lifecycle is ignored runtime metadata, not user-authored Compozy Task Step content.
  - **Trade-off:** Runtime Home state can drift from manually edited task files.
  - **Alternatives rejected:** task-step frontmatter expansion, PRD-run sidecar file, pure derivation.

- **Decision:** Make lifecycle dispatch-aware but keep task-step progress authoritative for current-step selection.
  - **Rationale:** The user selected dispatch-aware lifecycle, while ADR-001 preserves Compozy Task Step semantics.
  - **Trade-off:** The system must reconcile dispatch state and step state carefully.
  - **Alternatives rejected:** observational-only lifecycle, lifecycle as the sole current-step source.

- **Decision:** Extend `compozy_progress` instead of adding a new top-level Runtime State object.
  - **Rationale:** Current consumers already treat Compozy progress as the selected run summary.
  - **Trade-off:** `compozy_progress` becomes broader than pure step counts.
  - **Alternatives rejected:** separate `compozy_lifecycle`, issue-row-only lifecycle fields.

- **Decision:** Mirror PR readiness into lifecycle while keeping detailed handoff records in existing pull-request fields.
  - **Rationale:** Operators need a run-level answer, and existing handoff records already contain details.
  - **Trade-off:** Readiness is summarized in two places.
  - **Alternatives rejected:** duplicate full handoff details, keep PR readiness separate from lifecycle.

### Known Risks

- **Stale Runtime Home lifecycle:** Manual task-file edits may make lifecycle metadata stale.
  - **Mitigation:** Reconcile lifecycle from Compozy Task Step progress on discovery and polling.

- **Dispatch regression:** Using lifecycle dispatch state may alter which Stage Agent runs.
  - **Mitigation:** Add tests for planner, engineer, and reviewer dispatch and keep task-step status as current-step authority.

- **Snapshot compatibility regression:** Older Runtime State snapshots lack lifecycle fields.
  - **Mitigation:** Keep fields optional in OCaml and ReScript parsers.

- **PR readiness ambiguity:** Completed task steps may still be interpreted as PR-ready.
  - **Mitigation:** Store `pr_readiness` separately and require reason text for `not_ready` or failed handoff.

- **Frontend generated-file churn:** ReScript changes generate ignored `.res.js` files.
  - **Mitigation:** Edit `.res` sources only and run the frontend build command without committing generated files.

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle status belongs to the Compozy PRD Run, while Compozy Task Step statuses remain execution progress.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — V1 exposes lifecycle and PR readiness across Runtime State, Terminal Console, and Web Dashboard.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Runtime Home stores dispatch-aware lifecycle metadata, and `compozy_progress` exposes lifecycle and PR readiness fields.
