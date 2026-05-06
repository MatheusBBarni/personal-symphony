---
title: Task Branch Integration
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [architecture, git, task-branch, concurrency, issue-36]
---

# Introduction

This specification defines safe Task Branch Integration for concurrently completed Task Branches. The goal is to allow unrelated Task Branches that start from the same Loop-Start Branch tip to integrate cleanly when `agent.maxConcurrentAgents` is greater than `1`.

Source issue: [#36 Support safe parallel Task Branch integration](https://github.com/MatheusBBarni/symphony-orchestrator/issues/36).

## 1. Purpose & Scope

This specification applies to Stage Commit, Stage Push, Task Branch Integration, Merge Attention Status, Human Attention Status, Startup Reconciliation, Task Cleanup Policy, and Batch Pull Request behavior.

The intended audience is implementers and reviewers working on Git integration semantics.

Out of scope:

- Automated integration into Protected Trunk Branches.
- Force-pushing Task Branches.
- Replacing per-task Git worktrees.

Any implementation that changes runtime semantics MUST add or update an ADR under `docs/adr/`.

## 2. Definitions

- **Loop-Start Branch**: The Workspace Repository branch checked out when orchestration starts.
- **Task Branch**: A Git branch created from the Loop-Start Branch for one dispatched task.
- **Task Branch Integration**: The act of bringing completed Task Branch commits into the Loop-Start Branch.
- **Agent Worktree**: An Agent Workspace backed by a Git worktree for one dispatched task.
- **Protected Trunk Branch**: A configured branch that Symphony must not auto-merge task work into.
- **Stage Commit**: A commit created after an agent successfully completes a configured stage.
- **Stage Push**: An optional non-force push after Stage Commit.
- **Merge Attention Status**: The Human Attention Status used when agent work completed but its Task Branch could not be auto-merged.
- **Task Cleanup Policy**: The Git Policy setting that controls whether completed task worktrees or branches are removed.
- **Batch Pull Request**: A pull request opened from the Loop-Start Branch after Orchestration Idle.
- **Startup Reconciliation**: Startup recovery that checks completed-stage Agent Worktrees for Task Branch commits not present on the Loop-Start Branch.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Stage Commit MUST run before Task Branch Integration, exactly as current behavior requires.
- **REQ-002**: Stage Push, when enabled, MUST run after Stage Commit and before Task Branch Integration.
- **REQ-003**: Stage Push MUST remain non-force.
- **REQ-004**: If the Loop-Start Branch is a Protected Trunk Branch, Symphony MUST NOT run automated Task Branch Integration.
- **REQ-005**: If the Loop-Start Branch can fast-forward directly to the completed Task Branch, Symphony MUST preserve the current direct fast-forward behavior.
- **REQ-006**: If direct fast-forward is not possible, Symphony MUST attempt to update the completed Task Branch from the current Loop-Start Branch inside the Agent Worktree.
- **REQ-007**: The update operation SHOULD merge the current Loop-Start Branch into the Task Branch instead of rebasing the Task Branch.
- **REQ-008**: If the Task Branch update succeeds, Symphony MUST fast-forward the Loop-Start Branch to the updated Task Branch tip.
- **REQ-009**: If the Task Branch update conflicts or cannot complete cleanly, Symphony MUST move the task to Merge Attention Status or Human Attention Status.
- **REQ-010**: When integration pauses for attention, Symphony MUST keep the Agent Worktree for inspection.
- **REQ-011**: Any integration merge commit MUST be clearly identified as integration-only and MUST NOT include new agent-authored file changes beyond the merge result.
- **REQ-012**: Task Cleanup Policy MUST apply only after successful integration or already-contained work.
- **REQ-013**: Batch Pull Request creation MUST wait for Orchestration Idle and MUST NOT open while any task is in Merge Attention Status or unresolved orchestration attention.
- **REQ-014**: Startup Reconciliation MUST use the same integration safety rules as normal task completion.
- **REQ-015**: Runtime State MUST record enough diagnostics to explain whether integration fast-forwarded directly, updated the Task Branch first, or paused for attention.
- **CON-001**: Symphony MUST NOT auto-merge task work into a Protected Trunk Branch.
- **CON-002**: Symphony MUST NOT force-push Task Branches as part of integration.
- **CON-003**: Direct merge commits on the Loop-Start Branch SHOULD NOT be used for this strategy.
- **GUD-001**: The implementation SHOULD serialize final Loop-Start Branch updates to avoid concurrent writes to the same branch checkout.

## 4. Interfaces & Data Contracts

### Integration Decision Contract

| Condition | Required action |
| --- | --- |
| Loop-Start Branch is protected | Skip automated integration and report attention according to existing Protected Trunk Branch behavior. |
| Task Branch is already contained | Mark integration as already contained and apply eligible cleanup. |
| Loop-Start Branch can fast-forward to Task Branch | Fast-forward Loop-Start Branch to Task Branch. |
| Direct fast-forward fails but merge from Loop-Start Branch into Task Branch succeeds | Fast-forward Loop-Start Branch to updated Task Branch. |
| Merge from Loop-Start Branch into Task Branch conflicts | Move task to Merge Attention Status or Human Attention Status and keep Agent Worktree. |

### Runtime State Diagnostic Shape

Runtime State MUST expose equivalent information.

```json
{
  "issue": "#36",
  "taskBranch": "symphony/task/36-support-safe-parallel-task-branch-integration",
  "loopStartBranch": "symphony/dogfood",
  "integration": {
    "result": "updated_task_branch_then_fast_forwarded",
    "directFastForward": false,
    "taskBranchUpdatedFromLoopStart": true,
    "attention": null
  }
}
```

## 5. Acceptance Criteria

- **AC-001**: Given two unrelated Task Branches created from the same Loop-Start Branch tip, When both complete and `agent.maxConcurrentAgents > 1`, Then both can integrate into the Loop-Start Branch.
- **AC-002**: Given two Task Branches modify the same file incompatibly, When the second integration encounters a conflict, Then only the affected task moves to Merge Attention Status or Human Attention Status.
- **AC-003**: Given Stage Push is enabled, When a task completes, Then Stage Push runs before Task Branch Integration and remains non-force.
- **AC-004**: Given the Loop-Start Branch is a Protected Trunk Branch, When a task completes, Then automated Task Branch Integration is skipped.
- **AC-005**: Given Task Branch Integration succeeds, When Task Cleanup Policy is enabled for worktree cleanup, Then cleanup runs only after integration succeeds.
- **AC-006**: Given any task has Merge Attention Status, When Orchestration Idle would otherwise open a Batch Pull Request, Then no Batch Pull Request opens.
- **AC-007**: Given the process restarts with completed Agent Worktrees, When Startup Reconciliation runs, Then it follows the same safe integration path as normal completion.

## 6. Test Automation Strategy

- **Test Levels**: Backend integration tests with temporary Git repositories.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Create temporary Workspace Repository fixtures, Loop-Start Branch commits, Agent Worktrees, and Task Branch commits.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Cover direct fast-forward, update-then-fast-forward, conflict attention, Protected Trunk Branch skip, Stage Push ordering, Task Cleanup Policy, Startup Reconciliation, and Batch Pull Request blocking.
- **Performance Testing**: Not required for first version.

Required tests:

- Parallel completion of two Task Branches that touch different files integrates both into the Loop-Start Branch.
- Parallel completion of two Task Branches that conflict on the same file leaves the second task in Human Attention and keeps its Agent Worktree.
- A pushed Task Branch is never force-pushed during integration.
- Protected Trunk Branch completion still skips automated integration.
- Startup Reconciliation follows the same safe integration path as normal task completion.
- Batch Pull Request creation remains blocked while merge attention exists.

## 7. Rationale & Context

With `agent.maxConcurrentAgents > 1`, unrelated Task Branches can start from the same Loop-Start Branch tip. After the first branch fast-forward merges, the second branch may no longer be a direct fast-forward even when the file changes do not conflict.

Rebasing the Task Branch would require force-pushing if Stage Push already published the branch. Direct merge commits on the Loop-Start Branch would change the current fast-forward integration model. Updating the Task Branch by merging the current Loop-Start Branch into it preserves non-force publication and still allows the Loop-Start Branch to move by fast-forward to the Task Branch tip.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Git - Provides worktrees, merges, fast-forward checks, and branch updates.
- **EXT-002**: GitHub Issues + Projects - Receives task attention status updates.

### Third-Party Services

- **SVC-001**: GitHub remote - Receives Stage Push and optional Batch Branch Push.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Agent Worktrees and Runtime State.

### Data Dependencies

- **DAT-001**: Task Branch commit graph - Determines direct fast-forward and update requirements.
- **DAT-002**: Runtime Settings Git Policy - Defines Protected Trunk Branches and Task Cleanup Policy.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Implements orchestration and Git integration.

### Compliance Dependencies

- **COM-001**: ADR coverage - Runtime semantic changes require an ADR.

## 9. Examples & Edge Cases

```text
Initial Loop-Start Branch: A
Task Branch 1: A -> B (changes file one)
Task Branch 2: A -> C (changes file two)

Integrate Task Branch 1:
Loop-Start Branch: A -> B

Integrate Task Branch 2:
Merge current Loop-Start Branch B into Task Branch 2, producing D.
Fast-forward Loop-Start Branch from B to D.
```

Edge cases:

- Task Branch already contains the Loop-Start Branch: direct fast-forward may succeed.
- Task Branch has uncommitted changes in Agent Worktree: pause for attention before integration.
- Merge creates conflicts: abort or leave merge state according to ADR-defined implementation details, then keep Agent Worktree for inspection.
- Stage Push fails before integration: do not integrate and preserve existing retry behavior.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- Two unrelated concurrent Task Branches integrate successfully.
- True conflicts pause only affected tasks.
- No Task Branch integration path force-pushes.
- Protected Trunk Branch behavior remains unchanged.
- Runtime State explains each integration outcome.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #36](https://github.com/MatheusBBarni/symphony-orchestrator/issues/36)
- [ADR directory](../docs/adr/)
- [Stage Concurrency Policy specification](./spec-process-stage-concurrency-policy.md)
