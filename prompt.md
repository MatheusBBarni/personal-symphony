You are the Engineer agent for the Symphony Orchestrator Repository.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Responsibilities:
- Implement only the scoped issue.
- Use CONTEXT.md terms and follow AGENTS.md.
- Prefer existing module boundaries and tests over new abstractions.
- Preserve Runtime Contract semantics unless the issue explicitly asks to change them.
- Do not touch protected release/package paths unless the issue explicitly authorizes that scope.
- Edit ReScript .res sources only; never commit generated .res.js files.
- Keep examples secret-free and refer only to GITHUB_TOKEN or GH_TOKEN variable names.
- Run focused verification, then broader checks when shared orchestration/config/runtime behavior changes.

Stage Commit is enabled for this stage. Leave the worktree ready for a local commit boundary before review.

---

Stage agent: engineer

# Compozy Task Step

Run: compozy:ready-for-symphony-intake
PRD directory: ready-for-symphony-intake
Current task file: task_05.md
Current task title: Expose intake eligibility in Runtime State and dashboard

## Current Task (`task_05.md`)

---
status: in_progress
title: "Expose intake eligibility in Runtime State and dashboard"
type: frontend
complexity: high
dependencies:
  - task_04

---

# Task 05: Expose intake eligibility in Runtime State and dashboard

## Overview
Expose first-admission eligibility and blocking reasons through Runtime State so operators can tell why a work item will start, is waiting, or will not start. This task must keep intake explanations tracker-neutral and additive to existing Runtime State snapshots rather than replacing lifecycle, queue, or Compozy progress projections.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add a Runtime State projection for first-admission eligibility keyed to tracker-visible work items.
- R2 MUST surface tracker-neutral reasons for ready, not-ready, queue-blocked, or parse-blocked intake states without rewriting lifecycle semantics.
- R3 MUST keep frontend state decoding and dashboard rendering compatible with existing Runtime State snapshots.
- R4 MUST preserve Ordered Queue and Compozy progress views while adding intake-specific operator visibility.
- R5 MUST include backend and frontend test coverage for state serialization, snapshot decoding, and dashboard rendering of intake eligibility.
</requirements>

## Subtasks
- [ ] 5.1 Add intake-eligibility projection fields to Runtime State serialization and live state output.
- [ ] 5.2 Update frontend Runtime State decoding to understand the new intake-eligibility shape.
- [ ] 5.3 Render tracker-neutral intake explanations in dashboard state views without collapsing existing lifecycle or queue status.
- [ ] 5.4 Extend backend and frontend tests for state projection and UI rendering compatibility.

## Implementation Details
Reference the TechSpec "API Endpoints", "Runtime State Projection", and "Monitoring and Observability" sections. Keep this task focused on state projection and operator visibility; it should not change tracker semantics, queue policy, or run lifecycle ownership introduced by earlier tasks.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` - Runtime State model and JSON projection that should gain intake-eligibility fields.
- `apps/backend/lib/server.ml` - State API endpoints that must expose the new projection consistently.
- `apps/frontend/src/RuntimeStateSnapshot.res` - Frontend decoder for Runtime State snapshots.
- `apps/frontend/src/Pages/Dashboard.res` - Web Dashboard rendering of runtime status and tracker-facing explanations.
- `apps/backend/test/test_backend.ml` - Backend state snapshot tests to extend with the new fields.

### Dependent Files
- `apps/backend/bin/terminal_console_runtime.ml` - Terminal Console consumers may reuse the new intake-eligibility messages.
- `apps/backend/lib/terminal_console_model.ml` - Shared console projection may need the same intake-eligibility view as the dashboard.
- `apps/frontend/src` - Other snapshot consumers may need decoding compatibility if they read shared Runtime State types.
- `README.md` - Later docs task will explain new operator-facing intake diagnostics.

### Related ADRs
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Requires runtime visibility for first-admission rules.
- [ADR-004: Read Compozy Symphony-ready status from _tasks.md while keeping task-step state separate](adrs/adr-004.md) - Intake visibility must not blur Compozy lifecycle and task-step semantics.

## Deliverables
- Runtime State projection for intake eligibility and blocking reasons.
- Frontend decoding and dashboard rendering for tracker-neutral intake explanations.
- Backend and frontend tests covering serialization, snapshot compatibility, and UI rendering.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for state and dashboard behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Runtime State JSON includes intake-eligibility fields for ready and non-ready tracker-visible items.
  - [ ] Frontend Runtime State snapshot decoding accepts the new fields without breaking existing snapshots.
  - [ ] Dashboard rendering distinguishes intake-blocked items from terminal or lifecycle-completed items.
- Integration tests:
  - [ ] Live state output shows queue-blocked or not-ready reasons while preserving Ordered Queue progress.
  - [ ] Compozy runs with ready-status parse failures surface intake-specific explanations without replacing Compozy PRD Run progress rendering.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can see why tracker-visible work is ready, blocked, or excluded from first admission.
- Runtime State and dashboard consumers gain intake visibility without regressing existing queue or lifecycle views.

## PRD (`_prd.md`)

# PRD: Ready-for-Symphony Intake

## Overview

Symphony should automatically start newly eligible work from the selected **Issue Tracker** in a **Workspace Repository** without requiring the operator to restart the running process. The MVP uses a standard Symphony-ready status convention as the visible control for when work should begin.

This feature is for self-hosting engineers and small teams who keep Symphony running on a VPS or other long-lived environment. It is valuable because it removes restart friction, makes start timing predictable, and gives GitHub-backed and Compozy-backed workflows one shared product model.

## Goals

- Let Symphony start newly eligible work within one polling interval without restart.
- Make tracker status the primary user-visible control for when work starts.
- Give GitHub-backed and Compozy-backed workflows one consistent Symphony-ready concept.
- Preserve confidence in existing **Task Branch**, **Agent Worktree**, stage, retry, and **Ordered Queue** behavior.
- Keep “no ready work yet” as valid **Orchestration Idle** state rather than a failure condition.

## User Stories

- As a solo self-hosting engineer, I want Symphony to notice newly ready work automatically so that I can leave it running without babysitting restarts.
- As a small-team operator, I want one clear Symphony-ready status so that everyone can predict when work will start.
- As a GitHub-backed operator, I want tracker status to control intake so that I do not need a second readiness mechanism.
- As a Compozy-backed operator, I want local tracked work to follow the same Symphony-ready concept so that the product feels consistent across trackers.
- As an operator who uses `--queue` occasionally, I want routine work to start from status alone while keeping queue-based ordering for exceptions.

## Core Features

| # | Feature | Priority | Product Requirement |
| --- | --- | --- | --- |
| F1 | Standard Symphony-ready status | Critical | Symphony defines one standard ready status concept that means work is eligible to start automatically. |
| F2 | Cross-tracker consistency | Critical | The same Symphony-ready concept applies to both the **GitHub Tracker** and the Compozy-backed **Local Issue Tracker**. |
| F3 | Automatic start without restart | Critical | When a work item reaches the Symphony-ready status and capacity is available, Symphony starts it on a later polling cycle without restart. |
| F4 | Healthy idle behavior | Critical | When no work item is in the Symphony-ready status, Symphony remains in valid **Orchestration Idle** state. |
| F5 | Status-first operator control | High | Operators use tracker status as the main visible control for start timing instead of separate readiness markers. |
| F6 | Queue compatibility | High | `--queue` remains available for exceptional ordering and does not disappear from the product model. |
| F7 | Start-behavior visibility | High | Runtime feedback explains why a work item will start, is waiting, or will not start even when operators believe it is ready. |

## User Experience

A typical operator keeps Symphony running in a **Workspace Repository** while planning and refining work in the selected tracker. When a work item reaches the Symphony-ready status, the operator does not need to restart the process or rebuild routine intake commands. Symphony notices the newly eligible item on a later poll and starts work if capacity and normal dispatch rules allow it.

For day-to-day use, the core experience is predictability. Operators should be able to look at tracker status and understand whether Symphony will pick something up soon, whether it is intentionally idle, or whether another rule is holding work back. This matters most for always-on usage, where the product should feel like a dependable intake loop rather than a command that must be re-triggered manually.

For exceptional cases, operators can still use explicit queue ordering. The MVP should make routine work feel automatic while preserving deliberate control for special sequencing needs.

## High-Level Technical Constraints

- Preserve one selected **Issue Tracker** per **Workspace Repository**.
- Preserve existing **Task Branch**, **Agent Worktree**, stage, retry, and completion behavior after work starts.
- Preserve the distinction between status-based eligibility and queue-based ordering.
- Keep GitHub-backed and Compozy-backed workflows aligned under the same product language.
- Do not require operators to maintain a separate readiness marker for routine intake.

## Non-Goals

- Replacing `--queue` with a fully automatic prioritization system.
- Supporting multiple trackers at the same time in one **Workspace Repository**.
- Adding a second explicit readiness marker beside tracker status.
- Introducing dynamic prioritization, scheduling policies, or auto-ordering in the MVP.
- Changing in-flight work behavior based on new status edits after work has already started.
- Building a broader dashboard control plane as part of this MVP.

## Phased Rollout Plan

### MVP (Phase 1)

- Define a standard Symphony-ready status concept.
- Use tracker status as the main visible control for automatic start.
- Start newly eligible work within one polling interval without restart.
- Treat no ready work as valid **Orchestration Idle** state.
- Preserve `--queue` for exceptional ordering.

Success criteria: operators can leave Symphony running and see newly ready work start automatically without restart.

### Phase 2

- Improve operator-facing explanations for why a work item is waiting or not dispatchable.
- Add clearer project guidance for adopting the Symphony-ready convention across trackers.
- Improve confidence for teams mixing routine automatic intake with occasional queue-based ordering.

Success criteria: operators report that start behavior is predictable from tracker status alone.

### Phase 3

- Add product guidance and reporting around intake quality, routine throughput, and exceptions.
- Explore higher-level workflow improvements that build on the status-driven intake model without collapsing it into a hidden queue system.

Success criteria: Symphony-ready status becomes the default mental model for routine intake across supported trackers.

## Success Metrics

| Metric | Target |
| --- | --- |
| Ready-to-start latency | 90% of newly eligible work starts within one polling interval when capacity is available |
| Restart avoidance | 95% reduction in restart-required admissions for routine work |
| Routine queue avoidance | Most routine intake no longer requires `--queue`, while exceptions still can use it |
| Predictability | Operators can correctly predict start behavior from tracker status in dogfood validation |
| False-positive starts | Fewer than 1 unintended start per 100 Symphony-ready work items |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Teams resist adopting a Symphony-ready status convention | Allow the product concept to stay stable while providing project-level compatibility guidance |
| Operators expect status to control ordering as well as eligibility | Keep `--queue` as a distinct concept and explain that status controls start eligibility, not sequence |
| Mixed tracker habits create confusion about what “ready” means | Use one shared Symphony-ready product concept across trackers |
| Operators lose trust if a ready-looking item does not start | Improve runtime explanations for waiting, blocking, and non-dispatchable cases |
| Teams overuse the ready status and flood intake | Keep routine intake simple and rely on normal capacity limits plus queue controls for exceptional cases |

## Architecture Decision Records

- [ADR-001: Add explicit tracker-driven ready-for-symphony admission](./adrs/adr-001.md) — Initial idea-phase marker-based admission direction, later superseded.
- [ADR-002: Use a standard Symphony-ready status convention across trackers](./adrs/adr-002.md) — The PRD decision: tracker status becomes the primary intake control.

## Open Questions

- What exact user-facing status wording should Symphony standardize on for the ready state?
- How should Runtime State explain cases where a Symphony-ready item is still not dispatchable because of other existing rules?
- How much project-level compatibility should the MVP allow before the cross-tracker product story becomes too weak?

## TechSpec (`_techspec.md`)

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

