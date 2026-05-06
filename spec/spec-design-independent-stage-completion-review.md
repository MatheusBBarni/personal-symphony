---
title: Independent Stage Completion Review
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [design, review, stage-completion, issue-44]
---

# Introduction

This specification defines the design questions and decision requirements for independent stage completion review after an agent exits successfully.

Source issue: [#44 Decide Independent Stage Completion Review Semantics](https://github.com/MatheusBBarni/symphony-orchestrator/issues/44).

## 1. Purpose & Scope

The purpose is to evaluate a feature inspired by `codex-loop` goal confirmation without mixing it into deterministic Agent Context Snapshot work.

This specification covers decision points, runtime semantic boundaries, expected ADR content, and validation requirements.

Out of scope:

- Implementing completion review.
- Changing Stage Commit, Stage Push, or status transition behavior before an ADR is accepted.

## 2. Definitions

- **Stage Agent**: A configured agent that handles a project status.
- **Stage Commit**: Commit created after an agent successfully completes a stage.
- **Stage Push**: Optional non-force push after Stage Commit.
- **Task Branch Integration**: Bringing completed Task Branch commits into the Loop-Start Branch.
- **Human Attention Status**: Project status used when operator attention is required.
- **Protected Trunk Branch**: Branch that must not receive automated task work integration.
- **Completion Review**: A proposed read-only review step after agent success and before completion semantics proceed.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Completion Review MUST be decided in an ADR or design note before implementation.
- **REQ-002**: The decision MUST state whether review is configured per Stage Agent or as a separate command mode.
- **REQ-003**: The decision MUST state what happens when review fails.
- **REQ-004**: The decision MUST state whether failed review retries the task, moves it to Human Attention Status, or adds guidance to the next attempt.
- **REQ-005**: The decision MUST state whether review output is schema-interpreted or deterministic-tool interpreted.
- **REQ-006**: The decision MUST define interactions with Stage Commit, Stage Push, Task Branch Integration, and Protected Trunk Branch behavior.
- **REQ-007**: The decision MUST define Runtime State and dashboard visibility if the feature proceeds.
- **CON-001**: Completion Review MUST NOT be implemented in the same slice as Agent Context Snapshot or Context Command execution.
- **CON-002**: Completion Review MUST NOT auto-merge work into Protected Trunk Branches.
- **GUD-001**: Prefer a design that preserves existing default completion behavior unless explicitly enabled.

## 4. Interfaces & Data Contracts

### Candidate Decision Matrix

| Decision | Required answer |
| --- | --- |
| Configuration location | Per Stage Agent or separate command mode. |
| Review timing | Before Stage Commit, after Stage Commit, or before status transition. |
| Failed review behavior | Retry, Human Attention Status, or guidance-only. |
| Output interpretation | Schema, deterministic tool, or manual review. |
| Runtime State exposure | Status, summary, diagnostics, and links. |

### Candidate Runtime State Field

```json
{
  "completion_review": {
    "state": "not_configured",
    "summary": null
  }
}
```

## 5. Acceptance Criteria

- **AC-001**: Given the design issue is completed, When docs are reviewed, Then an ADR or design note states whether the feature proceeds.
- **AC-002**: Given the feature proceeds, When runtime semantics are reviewed, Then failure behavior is unambiguous.
- **AC-003**: Given Stage Commit and Stage Push are reviewed, When Completion Review timing is defined, Then ordering is explicit.
- **AC-004**: Given Protected Trunk Branch behavior is reviewed, When Completion Review is defined, Then protected branch safety remains unchanged.
- **AC-005**: Given Agent Context Snapshot work is reviewed, When Completion Review is evaluated, Then the two features remain separate.

## 6. Test Automation Strategy

- **Test Levels**: Design review first; implementation tests only after ADR acceptance.
- **Frameworks**: OCaml Alcotest for later backend behavior.
- **Test Data Management**: Future tests should use temporary Workspace Repository fixtures and fake review commands.
- **CI/CD Integration**: Run `pnpm test` for any later implementation.
- **Coverage Requirements**: Future coverage must include review pass, review fail, retry or attention routing, Runtime State exposure, Stage Commit ordering, and Protected Trunk Branch safety.
- **Performance Testing**: Define timeout behavior before implementation.

## 7. Rationale & Context

`codex-loop` uses an independent reviewer and structured interpreter for goal confirmation. That behavior changes completion semantics. Symphony should evaluate it separately from deterministic context snapshots because context injection affects launch input, while completion review affects whether work is accepted.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - May receive status changes for attention or retry outcomes.

### Third-Party Services

- **SVC-001**: Optional model or command reviewer - Required only if the accepted design chooses an external reviewer.

### Infrastructure Dependencies

- **INF-001**: Runtime State - Would expose review status if implemented.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Would orchestrate review behavior if accepted.

### Compliance Dependencies

- **COM-001**: ADR coverage - Required before runtime completion semantics change.

## 9. Examples & Edge Cases

```text
Possible order if accepted:
1. Agent exits successfully.
2. Completion Review runs read-only.
3. Review passes.
4. Stage Commit runs.
5. Stage Push runs if enabled.
6. Status transition or Task Branch Integration proceeds.
```

Edge cases:

- Review command times out.
- Review output is malformed.
- Agent succeeds but review finds missing tests.
- Protected Trunk Branch prevents automated integration regardless of review.

## 10. Validation Criteria

- ADR or design note exists before implementation.
- Runtime completion behavior remains unchanged until the ADR is accepted.
- Future implementation tests cover every accepted outcome path.

## 11. Related Specifications / Further Reading

- [Issue #44](https://github.com/MatheusBBarni/symphony-orchestrator/issues/44)
- [Issue #37](https://github.com/MatheusBBarni/symphony-orchestrator/issues/37)
- [Codex Loop Context Management Analysis](../docs/agent-context/codex-loop-context-management.md)
- [Stage Goal Handoff ADR](../docs/adr/0007-stage-goal-handoff.md)
