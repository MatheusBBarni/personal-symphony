# ADR 0017: Merge Conflict Resolution Handoff

## Status

Accepted

## Context

Safe parallel Task Branch Integration can update a completed Task Branch by merging the current Loop-Start Branch into the Agent Worktree, then fast-forwarding the Loop-Start Branch to the updated Task Branch. When that Task Branch update conflicts, Symphony previously stopped immediately in the Merge Attention Status.

That behavior is conservative, but it leaves resolvable conflicts for the operator even though the Agent Worktree already contains the exact conflicted state an agent can inspect and repair.

## Decision

Runtime Settings may enable a Git Policy `conflictResolution` block with `enabled` and `maxAttempts`.

When auto-merge fails while updating the Task Branch from the Loop-Start Branch, and Merge Conflict Resolution Handoff is enabled, Symphony launches Codex inside the conflicted Agent Worktree. The handoff prompt tells the agent to resolve conflicts, preserve both task and Loop-Start Branch intent, stage the resolved files, and create the merge commit on the Task Branch.

After the conflict-resolution agent exits successfully, Symphony requires the Agent Worktree to be clean. It then fast-forwards the Loop-Start Branch to the resolved Task Branch. If the Agent Worktree remains dirty, the agent fails, the attempt limit is reached, or the resolved Task Branch cannot fast-forward the Loop-Start Branch, Symphony moves the task to the Merge Attention Status and keeps the Agent Worktree for inspection.

Merge Conflict Resolution Handoff is disabled by default. Startup Reconciliation continues to move conflicted candidates to Merge Attention Status instead of launching agents during startup recovery.

## Consequences

Operators can opt into agent-assisted conflict repair without changing the invariant that the final Loop-Start Branch update is fast-forward only.

The conflict-resolution merge commit belongs to the Task Branch, so published Task Branches still do not need force-push.

True or unresolved conflicts remain visible as human attention, with the Agent Worktree retained.
