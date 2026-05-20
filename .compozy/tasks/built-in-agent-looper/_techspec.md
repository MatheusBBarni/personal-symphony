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
