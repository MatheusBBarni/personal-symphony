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

Run: compozy:built-in-agent-looper
PRD directory: built-in-agent-looper
Current task file: task_11.md
Current task title: Update operator docs examples and final validation coverage

## Current Task (`task_11.md`)

---
status: in_progress
title: "Update operator docs examples and final validation coverage"
type: docs
complexity: medium
dependencies:
  - task_03
  - task_08
  - task_09
  - task_10

---

# Task 11: Update operator docs examples and final validation coverage

## Overview
This task completes the feature documentation and verification story after backend and UI behavior are implemented. It documents Goal Loop configuration, evidence command behavior, Runtime State visibility, operator outcomes, and the boundaries that preserve existing delivery semantics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST document Goal Loop settings, evidence command contract, stop outcomes, and Runtime State fields.
- REQ-02 MUST update Bootstrap or example settings only if implementation explicitly accepted those defaults.
- REQ-03 MUST document that Goal Loop does not own Stage Commit, Stage Push, merge, PR, auto-merge, or status authority.
- REQ-04 MUST update repo docs/tests for Terminal Console and Web Dashboard visibility.
- REQ-05 MUST run the final verification set appropriate for backend, frontend, docs, and task validation.
</requirements>

## Subtasks
- [ ] 11.1 Update README and relevant docs for Goal Loop operator behavior.
- [ ] 11.2 Update Runtime Settings examples and secret-free evidence command examples.
- [ ] 11.3 Update `CONTEXT.md` if implementation changed final terms after task_01.
- [ ] 11.4 Add final docs/test assertions for operator-facing semantics.
- [ ] 11.5 Run full validation and record any remaining gaps.

## Implementation Details
Use the TechSpec "Monitoring and Observability" and "Development Sequencing" sections. This task should not introduce new runtime behavior except documentation-driven tests or fixture updates required to keep docs accurate.

### Relevant Files
- `README.md` — primary operator docs for Symphony runtime behavior.
- `CONTEXT.md` — domain source of truth.
- `docs/adr/` — contains repo-level decisions for runtime semantics.
- `apps/backend/test/test_backend.ml` — documentation and runtime behavior assertions.
- `apps/frontend/test/liveState.test.mjs` — final dashboard snapshot coverage.
- `.compozy/tasks/built-in-agent-looper/_tasks.md` — task bundle master list for validation.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — examples must remain idempotent and secret-free.
- `apps/backend/lib/config.ml` — docs must match actual settings.
- `apps/backend/lib/runtime_state.ml` — docs must match actual Runtime State fields.
- `apps/backend/bin/terminal_console_tui.ml` and `apps/frontend/src/Pages/Dashboard.res` — docs must match actual operator surfaces.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Defines scope and lifecycle boundaries.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Defines evidence-first product behavior.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Defines state and config scope.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Defines evidence gate and retry/attention behavior.

## Deliverables
- Updated operator documentation for Goal Loop.
- Updated docs tests or assertions.
- Secret-free examples for evidence command configuration.
- Final verification notes for backend, frontend, docs, and task validation.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests across backend/frontend/docs validation **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Docs assertions confirm Goal Loop terms and lifecycle boundaries.
  - [ ] Runtime Settings examples are secret-free and parse correctly.
  - [ ] Documentation mentions deterministic evidence for `Goal met`.
- Integration tests:
  - [ ] `pnpm test` passes for backend and docs assertions.
  - [ ] `pnpm frontend:test` passes for dashboard/live-state changes.
  - [ ] `pnpm frontend:build` passes after ReScript changes.
  - [ ] `pnpm backend:build` passes after backend changes.
  - [ ] `compozy tasks validate --name built-in-agent-looper` passes for this bundle.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operator docs match implemented behavior.
- Goal Loop examples are secret-free and idempotent.
- Task validation passes for the generated bundle.

## PRD (`_prd.md`)

# Built-In Agent Looper PRD

## Overview

Personal Symphony should add an evidence-first **Goal Loop** that lets a maintainer supervise agent work with higher trust and less manual continuation. A maintainer should be able to see what goal an agent is pursuing, why the loop continued, what evidence supports completion, and why the loop stopped.

V1 focuses on trust and visibility. A loop may stop as **Goal met** only when deterministic evidence supports that outcome. Ambiguous, blocked, or unverifiable work stops as **Needs attention** with clear guidance. Budget exhaustion stops predictably and visibly.

## Goals

- Let maintainers trust loop outcomes across multiple **Stage Agents** in a **Workspace Repository**.
- Make **Goal met** an evidence-backed stop outcome, not an agent confidence claim.
- Reduce manual "continue working" nudges while preserving operator control.
- Expose loop goal, status, stop reason, latest evidence, and next action through existing operator surfaces.
- Preserve existing lifecycle boundaries for status transitions, Stage Commit, Stage Push, merge, PR, and delivery behavior.

## User Stories

- As a maintainer, I want to see the active goal for each looped task so that I know what the agent is trying to complete.
- As a maintainer, I want **Goal met** to require visible deterministic evidence so that I can trust completed loop outcomes.
- As a maintainer, I want blocked or ambiguous loops to stop as **Needs attention** so that I can intervene with the missing decision or context.
- As a maintainer, I want budget exhaustion to be explicit so that long-running loops do not silently burn time or usage.
- As a maintainer, I want the same loop status in Runtime State, Terminal Console, and Web Dashboard so that I do not reconcile conflicting views.

## Core Features

| Feature | Priority | Requirement |
|---|---|---|
| Goal Loop status | Critical | Show the current loop goal, state, attempt count, stop budget, latest evidence, and next action. |
| Evidence-backed completion | Critical | Allow **Goal met** only when deterministic evidence is present for the claimed completion. |
| Attention stop outcome | Critical | Stop ambiguous, blocked, or missing-evidence work as **Needs attention** with a concise reason. |
| Budget stop outcome | Critical | Stop predictably when configured time, turn, or usage limits are exhausted. |
| Shared operator visibility | High | Present the same authoritative loop status through existing operator surfaces. |
| Lifecycle boundary protection | High | Keep delivery behavior under existing Symphony rules; the loop does not gain commit, push, merge, PR, or status authority. |
| Future recipe readiness | Medium | Preserve product language that can later support named reusable loop recipes without expanding V1 scope. |

## User Experience

A maintainer starts or observes a task using a loop-capable stage. The operator surface shows the active goal and current loop state. During execution, the maintainer can see whether the loop is still working, what changed recently, and what evidence is available.

When the loop stops, the outcome is one of three primary user-facing states:

- **Goal met**: deterministic evidence supports the completion claim.
- **Needs attention**: the loop is blocked, ambiguous, or missing required evidence.
- **Budget exhausted**: time, turn, or usage limits stopped the loop.

The maintainer should never need to infer whether "done" means verified, guessed, or merely claimed.

## High-Level Technical Constraints

- Must preserve established Symphony domain language and update `CONTEXT.md` when final terms are accepted.
- Must remain Workspace Repository scoped.
- Must not expose secrets, token values, local environment contents, or full hidden prompts in operator-facing evidence.
- Must not change existing Stage Commit, Stage Push, merge, PR, auto-merge, or status-transition behavior in V1.
- Must coexist with current **Stage Goal Handoff**, **Harness Loop**, **Goal Usage**, **Runtime State**, **Terminal Console**, and **Web Dashboard** semantics.

## Non-Goals (Out of Scope)

- Full autonomous delivery authority.
- Independent completion review after agent exit.
- Multi-goal orchestration.
- Recipe marketplace or broad loop configuration UI.
- Provider-specific global lifecycle hooks.
- Qualitative-only completion claims counted as **Goal met** in V1.

## Phased Rollout Plan

### MVP (Phase 1)

- Define evidence-first Goal Loop product behavior.
- Show active goal, loop state, stop outcome, latest evidence, budget status, and next action.
- Support **Goal met**, **Needs attention**, and **Budget exhausted** as clear stop outcomes.
- Preserve all existing delivery lifecycle rules.

### Phase 2

- Add reusable loop recipes once V1 proves maintainers trust the loop state.
- Improve dashboard and console summaries for historical loop outcomes.
- Add richer attention categorization for missing evidence, blocked dependency, and budget exhaustion.

### Phase 3

- Explore cross-harness loop behavior and broader workflow reuse.
- Consider independent completion review only through a separate ADR and PRD.
- Add aggregate loop reliability and cost trend reporting.

## Success Metrics

| Metric | Target |
|---|---:|
| Stop explanation coverage | >= 90% of stopped loops include outcome, reason, latest evidence, and next action. |
| Evidence-backed success | 100% of **Goal met** outcomes include deterministic evidence. |
| Manual continuation reduction | >= 50% fewer maintainer continuation nudges on loop-enabled tasks. |
| Attention clarity | >= 80% of **Needs attention** outcomes identify the missing evidence, blocker, or decision. |
| Lifecycle boundary violations | 0 loop-driven commit, push, merge, PR, or status changes outside existing rules. |

## Risks and Mitigations

- **False completion**: Require deterministic evidence for **Goal met**.
- **Operator fatigue from attention outcomes**: Make attention reasons concise and actionable.
- **Reduced automation feel**: Position V1 as trust-first; completion without evidence is not a success.
- **Scope creep into platform features**: Defer recipes, multi-goal orchestration, and completion review.
- **Confusing overlap with Stage Goal Handoff**: Define Goal Loop as the user-facing loop outcome model, while Stage Goal Handoff remains launch-time behavior.

## Architecture Decision Records

- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Accepts a narrow Goal Loop V1 with platform-shaped Runtime contracts.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Selects evidence-backed completion as the PRD approach.

## Open Questions

- What final domain term should be accepted in `CONTEXT.md`: **Goal Loop**, **Agent Loop Run**, or another term?
- Should V1 expose loop history beyond the latest stop outcome?
- Which user-facing evidence categories should count as deterministic for the first release?
- Should budget settings be described as per stage, per agent role, or per loop run in the next TechSpec?

## TechSpec (`_techspec.md`)

# Built-In Agent Looper TechSpec

## Executive Summary

Implement an evidence-first **Goal Loop** as Runtime-owned state, not as a provider prompt wrapper. The core architecture adds a pure backend `Goal_loop` domain module, stage-scoped Goal Loop settings, persisted `.symphony/state/goal-loops/*.json` state, Runtime State projection, and existing Terminal Console/Web Dashboard rendering.

The primary trade-off is stricter completion gating: Goal Loop-enabled stages may not enter existing completion behavior after agent exit `0` until a deterministic evidence command succeeds. Missing or failed evidence retries the task using the existing retry budget, then moves to Human Attention.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
|---|---|---|
| `Goal_loop` domain module | Types and pure transition logic for loop state, budgets, evidence, and stop outcomes | No Git, tracker, server, or UI calls |
| Stage Agent config | Opt-in Goal Loop settings and evidence command contract | Does not overload Harness Loop or Goal Usage |
| Orchestrator integration | Create/update Goal Loop state at dispatch, run evidence gate on exit `0`, route retry/attention/completion | Existing completion path remains downstream |
| Runtime State | Authoritative top-level `goal_loops` projection plus row summaries when useful | Existing `/api/v1/state` and live stream continue |
| Runtime Home persistence | Store canonical loop state under `.symphony/state/goal-loops/*.json` | Private, bounded, secret-free |
| Terminal Console | Render current/terminal Goal Loop state near Goal Usage and Context Status | Read-only |
| Web Dashboard | Render Goal Loop card near existing task execution details | Reads Runtime State only |

## Implementation Design

### Core Interfaces

```go
type GoalLoopState struct {
  IssueID        string `json:"issue_id"`
  RunID          string `json:"run_id"`
  Goal           string `json:"goal"`
  State          string `json:"state"`
  AttemptCount   int    `json:"attempt_count"`
  StopOutcome    string `json:"stop_outcome,omitempty"`
  StopReason     string `json:"stop_reason,omitempty"`
  LatestEvidence string `json:"latest_evidence,omitempty"`
  NextAction     string `json:"next_action,omitempty"`
  UpdatedAt      string `json:"updated_at"`
}
```

The implementation is OCaml/ReasonML, but the exported Runtime State JSON should follow this stable contract.

### Data Models

Add a Goal Loop state model with these fields:

| Field | Type | Notes |
|---|---|---|
| `issue_id` | string | Stable issue identifier used by Runtime State |
| `issue_identifier` | string | Human-readable identifier |
| `run_id` | string | Stable loop run id |
| `goal` | string | Bounded text from Stage Goal Context or configured goal source |
| `state` | enum | `running`, `retrying`, `goal_met`, `needs_attention`, `budget_exhausted` |
| `stage_agent` | string option | Stage Agent name |
| `harness_name` | string option | Selected Harness name |
| `harness_kind` | string option | Selected Harness kind |
| `attempt_count` | int | Existing attempt count plus Goal Loop attempts |
| `budget` | object | Max turns/time/usage configured for the loop |
| `latest_evidence` | string option | Bounded evidence summary |
| `stop_outcome` | enum option | `goal_met`, `needs_attention`, `budget_exhausted` |
| `stop_reason` | string option | Bounded reason |
| `next_action` | string option | Operator or retry guidance |
| `diagnostics_path` | string option | Private Runtime Diagnostics file path |
| `updated_at` | string | ISO timestamp |

Persist one JSON file per active or recently stopped loop under `.symphony/state/goal-loops/`.

### API Endpoints

No new endpoint is required.

Extend the existing Runtime State JSON returned by `GET /api/v1/state` and streamed by the Live Dashboard Connection:

```json
{
  "goal_loops": [
    {
      "issue_id": "I1",
      "issue_identifier": "#1",
      "run_id": "goal-loop-I1-...",
      "goal": "Evidence-backed completion for task #1",
      "state": "goal_met",
      "attempt_count": 2,
      "stop_outcome": "goal_met",
      "latest_evidence": "Verification command passed.",
      "next_action": null
    }
  ]
}
```

## Integration Points

| Area | Integration |
|---|---|
| `apps/backend/lib/config.ml` | Add stage-scoped Goal Loop config with evidence command, budgets, timeout, and max output bytes. |
| `apps/backend/lib/orchestrator.ml` | Gate agent exit `0` before `mark_completed`; update Goal Loop state through dispatch, retry, attention, and completion. |
| `apps/backend/lib/runtime_state.ml` | Add `goal_loop` types, JSON serialization, and top-level projection. |
| `apps/backend/lib/terminal_console_model.ml` | Sanitize and project Goal Loop state for rows/details. |
| `apps/backend/bin/terminal_console_tui.ml` | Render Goal Loop details in task panels. |
| `apps/frontend/src/RuntimeStateSnapshot.res` | Add snapshot types and mapping for `goal_loops`. |
| `apps/frontend/src/Pages/Dashboard.res` | Render Goal Loop status near Goal Usage and Context Status. |
| `CONTEXT.md` | Add accepted Goal Loop terminology and avoid-list language. |
| `docs/adr/` | Add product architecture ADR before implementation because runtime semantics change. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|---|---|---|---|
| `config.ml` | Modified | New stage config can create readiness gaps if invalid | Add parsing and validation tests |
| `runtime_home.ml` | Modified | Bootstrap examples must remain idempotent and not overwrite user files | Add defaults only if accepted for missing files |
| `orchestrator.ml` | Modified | Completion gating is high-risk | Add focused tests around exit `0`, evidence fail, retry, and attention |
| `runtime_state.ml` | Modified | JSON contract changes | Add backwards-compatible serialization tests |
| Terminal Console | Modified | Read-only display changes | Add projection/rendering tests |
| Frontend dashboard | Modified | Snapshot mapping/rendering changes | Add live-state tests |
| `CONTEXT.md` | Modified | New domain language | Update glossary and tests that assert docs language |

## Testing Approach

### Unit Tests

- Goal Loop transition tests for running, evidence success, evidence failure, retry, attention, and budget exhaustion.
- Config parsing tests for enabled/disabled Goal Loop, invalid evidence command, invalid budget, and missing command.
- Runtime State serialization tests for `goal_loops` and old snapshots without loop state.
- Evidence command input/output tests using temp scripts.

### Integration Tests

- Agent exit `0` plus passing evidence command proceeds to existing completion.
- Agent exit `0` plus failing evidence command retries with missing-evidence guidance.
- Evidence failure after retry exhaustion moves to Human Attention before Stage Commit/status changes.
- Runtime State HTTP and websocket snapshots include Goal Loop state.
- Terminal Console and Web Dashboard render the same loop state.

## Development Sequencing

### Build Order

1. Add `Goal_loop` domain module and tests - no dependencies.
2. Add stage-scoped config parsing and readiness validation - depends on step 1.
3. Add Runtime Home persistence for `.symphony/state/goal-loops/*.json` - depends on step 1.
4. Extend Runtime State JSON with top-level `goal_loops` - depends on steps 1 and 3.
5. Add evidence command runner using Context Command conventions - depends on steps 1 and 2.
6. Gate orchestrator exit `0` completion path with evidence evaluation - depends on steps 2, 3, and 5.
7. Add retry guidance and Human Attention routing for evidence failures - depends on step 6.
8. Render Goal Loop in Terminal Console - depends on step 4.
9. Render Goal Loop in Web Dashboard - depends on step 4.
10. Update `CONTEXT.md`, README/docs, and repo ADR - depends on settled behavior from steps 1-9.

### Technical Dependencies

- Existing Runtime State snapshot delivery.
- Existing Agent Worktree execution boundary.
- Existing retry budget and Human Attention status.
- Existing Context Command conventions for structured input and bounded output.

## Monitoring and Observability

- Runtime State fields: loop state, stop outcome, stop reason, latest evidence, next action, attempt count, updated timestamp.
- Diagnostics: evidence command duration, exit code, timeout flag, stdout/stderr byte counts, truncation flags.
- Operator thresholds: any `needs_attention` or `budget_exhausted` state should be visible in Terminal Console and Web Dashboard.
- No secret values, local environment contents, or full hidden prompts should be stored in Goal Loop state.

## Technical Considerations

### Key Decisions

- **Decision:** Stage Agent owns Goal Loop config.
  **Rationale:** Goal Loop is workflow-stage behavior, not a Harness capability.
  **Trade-off:** More stage config surface.

- **Decision:** Persist canonical state under `.symphony/state/goal-loops/*.json`.
  **Rationale:** Successful `goal_met` outcomes need retained visibility after active rows clear.
  **Trade-off:** More persistence and pruning work.

- **Decision:** Require evidence command success before completion.
  **Rationale:** Agent exit `0` is not deterministic proof.
  **Trade-off:** Misconfigured evidence commands can increase retries and attention.

- **Decision:** Reuse Context Command input conventions.
  **Rationale:** Existing structured input, temp-file env var, timeout, and diagnostics patterns fit the evidence command.
  **Trade-off:** Evidence command semantics must be documented separately from Context Command.

### Known Risks

- Evidence command becomes too strict and blocks useful qualitative work. Mitigation: stop qualitative work as Human Attention in V1.
- Goal Loop state drifts from orchestrator lifecycle. Mitigation: all transitions go through `Goal_loop` helpers and are projected into Runtime State.
- UI surfaces diverge. Mitigation: both read the same Runtime State JSON.
- Existing Stage Goal Handoff terminology confuses operators. Mitigation: `CONTEXT.md` must distinguish Goal Loop from Harness Loop and Stage Goal Handoff.

## Architecture Decision Records

- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Accepts a narrow Goal Loop V1 with platform-shaped Runtime contracts.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Selects evidence-backed completion as the PRD approach.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Chooses Stage Agent config plus persisted top-level Runtime State as the canonical loop model.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Requires an evidence command before Goal Loop completion can enter the existing completion path.

