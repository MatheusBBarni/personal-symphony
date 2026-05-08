# Claude Code Harness Integration TechSpec

## Executive Summary

Implement the PRD by splitting Runtime Settings execution concerns into three explicit layers: `harnesses` define execution backends, `agents` define logical agent execution selection, and `stageAgents` continue to route statuses to logical agents. The backend changes concentrate in `Config`, `Orchestrator`, `Runtime_state`, Bootstrap defaults, docs, and existing backend/frontend tests.

Primary trade-off: this is a breaking Runtime State and Runtime Contract cleanup rather than a compatibility-preserving alias layer. That increases migration strictness, but it removes the current ambiguity around `agents.*`, stage-level Harness overrides, and Codex-specific `codex_totals`.

## System Architecture

### Component Overview

| Component | Responsibility |
| --- | --- |
| `Config` | Parse `harnesses`, parse logical `agents`, resolve stage -> agent -> Harness, validate readiness. |
| `Runtime_home` | Bootstrap new Runtime Settings examples without overwriting existing Runtime Contract files. |
| `Orchestrator` | Render Harness commands, compose loop handoff, launch selected Harness, parse provider output. |
| `Runtime_state` | Expose `usage_totals`, selected Harness identity, and normalized live task activity. |
| Frontend live state | Consume renamed `usage_totals` and display selected Harness identity. |
| Docs / glossary | Update Runtime Contract language for Agent Harness, Claude Harness, logical agents, and loop configuration. |

Data flow:

1. `stageAgents.stages[].agent` selects a logical agent.
2. `agents.<name>.harness` selects a Harness.
3. Agent execution fields override Harness defaults field-by-field.
4. Orchestrator launches the resolved Harness command.
5. If stage `goal.enabled` is true and selected Harness loop is enabled, Orchestrator prepends `loop.command` with Stage Goal Context.
6. Runtime State exposes usage, Harness identity, and live messages/tool events.

## Implementation Design

### Core Interfaces

Actual implementation is OCaml. The Go struct below is a compact schema contract sketch required by the workflow.

```go
type Harness struct {
    Name   string
    Kind   string
    Command string
    Model  string
    ReasoningEffort string
    Loop struct {
        Enabled bool
        Command string
    }
}
```

```go
type Agent struct {
    Name string
    Harness string
    Model *string
    ReasoningEffort *string
    TurnTimeoutMs *int
    ReadTimeoutMs *int
    StallTimeoutMs *int
}
```

### Data Models

Extend `Config.agent_harness` with:

- `loop_enabled : bool`
- `loop_command : string`

Add a new logical agent model:

- `name : string`
- `harness : string`
- `model : string option`
- `reasoning_effort : string option`
- `turn_timeout_ms : int option`
- `read_timeout_ms : int option`
- `stall_timeout_ms : int option`

Resolved launch config remains a concrete `agent_harness`-like record after merging Harness defaults and agent overrides.

Runtime State changes:

- Rename `codex_totals` to `usage_totals`.
- Add selected Harness identity to running rows:
  - `harness_name`
  - `harness_kind`
- Normalize Claude `stream-json` activity into existing running-row activity fields where possible:
  - `last_event`
  - `last_message`
  - token usage totals

### API Endpoints

No new API endpoints.

Existing Runtime State HTTP and live connection snapshots change shape:

- Remove `codex_totals`.
- Add `usage_totals`.
- Add running row Harness fields.
- Preserve existing state delivery route and message model.

## Integration Points

| Integration | Design |
| --- | --- |
| Claude CLI | Use configured Claude Harness command with `stream-json`; parse structured output defensively. |
| Codex CLI | Keep command rendering and loop command support through `harnesses.codex.loop`. |
| PI CLI | Keep selected-Harness install/auth readiness checks, moved under `harnesses.pi`. |
| Runtime Contract | Read `.symphony/settings.json`; never write automatic migrations. |
| Secrets | Continue referencing environment variable names only. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/config.ml` | Modified | Main schema migration and readiness risk. | Add `harnesses`, logical `agents`, merge rules, Claude kind, legacy diagnostics. |
| `apps/backend/lib/orchestrator.ml` | Modified | Loop and stream parsing changes affect dispatch. | Replace hard-coded `/goal`, parse Claude stream events, store Harness identity. |
| `apps/backend/lib/runtime_state.ml` | Modified | Breaking JSON rename. | Rename `codex_totals` to `usage_totals`, add Harness fields. |
| `apps/frontend/src/Main.res` | Modified | Type and snapshot shape break. | Update ReScript types and token display mapping. |
| `apps/frontend/test/liveState.test.mjs` | Modified | Snapshot fixtures break. | Update expected state shape. |
| `apps/backend/lib/runtime_home.ml` | Modified | Bootstrap examples change. | Add `harnesses` and logical `agents` defaults idempotently. |
| `README.md`, `CONTEXT.md`, ADRs | Modified | Product language change. | Update glossary, examples, migration notes. |
| `apps/backend/test/test_backend.ml` | Modified | Large shared suite. | Add targeted cases near existing Harness tests. |

## Testing Approach

### Unit Tests

- Parse `harnesses.codex`, `harnesses.claude`, and `harnesses.pi`.
- Parse logical `agents.planner/engineer/reviewer`.
- Verify agent override merge over Harness defaults.
- Verify `stageAgents.stages[].harness` is rejected as legacy migration input.
- Verify legacy harness-shaped `agents.*` produces readiness remediation.
- Verify `claude` is an allowed Harness kind.
- Verify `usage_totals` JSON replaces `codex_totals`.
- Verify Claude stream-json parser handles message, tool, and usage events defensively.

### Integration Tests

- Dispatch a stage routed to a logical agent that resolves to Codex.
- Dispatch a stage routed to a logical agent that resolves to Claude.
- Verify `goal.enabled` plus Codex loop prepends `/goal`.
- Verify `goal.enabled` plus Claude loop disabled runs the normal prompt.
- Verify running Runtime State includes `harness_name` and `harness_kind`.
- Verify frontend live-state tests consume `usage_totals`.

## Development Sequencing

### Build Order

1. Add `Config` data models for Harness loop and logical agents - no dependencies.
2. Add parser support for `harnesses` and logical `agents` - depends on step 1.
3. Add Harness/default plus agent override resolution - depends on step 2.
4. Add readiness diagnostics for legacy `agents.*` and stage-level `harness` - depends on step 3.
5. Update Orchestrator loop composition to use selected Harness loop settings - depends on step 3.
6. Add Claude Harness command/readiness and stream-json parsing - depends on steps 3 and 5.
7. Rename Runtime State `codex_totals` to `usage_totals` and add Harness identity - depends on step 6.
8. Update frontend types/tests for Runtime State shape - depends on step 7.
9. Update Bootstrap defaults and documentation - depends on steps 2 through 7.
10. Add targeted backend/frontend tests and run verification - depends on steps 1 through 9.

### Technical Dependencies

- Claude CLI must be available on `PATH` for real dispatch validation.
- Existing backend tests remain in `apps/backend/test/test_backend.ml`; do not split the file.
- ReScript source changes must be made in `.res` files only.

## Monitoring and Observability

- Runtime State should expose selected Harness name and kind for running tasks.
- Runtime State should expose provider-neutral `usage_totals`.
- Readiness gaps should identify exact legacy settings paths and remediation.
- Claude stream parsing should leave raw stdout/stderr logs intact for diagnostics.
- Unsupported or disabled loop handoff should be observable through launch diagnostics when practical.

## Technical Considerations

### Key Decisions

- Decision: `stageAgents.stages[].agent` resolves to `agents.<name>`, which resolves to `harnesses.<name>`.
  Rationale: keeps stage routing, logical agent configuration, and execution backend definitions separate.
  Trade-off: stage-level Harness overrides become migration errors.

- Decision: Agent fields override Harness defaults field-by-field.
  Rationale: avoids repetitive settings while allowing role-specific model/timeouts.
  Trade-off: resolved values require merge logic.

- Decision: `goal.enabled` remains stage-level, but selected Harness loop controls actual handoff.
  Rationale: operators can test agents/models without editing stage settings.
  Trade-off: loop handoff can silently skip when Harness loop is disabled.

- Decision: Rename `codex_totals` to `usage_totals` immediately.
  Rationale: mixed-Harness Runtime State should not keep Codex-specific naming.
  Trade-off: frontend and snapshot consumers must update in the same change.

- Decision: Parse Claude live messages and tool events into Runtime State.
  Rationale: operators need visibility into Claude-selected work.
  Trade-off: provider-specific output parsing must be defensive.

### Known Risks

- Legacy Runtime Contracts may block dispatch until migrated.
  Mitigation: precise readiness messages with before/after examples.

- Claude `stream-json` event shape may change.
  Mitigation: ignore unknown events, keep raw logs, and test representative fixtures.

- Runtime State rename may break consumers.
  Mitigation: update frontend and tests atomically.

- Silent loop skip may hide missing goal handoff.
  Mitigation: expose loop status in launch diagnostics where practical.

## Architecture Decision Records

- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Defines `harnesses`, logical `agents`, explicit Harness loop configuration, and Claude `stream-json`.
- [ADR-002: Clarity-First PRD Scope](adrs/adr-002.md) — Selects configuration clarity and blocking readiness migration as the product approach.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Defines stage -> agent -> Harness resolution, override merging, and stage-gated Harness loop behavior.
- [ADR-004: Provider-Neutral Runtime State and Claude Stream Events](adrs/adr-004.md) — Renames usage totals and defines Claude live event normalization.
