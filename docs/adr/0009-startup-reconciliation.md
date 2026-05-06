# Startup Reconciliation

## Status

Accepted

## Context

Personal Symphony can restart with completed-stage Agent Worktrees whose Task Branch commits are not present on the Loop-Start Branch. This can happen after a crash, interrupted cleanup, or a protected-trunk skip. Without startup recovery, committed task work can remain stranded while normal dispatch resumes.

## Decision

Startup Reconciliation runs once per process startup after the first tracker fetch and before normal dispatch or agent launch. It considers only issues currently in a configured stage `successStatus` that also have an expected Agent Worktree path. Retained Task Branches without Agent Worktrees are outside the recovery scope.

Candidates are sorted by numeric issue identifier and then Task Branch name. The Loop-Start Worktree must be clean before any candidate is merged. Each Agent Worktree must be a valid Git worktree, be checked out on the expected Task Branch, reference an existing Task Branch, and have no uncommitted changes.

Safe committed work uses the same Task Branch Integration path as normal completion. Already-contained Task Branches are treated as reconciled. If the Loop-Start Branch can fast-forward directly to the Task Branch, Startup Reconciliation preserves that direct fast-forward. If direct fast-forward is not possible, Startup Reconciliation may merge the current Loop-Start Branch into the Task Branch from the Agent Worktree, then fast-forward the Loop-Start Branch to the updated Task Branch. Successful and already-contained candidates apply the existing Task Cleanup Policy and do not change tracker status.

Unsafe candidates move to the configured Merge Attention Status and are recorded in Runtime State issue errors. Protected Trunk Branch targets, wrong branches, missing Task Branches, uncommitted Agent Worktree changes, and conflicted integration are attention cases. Startup Reconciliation does not create Stage Commits, does not resolve conflicts, does not rebase, does not force-push, and does not auto-merge into Protected Trunk Branches.

Runtime State records startup reconciliation diagnostics for merged, already-reconciled, skipped, and attention outcomes. The Terminal Console also prints each outcome during startup.

## Consequences

Startup recovery is conservative and deterministic. Operators can see what was merged, what was already reconciled, what was ignored because it lacked an Agent Worktree, and what needs manual merge attention. Normal orchestration can continue after the pass, but attention tasks remain paused and non-dispatchable in the same startup session.
