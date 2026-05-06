# Use per-task Git worktrees and task branches

## Status

Accepted

## Context

Personal Symphony can dispatch multiple tasks from one Loop-Start Branch. Running every agent in the Loop-Start Worktree makes task changes hard to isolate, makes concurrent work unsafe, and leaves the operator without a clear boundary for deciding which task changes should come back to the branch where orchestration started.

## Decision

Personal Symphony runs each dispatched task in an Agent Worktree under `.symphony/workspaces/`. Each Agent Worktree checks out a per-task Task Branch whose name starts with the configured Task Branch Prefix and is created from the Loop-Start Branch. Existing Task Branches are reused on restart, including tasks that already start in an in-progress project state.

The Loop-Start Worktree must be clean before Symphony creates a new Agent Worktree. Symphony creates or reuses the Agent Worktree before moving the task into the in-progress project state or launching agent work.

Runtime Settings include a Git Policy for:

- Task Branch Prefix.
- Protected Trunk Branches.
- serialized Task Branch Integration with a fast-forward-only final Loop-Start Branch update.
- Merge Attention Status.
- Task Cleanup Policy.

Stage Commit still happens before a task moves to its success status. When a stage commit policy enables Stage Push, Symphony pushes the current Task Branch after the Stage Commit and before any auto-merge attempt.

Completed Task Branches may auto-merge into the Loop-Start Branch only when the Loop-Start Branch is not a configured Protected Trunk Branch. The final Loop-Start Branch update is fast-forward only. When the Loop-Start Branch cannot fast-forward directly to a completed Task Branch, Symphony may merge the current Loop-Start Branch into the Task Branch from the Agent Worktree, then fast-forward the Loop-Start Branch to the updated Task Branch. Symphony does not push the Loop-Start Branch after auto-merge.

The default cleanup policy removes the Agent Worktree after a successful merge and keeps the Task Branch. If configured not to keep the Task Branch, Symphony deletes it after the worktree is removed.

## Consequences

Concurrent task work is isolated by Git instead of by convention. Operators can inspect, push, merge, or discard each Task Branch independently.

Merge conflicts and integration failures are treated as human attention events. Symphony moves the task to the configured Merge Attention Status, which defaults to `Human attention`, instead of retrying agent work against an integration problem.
