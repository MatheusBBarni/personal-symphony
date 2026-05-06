# ADR 0015: Safe Parallel Task Branch Integration

## Status

Accepted

## Context

When `agent.maxConcurrentAgents` is greater than `1`, multiple Task Branches can start from the same Loop-Start Branch tip. After the first completed Task Branch fast-forwards the Loop-Start Branch, another unrelated Task Branch from the original tip is no longer a direct fast-forward even when its file changes do not conflict.

Treating that non-fast-forward shape as merge attention blocks useful parallel work. Rebasing the Task Branch would require force-pushing if Stage Push already published it. Creating a direct merge commit on the Loop-Start Branch would change the current model where the Loop-Start Branch moves only by fast-forwarding to a Task Branch tip.

## Decision

Automated Task Branch Integration is serialized and keeps the final Loop-Start Branch update fast-forward only.

Stage Commit still runs before Stage Push. Stage Push, when enabled, remains non-force and runs before Task Branch Integration.

If the Loop-Start Branch is a Protected Trunk Branch, Symphony does not run automated Task Branch Integration.

If the Loop-Start Branch already contains the Task Branch, Symphony treats the task as already integrated and applies eligible Task Cleanup Policy.

If the Loop-Start Branch can fast-forward directly to the completed Task Branch, Symphony preserves the direct fast-forward path.

If direct fast-forward is not possible, Symphony merges the current Loop-Start Branch into the completed Task Branch from the Agent Worktree. When that update succeeds, Symphony fast-forwards the Loop-Start Branch to the updated Task Branch tip. The integration merge commit belongs to the Task Branch and exists only to connect the current Loop-Start Branch history with the completed task work.

If the Task Branch update conflicts or the updated Task Branch still cannot fast-forward the Loop-Start Branch, Symphony moves the task to the Merge Attention Status and keeps the Agent Worktree for inspection.

Startup Reconciliation uses the same Task Branch Integration rules as normal completion. Manual Task Merge keeps its explicit operator-selected fast-forward-only semantics.

Runtime State records Task Branch Integration diagnostics so operators can distinguish already-contained work, direct fast-forward, update-then-fast-forward, and attention outcomes.

## Consequences

Unrelated concurrently completed Task Branches can integrate into the Loop-Start Branch without avoidable merge attention.

Published Task Branches do not need force-push because integration updates are ordinary merge commits on the Task Branch.

Protected Trunk Branch behavior is unchanged.

True conflicts remain visible as human attention, with the Agent Worktree retained for inspection.

Batch Pull Request behavior remains based on work already integrated into the Loop-Start Branch and remains blocked while Merge Attention Status or unresolved orchestration attention exists.
