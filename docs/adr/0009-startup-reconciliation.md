# Startup Reconciliation

## Status

Accepted

## Context

Personal Symphony can restart with completed-stage Agent Worktrees whose Task Branch commits are not present on the Loop-Start Branch. Startup Reconciliation runs once per Symphony process startup, before normal dispatch or agent launch, and evaluates completed-stage Agent Worktrees in deterministic order.

## Decision

Startup Reconciliation is scoped to Agent Worktrees for tasks in a configured stage success status, not every retained Task Branch. It evaluates candidates in deterministic order by issue identifier numeric key, then Task Branch name. A completed-stage Agent Worktree must be on the expected Task Branch for its issue; missing or mismatched Task Branch state moves the task to Merge Attention Status. Startup Reconciliation only integrates committed Task Branch work into a Clean Loop-Start Worktree using explicit Git preflight checks followed by fast-forward merge semantics; uncommitted Agent Worktree changes, non-fast-forward branches, and committed work targeting a Protected Trunk Branch move the task to Merge Attention Status with operator-visible Runtime State diagnostics. Successful or already-contained reconciliation applies the configured Task Cleanup Policy without changing the task's tracker status.

## Consequences

Startup recovery remains conservative: it does not invent Stage Commits, does not auto-merge into Protected Trunk Branches, and does not resurrect historical kept Task Branches without Agent Worktrees. Operators get persistent diagnostics for reconciliation outcomes while tasks moved to Merge Attention Status remain paused and excluded from dispatch or retry.
