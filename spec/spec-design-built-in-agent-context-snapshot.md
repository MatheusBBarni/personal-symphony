---
title: Built-In Agent Context Snapshot
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [design, agent-context, prompt-composition, issue-38]
---

# Introduction

This specification defines the built-in Agent Context Snapshot rendered into an Agent Prompt before Symphony launches a Stage Agent.

Source issue: [#38 Inject A Built-In Agent Context Snapshot](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38).

## 1. Purpose & Scope

The purpose is to provide deterministic, bounded launch context without relying on Codex lifecycle hooks or full transcript storage.

This specification covers Runtime Settings parsing, readiness validation, prompt composition, snapshot content, ordering, and backend tests.

Out of scope:

- Retry stdout/stderr tails. Covered by issue #39.
- Context Command execution. Covered by issue #40.
- Dashboard display. Covered by issue #41.

## 2. Definitions

- **Stage Agent**: A configured agent mapped to one or more issue states.
- **Agent Context Snapshot**: Bounded deterministic markdown appended to the Agent Prompt.
- **Readiness Gap**: A pre-dispatch configuration problem surfaced to the operator.
- **Task Branch**: A branch created for one dispatched issue.
- **Agent Worktree**: The per-task Git worktree under Runtime Home.
- **Loop-Start Branch**: The branch checked out when orchestration starts.
- **Stage Goal Handoff**: Optional Codex goal handoff sent before the Agent Prompt.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Missing snapshot configuration MUST mean disabled.
- **REQ-002**: Enabled configuration MUST be stage-specific.
- **REQ-003**: Invalid configuration MUST create a Readiness Gap before dispatch.
- **REQ-004**: Snapshot rendering MUST include issue identifier, title, project status, labels, blockers, attempt, Stage Agent name, Task Branch, Agent Worktree path, and Loop-Start Branch when available.
- **REQ-005**: Snapshot output MUST be deterministic in field order and list order.
- **REQ-006**: Snapshot output MUST enforce a configured or default max-size cap.
- **REQ-007**: Snapshot content MUST be appended under a stable markdown heading.
- **REQ-008**: Snapshot rendering MUST coexist with Stage Goal Handoff and stage agent instructions.
- **CON-001**: Snapshot rendering MUST NOT mutate Runtime Contract files.
- **CON-002**: Snapshot rendering MUST NOT include secret environment values.
- **GUD-001**: Snapshot field names SHOULD match `CONTEXT.md` domain terms.

## 4. Interfaces & Data Contracts

### Candidate Runtime Settings Shape

```json
{
  "stageAgents": {
    "stages": [
      {
        "states": ["Todo"],
        "agent": "engineer",
        "context": {
          "snapshot": {
            "enabled": true,
            "maxOutputBytes": 12000
          }
        }
      }
    ]
  }
}
```

### Prompt Section

```md
## Agent Context Snapshot

- Issue: #38 Inject A Built-In Agent Context Snapshot
- Project status: Todo
- Attempt: 1
- Stage Agent: engineer
- Task Branch: symphony/task/38-inject-a-built-in-agent-context-snapshot
- Agent Worktree: .symphony/workspaces/...
- Loop-Start Branch: symphony/dogfood
```

## 5. Acceptance Criteria

- **AC-001**: Given no context config, When an agent launches, Then no Agent Context Snapshot is appended.
- **AC-002**: Given valid enabled config, When an agent launches, Then the Agent Prompt includes the stable Agent Context Snapshot section.
- **AC-003**: Given invalid config, When readiness is evaluated, Then a Readiness Gap identifies the stage and setting path.
- **AC-004**: Given Stage Goal Handoff is enabled, When the prompt is composed, Then Stage Goal Handoff remains ordered before the normal Agent Prompt and snapshot content.
- **AC-005**: Given large snapshot data, When rendering occurs, Then output is truncated deterministically.

## 6. Test Automation Strategy

- **Test Levels**: Backend unit and integration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Use temporary config JSON, issues, and workspaces.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Disabled config, enabled config, invalid config, ordering, truncation, and Stage Goal Handoff coexistence.
- **Performance Testing**: Validate bounded rendering; no load test required.

## 7. Rationale & Context

Agents need enough local state to continue work after dispatch and retry. A built-in snapshot gives repeatable context without allowing unbounded transcript replay or hidden global Codex hook behavior.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - Supplies issue status, labels, and blockers.
- **EXT-002**: Git - Supplies branch and worktree names.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Agent Worktrees and Runtime State.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Implements Config and Orchestrator behavior.

## 9. Examples & Edge Cases

```text
Order:
1. Stage Goal Handoff, when enabled
2. Stage agent instructions and skill load, when configured
3. Rendered Agent Prompt
4. Agent Context Snapshot
```

Edge cases:

- Labels list is empty.
- Blockers list is empty.
- Task Branch is created during dispatch and was not available before workspace preparation.

## 10. Validation Criteria

- `pnpm test` passes.
- Prompt snapshots are deterministic.
- Readiness Gaps are actionable.
- No generated `.res.js` files are touched.

## 11. Related Specifications / Further Reading

- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)
- [Issue #37](https://github.com/MatheusBBarni/symphony-orchestrator/issues/37)
- [CONTEXT.md](../CONTEXT.md)
- [Agent Context Architecture Notes](../docs/agent-context/architecture.md)
