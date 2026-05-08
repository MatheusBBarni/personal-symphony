---
title: Compozy Tasks Run Integration
version: 1.0
date_created: 2026-05-08
last_updated: 2026-05-08
owner: Product Repository maintainers
tags: [architecture, runtime-contract, tracker, compozy, task-run]
---

# Compozy Tasks Run Integration

## Executive Summary

This TechSpec defines a narrow Compozy-backed tracker path that lets Personal Symphony treat `.compozy/tasks/<task_name>/` as one PRD-run work item while executing its `task_NN.md` files sequentially in the same Agent Worktree and Task Branch. Each task-step prompt includes the current task file plus `_prd.md` and `_techspec.md` when present.

The primary trade-off is intentional: V1 avoids the cleaner shared `Issue_tracker` abstraction and instead adds a contained Compozy-specific path beside the existing GitHub path. This validates PRD-run execution faster, but accepts some duplicated tracker behavior that should be revisited if Compozy and minibeads local tracking are unified later.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Config` | Parse `tracker.kind = "compozy_tasks"` and Compozy tracker settings. | Preserve GitHub defaults and avoid changing Bootstrap defaults. |
| `Compozy_tasks_tracker` | Discover PRD-run directories, parse task files, update task frontmatter, and build current task-step issue context. | Reads and writes only under `.compozy/tasks/<task_name>/`. |
| `Orchestrator` Compozy path | Launch task steps sequentially in the same Agent Worktree and Task Branch. | Final Stage Commit, Stage Push, and Task Branch Integration happen only after PRD-run completion. |
| `Runtime_state` | Project tracker kind and Compozy PRD-run progress to terminal and Web Dashboard consumers. | Existing state shape remains compatible when fields are absent. |
| `Ordered_queue` and `Manual_merge` | Keep GitHub behavior unchanged; support Compozy PRD-run identifiers only where V1 explicitly needs tracker replacement confidence. | Avoid broad selected-tracker refactor in V1. |
| Frontend Runtime State parsing | Display tracker-neutral wording and PRD-run progress when present. | No full project-management UI. |

### Data Flow

1. Runtime Settings select `tracker.kind = "compozy_tasks"`.
2. Compozy readiness checks confirm `.compozy/tasks/<task_name>/` candidates and task files are valid.
3. The Compozy tracker path maps one PRD directory to one `Issue.t` with a stable PRD-run identifier.
4. Orchestrator creates or reuses the Agent Worktree and Task Branch for that PRD run.
5. The current pending task file is rendered into a task-step prompt with `_prd.md` and `_techspec.md`.
6. On successful task-step completion, Symphony updates that `task_NN.md` frontmatter and relaunches the next task step in the same worktree.
7. On task-step failure, Symphony retries until `tracker.compozy.maxTaskStepRetries` is reached, then marks that step failed/skipped and advances.
8. After no runnable task steps remain, Symphony applies final PRD-run completion behavior.

## Implementation Design

### Core Interfaces

```ocaml
type task_step = {
  file : string;
  title : string;
  status : string;
  retry_count : int;
  index : int;
}

type prd_run = {
  id : string;
  slug : string;
  path : string;
  title : string;
  state : string;
  current_step : task_step option;
  steps : task_step list;
}
```

```ocaml
module Compozy_tasks_tracker : sig
  val fetch_prd_runs : Config.t -> prd_run list
  val issue_of_prd_run : prd_run -> Issue.t
  val current_prompt : prd_run -> (string, string) result
  val mark_step_started : Config.t -> prd_run -> task_step -> (unit, string) result
  val mark_step_finished : Config.t -> prd_run -> task_step -> (unit, string) result
  val mark_step_failed : Config.t -> prd_run -> task_step -> (unit, string) result
end
```

### Data Models

#### Runtime Settings

```json
{
  "tracker": {
    "kind": "compozy_tasks",
    "compozy": {
      "root": ".compozy/tasks",
      "maxTaskStepRetries": 2
    }
  }
}
```

Fields:

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `tracker.kind` | string | `github` | Accept `github` and `compozy_tasks` in V1. |
| `tracker.compozy.root` | string | `.compozy/tasks` | Relative to Workspace Repository root. |
| `tracker.compozy.maxTaskStepRetries` | int | `2` | Number of retries per task step before advancing. |

#### PRD-Run Identifier

Use canonical identifiers of the form `compozy:<task_name>`.

Examples:
- `.compozy/tasks/compozy-tasks-run-integration/` -> `compozy:compozy-tasks-run-integration`
- `.compozy/tasks/minibeads-local-issue-tracker/` -> `compozy:minibeads-local-issue-tracker`

The Task Branch/workspace key must not rely on the current numeric extraction behavior in `issue_branch_key`. The Compozy path should derive a sanitized stable branch key from the full identifier or slug.

#### Task-Step Frontmatter

Existing task files already use frontmatter such as:

```yaml
status: pending
title: "Add tracker kind config and minibeads settings"
type: backend
complexity: medium
dependencies: []
```

V1 adds or updates:

```yaml
status: in_progress
symphony_retry_count: 1
symphony_last_error: "agent exited with code 1"
```

Allowed task-step statuses:
- `pending`
- `in_progress`
- `completed`
- `failed`
- `skipped`

#### Runtime State Projection

Add optional fields:

```json
{
  "tracker_kind": "compozy_tasks",
  "compozy_progress": {
    "run_id": "compozy:compozy-tasks-run-integration",
    "slug": "compozy-tasks-run-integration",
    "current_step": "task_02.md",
    "completed": 1,
    "failed": 0,
    "skipped": 0,
    "total": 8
  }
}
```

The fields are optional so existing clients continue to parse older state.

### API Endpoints

No new HTTP endpoint is required for V1.

Existing endpoints continue to serve full Runtime State snapshots:

| Method | Path | Change |
| --- | --- | --- |
| GET | `/api/v1/state` | Includes optional `tracker_kind` and `compozy_progress`. |
| GET | `/api/v1/state/live` | Streams snapshots with the same optional fields. |

## Integration Points

### Compozy Artifacts

The integration reads and writes local files under `.compozy/tasks/<task_name>/`.

Required files:
- `task_NN.md`: at least one runnable task file.
- `_prd.md`: included in prompts when present.
- `_techspec.md`: included in prompts when present.

Optional files:
- `_tasks.md`: may help validate task order, but V1 can sort task files by numeric suffix.
- `adrs/*.md`: optional prompt context only if already included by the task file or future extension.

### Git

The feature reuses existing Agent Worktree and Task Branch behavior. Intermediate task-step completion must not trigger final integration. Final PRD-run completion uses the existing final Stage Commit, Stage Push, and Task Branch Integration path.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/config.ml` | modified | Currently rejects non-GitHub tracker kinds and always expects GitHub fields. | Accept `compozy_tasks`, parse Compozy settings, skip GitHub-only readiness gaps for Compozy. |
| `apps/backend/lib/compozy_tasks_tracker.ml` | new | Owns file discovery, frontmatter parsing, task-step prompts, and task file status writes. | Add module with testable file I/O boundaries. |
| `apps/backend/lib/orchestrator.ml` | modified | Current completion assumes one issue run maps to final completion. | Add Compozy intermediate completion/next-step relaunch path. |
| `apps/backend/lib/runtime_state.ml` | modified | No tracker kind or task-step progress fields today. | Add optional tracker/progress projection and JSON parsing. |
| `apps/backend/lib/ordered_queue.ml` | modified | Numeric GitHub selectors only. | Accept `compozy:<task_name>` if Compozy queue support is included in V1. |
| `apps/backend/lib/manual_merge.ml` | modified | Numeric GitHub selectors and `Github_tracker.project_issue` only. | Keep GitHub path unchanged; add Compozy merge validation only if final PRD-run branches need manual merge by identifier. |
| `apps/backend/bin/main.ml` | modified | Readiness and run wiring are GitHub-specific. | Route Compozy tracker kind to Compozy run path. |
| `apps/frontend/src/RuntimeStateSnapshot.res` | modified | Runtime State type lacks tracker/progress fields. | Parse optional fields. |
| `apps/frontend/src/Pages/Dashboard.res` | modified | Copy is GitHub/project-specific. | Use tracker-neutral wording and show compact PRD-run progress. |
| `apps/backend/test/test_backend.ml` | modified | Large existing suite with tracker/orchestrator coverage. | Add focused tests near related config, queue, runtime state, and orchestrator cases. |

## Testing Approach

### Unit Tests

- Config parses omitted `tracker.kind` as GitHub.
- Config parses `tracker.kind = "compozy_tasks"` with default and explicit Compozy settings.
- Compozy tracker rejects task directories outside the configured root.
- Compozy tracker parses `task_NN.md` files in numeric order.
- Compozy tracker preserves task body while updating frontmatter.
- Compozy tracker builds a task-step prompt containing the current task file, `_prd.md`, and `_techspec.md`.
- Runtime State serializes optional tracker kind and Compozy progress.

### Integration Tests

- Compozy tracker run does not require GitHub owner, repo, project number, or token.
- One PRD run launches the first pending task in a new Agent Worktree.
- Successful first task updates frontmatter and relaunches the next task in the same worktree and branch.
- A failing task retries until `maxTaskStepRetries`, then marks the task failed/skipped and advances.
- Final PRD-run completion triggers existing final completion behavior only after task steps are exhausted.
- GitHub tracker config, readiness, Ordered Queue, Manual Task Merge, and orchestrator tests continue to pass.

## Development Sequencing

### Build Order

1. Add Compozy tracker config parsing - no dependencies.
2. Add Compozy task file parser and frontmatter updater - depends on step 1.
3. Add PRD-run discovery and `Issue.t` mapping - depends on step 2.
4. Add task-step prompt assembly - depends on step 3.
5. Add Runtime State tracker/progress projection - depends on step 3.
6. Add Compozy run wiring in `main.ml` and readiness behavior - depends on steps 1, 3, and 5.
7. Add Orchestrator intermediate task-step completion path - depends on steps 3, 4, and 6.
8. Add retry-limit behavior and failed-over-limit advancement - depends on step 7.
9. Add compact dashboard/terminal progress rendering - depends on step 5.
10. Add optional Ordered Queue and Manual Task Merge identifier support for `compozy:<task_name>` - depends on steps 3 and 7.
11. Update documentation and examples - depends on steps 1 through 10.
12. Run focused backend/frontend verification - depends on steps 1 through 11.

### Technical Dependencies

- Existing OCaml backend and Alcotest suite.
- Existing ReScript frontend Runtime State parsing.
- No new external service dependency.
- No package or Bootstrap default changes.

## Monitoring and Observability

- Log selected tracker kind at startup.
- Log Compozy PRD-run identifier, current task file, retry count, and status transition.
- Runtime State should expose the current PRD run, current task step, total task count, completed count, failed count, skipped count, and attention state.
- Status update failures should include the PRD-run identifier and task filename, with sanitized error text.

## Technical Considerations

### Key Decisions

- Decision: Use a narrow Compozy-specific path instead of a full shared tracker abstraction.
  - Rationale: It matches the selected V1 scope and avoids blocking PRD-run execution on a broader refactor.
  - Trade-off: Duplicated tracker behavior may need consolidation later.
  - Alternatives rejected: Shared `Issue_tracker` boundary and in-memory override.
- Decision: Persist task-step progress in task file frontmatter.
  - Rationale: Compozy task files are the tracker artifacts for this workflow.
  - Trade-off: Symphony mutates repository-owned task files during execution.
  - Alternatives rejected: `.symphony/state/` only and hybrid persistence.
- Decision: Sequentially relaunch task steps in the same worktree.
  - Rationale: Gives visible step progress while preserving PRD-run continuity.
  - Trade-off: Requires an intermediate completion path before final branch integration.
  - Alternatives rejected: single long prompt and `compozy tasks run` delegation.
- Decision: Add `tracker.compozy.maxTaskStepRetries`.
  - Rationale: The retry limit is specific to task-step progression.
  - Trade-off: Continuing after failures can produce partial PRD-run completion.

### Known Risks

- Early branch cleanup or integration: mitigate by separating intermediate step completion from final PRD-run completion.
- Task file write conflicts: mitigate with scoped frontmatter updates and clear attention errors when the file changed unexpectedly.
- Hidden skipped work: mitigate by surfacing failed/skipped task counts in Runtime State and terminal output.
- GitHub regression: mitigate with existing GitHub tracker and orchestrator tests.
- Future local tracker divergence: document the Compozy path as a V1 compromise and keep module boundaries explicit.

## Architecture Decision Records

- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — V1 uses Compozy task files through an opt-in Local Issue Tracker adapter instead of a direct special path.
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — V1 presents `.compozy/tasks/<task_name>/` as one work item whose task files run in the same worktree.
- [ADR-003: Add a narrow Compozy tracker path](adrs/adr-003.md) — V1 chooses a contained Compozy-specific path instead of a full shared tracker abstraction.
- [ADR-004: Persist task-step progress in Compozy task files](adrs/adr-004.md) — Task file frontmatter is the authoritative task-step progress store.
- [ADR-005: Relaunch task steps sequentially in one worktree](adrs/adr-005.md) — Each task step launches separately while preserving one Agent Worktree and Task Branch.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Compozy task-step retry limits live under Compozy tracker Runtime Settings.
