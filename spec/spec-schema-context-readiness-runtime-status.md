---
title: Context Readiness And Runtime Status Schema
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [schema, runtime-state, dashboard, agent-context, issue-41]
---

# Introduction

This specification defines Runtime State and Web Dashboard exposure for context readiness and runtime context generation status.

Source issue: [#41 Surface Context Readiness And Runtime Status](https://github.com/MatheusBBarni/symphony-orchestrator/issues/41).

## 1. Purpose & Scope

The purpose is to make Agent Context Snapshot and Context Command status visible without making context status a primary orchestration metric.

This specification covers Runtime State fields, API snapshots, frontend parsing, dashboard display, and tests.

Out of scope:

- Command execution behavior. Covered by issue #40.
- Diagnostics persistence. Covered by issue #42.

## 2. Definitions

- **Runtime State**: Backend snapshot of orchestration activity.
- **Readiness Gap**: Pre-dispatch configuration problem.
- **Web Dashboard**: Browser interface that consumes Runtime State snapshots.
- **Live Dashboard Connection**: Frontend connection that receives state snapshots.
- **Context Status**: The per-task state of context generation.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime State MUST expose context status for running tasks.
- **REQ-002**: Runtime State MUST expose context status for retrying tasks.
- **REQ-003**: Supported statuses MUST include `skipped`, `succeeded`, `warning`, `timed_out`, and `failed`.
- **REQ-004**: Readiness Gaps MUST identify the Stage Agent and exact setting path for invalid config.
- **REQ-005**: HTTP and websocket state endpoints MUST include context fields.
- **REQ-006**: Frontend parsing MUST tolerate snapshots that omit context fields.
- **REQ-007**: The Web Dashboard MUST show context status per running or retrying task.
- **CON-001**: Context status MUST NOT replace Goal Usage, task state, or readiness summaries.
- **CON-002**: Context failures MUST NOT be shown as task failures unless another runtime decision explicitly changes that behavior.

## 4. Interfaces & Data Contracts

### Runtime State Field

```json
{
  "running": [
    {
      "issue": {"identifier": "#41"},
      "context_status": {
        "state": "warning",
        "summary": "Context Command exited 1; prompt contains bounded warning.",
        "diagnostics_path": ".symphony/state/context/issue-41.json"
      }
    }
  ]
}
```

### Status Values

| Value | Meaning |
| --- | --- |
| `skipped` | Context behavior was disabled or not applicable. |
| `succeeded` | Context generation completed without warning. |
| `warning` | Context generated prompt warning content. |
| `timed_out` | Context Command exceeded timeout. |
| `failed` | Context generation failed before usable output. |

## 5. Acceptance Criteria

- **AC-001**: Given context is disabled, When Runtime State renders, Then the task context status is `skipped` or omitted according to the accepted compatibility design.
- **AC-002**: Given Context Command succeeds, When Runtime State renders, Then status is `succeeded`.
- **AC-003**: Given Context Command times out, When Runtime State renders, Then status is `timed_out`.
- **AC-004**: Given old snapshots omit context fields, When frontend parsing runs, Then the dashboard remains usable.
- **AC-005**: Given invalid context config, When readiness is evaluated, Then a Readiness Gap names the Stage Agent and setting path.

## 6. Test Automation Strategy

- **Test Levels**: Backend Runtime State/API tests and frontend live-state tests.
- **Frameworks**: OCaml Alcotest, frontend test runner via `pnpm frontend:test`.
- **Test Data Management**: Construct Runtime State fixtures for all status values.
- **CI/CD Integration**: Run `pnpm test` and `pnpm frontend:test`.
- **Coverage Requirements**: All status values, missing field compatibility, readiness gaps, HTTP state, websocket state, dashboard display mapping.
- **Performance Testing**: Not required.

## 7. Rationale & Context

Operators need to know whether context generation helped or degraded a task launch. The information belongs in existing Runtime State snapshots because the dashboard already consumes those snapshots for orchestration visibility.

## 8. Dependencies & External Integrations

### Infrastructure Dependencies

- **INF-001**: Runtime State - Carries live orchestration fields.
- **INF-002**: Web Dashboard - Displays status to operators.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Serializes Runtime State.
- **PLT-002**: ReScript React frontend - Parses and renders live-state data.

## 9. Examples & Edge Cases

```json
{"context_status": null}
```

Edge cases:

- Dashboard receives a snapshot from an older backend.
- A task moves from running to retrying with previous context status.
- Context Command succeeds with empty stdout.

## 10. Validation Criteria

- `pnpm test` passes.
- `pnpm frontend:test` passes.
- Dashboard displays context status without obscuring primary task state.

## 11. Related Specifications / Further Reading

- [Issue #41](https://github.com/MatheusBBarni/symphony-orchestrator/issues/41)
- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)
- [Issue #40](https://github.com/MatheusBBarni/symphony-orchestrator/issues/40)
- [API Conventions](../docs/agent-context/api-conventions.md)
