---
title: Stage Concurrency Policy
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, runtime-settings, scheduler, stage-agents, issue-35]
---

# Introduction

This specification defines Stage Concurrency Policy for Personal Symphony. The goal is to let a Workspace Repository configure how many agents may run for each Stage Agent while preserving the global `agent.maxConcurrentAgents` cap.

Source issue: [#35 maxConcurrentAgents for each stage](https://github.com/MatheusBBarni/symphony-orchestrator/issues/35).

## 1. Purpose & Scope

This specification applies to Runtime Settings, scheduler capacity calculation, Ordered Queue admission, dispatch behavior, Runtime State diagnostics, and tests for concurrent Stage Agent execution.

The intended audience is implementers and reviewers working on scheduling and stage dispatch behavior.

Out of scope:

- Keeping idle agents alive when no issue is dispatchable.
- Replacing the global `agent.maxConcurrentAgents` cap.
- Increasing concurrency for this Self-Dogfooding Workspace Repository before safe parallel Task Branch Integration is implemented.

Any implementation that changes runtime semantics MUST add or update an ADR under `docs/adr/`.

## 2. Definitions

- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Stage Agent**: A configured stage entry that owns one or more project statuses and transition behavior.
- **Stage Concurrency Policy**: A Runtime Settings rule that limits how many agents may run for a specific Stage Agent.
- **Ordered Queue**: A CLI-provided sequence of issue identifiers used as the dispatch order for eligible work.
- **Human Attention Status**: A paused project status for task work that requires operator triage.
- **Task Branch**: A Git branch created from the Loop-Start Branch for one dispatched task.
- **Task Branch Integration**: The act of bringing completed Task Branch commits into the Loop-Start Branch.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime Settings MUST support a Stage Concurrency Policy on each `stageAgents.stages[]` entry.
- **REQ-002**: Stage Concurrency Policy MUST apply to the Stage Agent entry, not to raw project status names.
- **REQ-003**: One Stage Agent that owns multiple statuses MUST share one concurrency limit across all owned statuses.
- **REQ-004**: The global `agent.maxConcurrentAgents` value MUST remain the maximum total number of running agents.
- **REQ-005**: Symphony MUST NOT exceed either a Stage Agent concurrency limit or the global concurrency cap.
- **REQ-006**: Omitted per-stage concurrency MUST preserve current behavior for that Stage Agent.
- **REQ-007**: A configured per-stage concurrency limit MUST be a positive integer.
- **REQ-008**: Invalid zero, negative, non-integer, or non-numeric limits MUST be Runtime Settings validation errors.
- **REQ-009**: Scheduler capacity MUST be recomputed from current running issue state on each poll.
- **REQ-010**: Symphony MUST NOT pre-spawn idle agents.
- **REQ-011**: If one issue is dispatchable for a Stage Agent with limit `2`, Symphony MUST launch only one agent.
- **REQ-012**: When an agent finishes, a later scheduler poll MUST refill only stage slots that have dispatchable issues.
- **REQ-013**: Ordered Queue admission order MUST remain authoritative for queued work.
- **REQ-014**: Stage Concurrency Policy MUST only decide whether an otherwise eligible issue has capacity to run.
- **REQ-015**: Running, retrying, blocked, and Human Attention tasks MUST NOT be double-dispatched.
- **REQ-016**: Runtime State SHOULD expose enough data to explain per-stage running counts and blocked capacity.
- **CON-001**: This Self-Dogfooding Workspace Repository SHOULD keep practical concurrency at one until safe parallel Task Branch Integration is implemented.
- **GUD-001**: After safe parallel Task Branch Integration exists, a recommended dogfood shape is planner `1`, engineer `2`, reviewer `2`, with a global cap high enough to permit the intended total.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

The exact field name may be adjusted during implementation, but per-stage capacity MUST be configured on the Stage Agent entry.

```json
{
  "agent": {
    "maxConcurrentAgents": 5
  },
  "stageAgents": {
    "stages": [
      {
        "agent": "planner",
        "statuses": ["Backlog"],
        "successStatus": "To-Do",
        "concurrency": 1
      },
      {
        "agent": "engineer",
        "statuses": ["To-Do", "In progress"],
        "successStatus": "In review",
        "concurrency": 2
      },
      {
        "agent": "reviewer",
        "statuses": ["In review"],
        "successStatus": "Done",
        "concurrency": 2
      }
    ]
  }
}
```

### Scheduler Capacity Contract

| Input | Expected result |
| --- | --- |
| Stage limit has available slot and global cap has available slot | Dispatch next eligible issue for that Stage Agent. |
| Stage limit is full | Do not dispatch more issues for that Stage Agent. |
| Global cap is full | Do not dispatch any additional issue. |
| Stage has no dispatchable issue | Launch no agent for that Stage Agent. |
| Ordered Queue has eligible entry but stage cap is full | Keep entry pending until capacity exists. |

## 5. Acceptance Criteria

- **AC-001**: Given Backlog limit `1`, engineer limit `2`, reviewer limit `2`, and global cap `5`, When all stages have dispatchable issues, Then Symphony can dispatch up to five agents across those Stage Agents.
- **AC-002**: Given engineer limit `2` and one eligible engineer issue, When the scheduler polls, Then Symphony launches one engineer agent.
- **AC-003**: Given stage limits sum to `5` and global cap is `3`, When five issues are eligible, Then Symphony runs no more than three agents total.
- **AC-004**: Given an Ordered Queue, When the next queued issue has stage capacity, Then it is admitted according to queue order.
- **AC-005**: Given an Ordered Queue entry is otherwise eligible but its Stage Agent is at capacity, When a later queue entry has different stage capacity, Then queue semantics determine whether the later entry may be admitted.
- **AC-006**: Given an issue is already running, retrying, blocked, or in Human Attention Status, When the scheduler polls, Then that issue is not double-dispatched.

## 6. Test Automation Strategy

- **Test Levels**: Unit and backend integration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Synthetic issue lists, Stage Agent fixtures, Ordered Queue fixtures, and temporary Runtime Settings files.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Cover parsing, capacity calculation, global cap interaction, queue behavior, and duplicate dispatch prevention.
- **Performance Testing**: Not required for first version.

Required tests:

- Config parsing for omitted per-stage limit, valid positive limit, invalid zero limit, and invalid negative limit.
- Dispatch with Backlog limit `1`, engineer limit `2`, reviewer limit `2`, and a global cap high enough to run all available stage slots.
- Single issue in a stage with limit `2` launches only one agent.
- Global cap lower than the sum of stage caps still limits total running agents.
- Ordered Queue plus Stage Concurrency Policy preserves queue admission order.
- No duplicate dispatch for issues already running, retrying, blocked, or in Human Attention Status.

## 7. Rationale & Context

The current global concurrency cap is not expressive enough for workflows where different stages should have different throughput. A planner stage may need one agent, while implementation and review stages may safely use more than one.

The policy belongs on Stage Agent entries because a Stage Agent may own multiple project statuses. Limiting raw statuses would split capacity incorrectly and make scheduler behavior harder to reason about.

Safe concurrency also depends on Task Branch Integration. Until unrelated concurrent Task Branches can integrate without avoidable merge attention, this Self-Dogfooding Workspace Repository should keep operational concurrency low.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - Provides dispatchable issue states.

### Third-Party Services

- **SVC-001**: Codex agent runtime - Receives launched agents for eligible issues.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Settings and Runtime State.

### Data Dependencies

- **DAT-001**: Issue state snapshot - Determines dispatchable, running, retrying, blocked, and Human Attention work.
- **DAT-002**: Ordered Queue state - Determines admission order when an Ordered Queue is active.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend scheduler - Computes stage and global capacity.

### Compliance Dependencies

- **COM-001**: ADR coverage - Runtime semantic changes require an ADR.

## 9. Examples & Edge Cases

```json
{
  "globalCap": 3,
  "stageCaps": {
    "planner": 1,
    "engineer": 2,
    "reviewer": 2
  },
  "running": {
    "planner": 1,
    "engineer": 1,
    "reviewer": 0
  },
  "availableGlobalSlots": 1,
  "availableStageSlots": {
    "planner": 0,
    "engineer": 1,
    "reviewer": 2
  }
}
```

Edge cases:

- A Stage Agent owns `Todo`, `To-Do`, and `In progress`: count all running issues for those statuses against one Stage Agent limit.
- A stage limit exceeds the global cap: allow the configuration but the global cap still controls total running agents.
- No dispatchable issue exists for a stage with open capacity: launch no idle agent.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- Scheduler never exceeds stage or global caps.
- Runtime Settings validation rejects invalid limits.
- Ordered Queue behavior remains deterministic.
- Runtime State provides enough information to explain why capacity did or did not dispatch work.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #35](https://github.com/MatheusBBarni/symphony-orchestrator/issues/35)
- [ADR directory](../docs/adr/)
- [Task Branch Integration specification](./spec-architecture-task-branch-integration.md)
