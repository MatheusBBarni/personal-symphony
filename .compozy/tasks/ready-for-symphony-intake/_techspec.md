# Ready-for-Symphony Intake

## Executive Summary

This TechSpec adds a tracker-owned Symphony-ready status rule for first admission into orchestration without changing the existing polling loop, **Task Branch**, **Agent Worktree**, stage routing, retry flow, or **Ordered Queue** model. The core design extends the selected `Issue_tracker` boundary with a first-admission decision separate from the existing active and terminal status predicates. GitHub uses an exact configured ready status for first admission. Compozy reads a run-level ready status from `_tasks.md` while keeping `task_NN.md` frontmatter and **Compozy PRD Run Lifecycle** in their current roles.

The primary trade-off is deliberate: this design adds a small new tracker contract and a new runtime-state projection instead of reusing the broader `activeStates` set or filtering ad hoc in `Orchestrator`. That costs some interface churn, but it preserves boundary integrity, keeps queue semantics stable, and avoids breaking post-admission lifecycle behavior just to enforce a narrow first-admission rule.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Config` | Parse the shared Symphony-ready status setting and preserve existing tracker, project, and stage settings. | Must not break current GitHub or Compozy Runtime Settings loading. |
| `Issue_tracker` | Own first-admission eligibility at the selected tracker boundary. | `Orchestrator` should not implement tracker-specific ready-status logic itself. |
| `Github_tracker` | Read GitHub Project status, determine exact ready-status matches for first admission, and continue exposing tracker-visible issues. | Must preserve current GraphQL shape and status-field behavior. |
| `Compozy_tasks_tracker` | Parse `_tasks.md` run-level readiness, keep `task_NN.md` as task-step execution truth, and expose PRD-run eligibility inputs. | Must not replace task-step frontmatter or lifecycle metadata. |
| `Compozy_lifecycle` | Continue owning run-level execution and PR-readiness state after admission. | Must stay distinct from `_tasks.md` intake status. |
| `Runtime_readiness` / `Runtime_policy` | Allow startup with no ready work and keep structural readiness failures only. | “Nothing ready” is valid **Orchestration Idle**, not a readiness block. |
| `Orchestrator` | Poll tracker-visible issues, use tracker-owned first-admission decisions for dispatch, and keep queue and stage behavior intact. | Must not become the new source of tracker semantics. |
| `Runtime_state` / UI | Expose intake-eligibility explanations without changing the meaning of tracker status, queue state, or lifecycle state. | Frontend should render snapshot fields, not infer intake rules. |

Data flow:

1. Runtime loads `settings.json` and resolves the selected tracker plus the effective Symphony-ready status.
2. `Runtime_readiness` validates structure only: tracker config, GitHub connectivity, Compozy root and parseability.
3. The selected tracker fetches tracker-visible issues or runs.
4. The tracker adapter computes first-admission eligibility for each visible work item.
5. `Orchestrator` filters dispatch by tracker eligibility, running state, retry timing, stage capacity, and optional **Ordered Queue** membership.
6. `Runtime_state` projects candidate visibility plus intake explanations for terminal and dashboard consumers.
7. Existing post-admission lifecycle, retry, and completion logic continues unchanged.

## Implementation Design

### Core Interfaces

```go
type AdmissionDecision struct {
    Eligible bool
    Reason   string
}

type Tracker interface {
    FetchCandidates() ([]Issue, error)
    FirstAdmission(issue Issue) AdmissionDecision
    IsActive(status string) bool
    IsTerminal(status string) bool
}
```

```go
type CompozyReadySummary struct {
    ReadyStatus string
    Path        string
}

type IntakeEvaluation struct {
    IssueIdentifier string
    Eligible        bool
    Reason          string
}
```

### Data Models

#### Runtime Settings

Add a dedicated ready-status field to the shared tracker-facing project settings.

- Proposed effective config field: `project.readyStatus`
- Type: `string`
- Scope: selected tracker intake semantics
- Purpose: exact-match first-admission status for GitHub and expected ready value for Compozy `_tasks.md`
- Assumption for V1 draft: default effective value is `Ready for Symphony` until product wording is finalized

This field is separate from:

- `project.activeStates`: broader active or visible lifecycle states
- `project.terminalStates`: terminal lifecycle states
- `project.startStatus`, `reviewStatus`, `retryStatus`: stage transition targets

#### Tracker Admission Decision

Add a tracker-bound first-admission evaluation to avoid overloading `is_active`.

- `eligible: bool`
- `reason: string`
- Responsibility: explain exact first-admission result for one tracker-visible issue or run

#### Compozy Ready Summary

Add a minimal parser for `.compozy/tasks/<slug>/_tasks.md`.

- Source of truth: run-level intake status only
- Expected content: one run-level ready-status summary that can be compared to `project.readyStatus`
- Non-goals: task-step execution status, retry counters, failure metadata, PR-readiness metadata

#### Runtime State Projection

Add an optional intake-evaluation projection to `Runtime_state`.

- `issue_identifier: string`
- `eligible: bool`
- `reason: string option`

This keeps intake visibility separate from:

- `issues`: tracker-visible work items
- `ordered_queue`: queue state
- `compozy_progress`: Compozy lifecycle and task-step progress
- `issue_errors`: execution failures

### API Endpoints

No new HTTP endpoint is required.

Existing state endpoints should expose the new intake-evaluation projection:

| Method | Path | Change |
| --- | --- | --- |
| GET | `/api/v1/state` | Add optional intake-evaluation array keyed by issue identifier. |
| GET | `/api/v1/state/live` | Stream the same additional intake-evaluation fields. |

## Integration Points

| Integration Point | Design |
| --- | --- |
| GitHub GraphQL Project status | Continue using the configured single-select status field and compare its value to `project.readyStatus` for first admission. |
| Compozy `_tasks.md` | Add a narrow run-level parser for the ready status without changing `task_NN.md` parsing. |
| Existing queue validation | Queue entries remain subject to tracker first-admission eligibility before dispatch. |
| Existing stage routing | Post-admission stage behavior continues to use current transition and lifecycle semantics. |
| README and `CONTEXT.md` | Document **Symphony-ready Status** and its distinction from ordering and lifecycle state. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/config.ml` | modified | Add ready-status parsing and defaults; medium risk because config changes affect all tracker modes. | Add field parsing, validation, and tests. |
| `apps/backend/lib/issue_tracker.ml` | modified | Extend tracker contract with first-admission evaluation; medium risk because all adapters depend on this seam. | Add admission-decision type and adapter implementations. |
| `apps/backend/lib/github_tracker.ml` | modified | Add exact-match ready-status evaluation while preserving visible issue discovery; medium risk due to GitHub project-status assumptions. | Implement GitHub first-admission logic and tests. |
| `apps/backend/lib/compozy_tasks_tracker.ml` | modified | Parse `_tasks.md` ready status and expose run-level intake inputs; medium risk due to new file parsing path. | Add parser, deterministic errors, and tests. |
| `apps/backend/lib/compozy_lifecycle.ml` | modified | Keep lifecycle distinct from intake status and ensure reconciliation does not overwrite intake meaning; low to medium risk. | Update derivation or reconciliation only where needed. |
| `apps/backend/lib/runtime_readiness.ml` | modified | Stop treating “no runnable or ready work” as a readiness gap; high semantic risk because startup behavior changes. | Separate structural gaps from empty-idle state. |
| `apps/backend/lib/runtime_policy.ml` | modified | Preserve orchestrator start when there are zero ready items; low risk if readiness gaps are corrected upstream. | Keep policy aligned with new readiness semantics. |
| `apps/backend/lib/orchestrator.ml` | modified | Filter first admission through tracker eligibility while keeping queue and post-admission behavior stable; high risk because dispatch semantics live here. | Use tracker admission decisions in dispatch and state projection. |
| `apps/backend/lib/runtime_state.ml` | modified | Add intake-evaluation projection; medium risk due to API contract changes. | Extend JSON model and snapshot tests. |
| `apps/frontend/src/RuntimeStateSnapshot.res` | modified | Decode new intake-evaluation fields; low to medium risk. | Extend snapshot parser. |
| `apps/frontend/src/Pages/Dashboard.res` | modified | Render intake explanations without overloading lifecycle wording; low to medium risk. | Add tracker-neutral UI copy. |
| `apps/backend/test/test_backend.ml` | modified | Most behavior changes concentrate here; low structural risk, high verification importance. | Add focused unit and integration coverage. |
| `README.md` / `CONTEXT.md` / `docs/adr/0024-compozy-prd-run-lifecycle-semantics.md` | modified | Product semantics and Compozy lifecycle wording must stay coherent; medium documentation risk. | Update docs and ADR wording where semantics changed. |

## Testing Approach

### Unit Tests

- Config parsing accepts `project.readyStatus` and preserves existing defaults for unrelated fields.
- GitHub admission returns eligible only when project status exactly matches the configured ready status.
- GitHub visible-issue discovery still preserves terminal or already-managed visibility needed for ongoing lifecycle.
- Compozy `_tasks.md` parsing returns a deterministic ready-status summary or deterministic parse failure.
- Compozy first-admission logic requires both `_tasks.md` ready match and existing runnable-run conditions.
- Queue validation rejects first-admission attempts for non-ready items even when listed in `--queue`.
- Runtime readiness does not emit a gap when the tracker is structurally valid but nothing is ready.

### Integration Tests

- Startup with valid GitHub settings and zero ready issues enters **Orchestration Idle** rather than readiness-only mode.
- Startup with valid Compozy settings and zero ready runs enters **Orchestration Idle** rather than readiness-only mode.
- A GitHub issue moving into the configured ready status is dispatched on a later poll without restart.
- A Compozy run whose `_tasks.md` changes to the configured ready status is dispatched on a later poll without restart.
- A queued GitHub or Compozy item that is not ready remains pending and does not dispatch.
- Runtime State JSON exposes intake evaluations and frontend snapshot decoding remains compatible.
- Existing Compozy sequential step execution and lifecycle behavior remains unchanged after admission.

## Development Sequencing

### Build Order

1. Add `project.readyStatus` parsing and validation in `Config` and update docs for the new Runtime Settings field. No dependencies.
2. Extend `Issue_tracker` with a first-admission decision contract and update adapter signatures. Depends on step 1.
3. Implement GitHub exact-match first-admission logic using the configured ready status while preserving visible issue discovery. Depends on steps 1 and 2.
4. Add `_tasks.md` ready-status parsing and Compozy first-admission evaluation without changing task-step parsing. Depends on steps 1 and 2.
5. Update `Runtime_readiness` and `Runtime_policy` so structurally valid trackers can start in **Orchestration Idle** with zero ready work. Depends on steps 1, 3, and 4.
6. Update `Orchestrator` to use tracker admission decisions for first dispatch and queue admission checks while preserving post-admission behavior. Depends on steps 2, 3, 4, and 5.
7. Extend `Runtime_state` plus dashboard snapshot decoding and rendering for intake evaluations. Depends on step 6.
8. Add focused backend and frontend tests for config, tracker semantics, idle startup, queue interaction, and runtime-state projection. Depends on steps 3 through 7.
9. Update `README.md`, `CONTEXT.md`, and any affected ADR wording so the documented semantics match the implementation. Depends on steps 1, 5, and 7.

### Technical Dependencies

- GitHub project-status GraphQL queries must continue returning the configured status field reliably.
- Compozy `_tasks.md` needs a stable, documented run-level status format before implementation finalization.
- Existing Compozy lifecycle semantics in `docs/adr/0024-compozy-prd-run-lifecycle-semantics.md` may need wording updates to distinguish intake status from run lifecycle.
- Terminal and dashboard consumers depend on `Runtime_state` JSON compatibility and need synchronized snapshot updates.

## Monitoring and Observability

- Track count of tracker-visible items versus first-admission-eligible items per poll.
- Log ready-status mismatches with issue identifier, tracker kind, observed status, and configured ready status.
- Log `_tasks.md` parse failures with PRD-run identifier and file path.
- Surface structured runtime messages for:
  - `not_ready_status`
  - `queue_blocked_not_ready`
  - `idle_no_ready_work`
  - `compozy_ready_status_parse_failed`
- Alert only on structural tracker failures or repeated parse failures, not on ordinary idle-with-no-ready-work states.

## Technical Considerations

### Key Decisions

- Decision: add a dedicated tracker-owned first-admission contract instead of reusing `activeStates`.
  Rationale: first admission is narrower than general active or visible lifecycle semantics.
  Trade-off: introduces interface changes across all tracker adapters.
  Alternatives rejected: broad `activeStates` reuse, `Orchestrator`-local filtering.

- Decision: GitHub first admission requires exact configured ready-status match.
  Rationale: matches the selected product model and avoids ambiguous active-state behavior.
  Trade-off: stricter migration for existing projects.
  Alternatives rejected: broad active-state compatibility, mixed exact-or-legacy behavior.

- Decision: Compozy reads ready status from `_tasks.md` while keeping task-step and lifecycle state separate.
  Rationale: preserves a run-level local-tracker artifact without overloading execution files.
  Trade-off: introduces another parsed file and semantic boundary to maintain.
  Alternatives rejected: lifecycle-owned intake status, task-step-derived readiness.

- Decision: zero ready work is valid **Orchestration Idle** state, not a readiness failure.
  Rationale: supports always-on runtime behavior and restartless polling.
  Trade-off: startup readiness becomes structural-only rather than work-availability-driven.
  Alternatives rejected: blocking startup until ready work exists, readiness-gap-but-still-run hybrid behavior.

- Decision: `--queue` never bypasses the Symphony-ready rule for first admission.
  Rationale: preserves queue as ordering or selection, not forced eligibility override.
  Trade-off: queue users may need to update tracker status before dispatch.
  Alternatives rejected: queue override semantics, order-only-after-ready filtering that weakens admission guarantees.

### Known Risks

- The exact default ready-status string is still unresolved at the product level.
  Mitigation: wire the field as explicit config and keep the default as a documented assumption until finalized.

- GitHub fetch behavior may need to distinguish “visible for lifecycle” from “eligible for first admission.”
  Mitigation: keep those as separate adapter concepts and cover the distinction with integration tests.

- Compozy `_tasks.md` may drift from lifecycle or step status in operator mental models.
  Mitigation: keep `_tasks.md` intake-only, project intake evaluation separately in Runtime State, and update docs.

- Runtime State may still not fully explain all non-dispatchable cases if intake evaluation remains too narrow.
  Mitigation: start with first-admission explanations and expand only if dogfood feedback shows a real observability gap.

## Architecture Decision Records

- [ADR-001: Add explicit tracker-driven ready-for-symphony admission](./adrs/adr-001.md) — Initial marker-based idea direction, now superseded.
- [ADR-002: Use a standard Symphony-ready status convention across trackers](./adrs/adr-002.md) — Establishes the PRD’s status-driven intake model.
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](./adrs/adr-003.md) — Keeps ready-status logic in tracker adapters and preserves queue semantics.
- [ADR-004: Read Compozy Symphony-ready status from _tasks.md while keeping task-step state separate](./adrs/adr-004.md) — Uses `_tasks.md` as Compozy intake source without replacing task-step or lifecycle truth.
