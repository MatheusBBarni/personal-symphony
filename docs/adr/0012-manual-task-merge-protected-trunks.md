# ADR 0012: Manual Task Merge can target protected trunks

## Status

Accepted

## Context

Auto-merge and Startup Reconciliation are automated integration paths. They stay conservative around Protected Trunk Branches because they can run as part of orchestration without an explicit per-task operator selection at merge time.

Operators also need a one-shot Manual Task Merge action for known completed Agent Worktrees. In that flow the operator provides explicit issue identifiers, such as `--merge 20` or `--merge #20`, and expects Symphony to preserve Task Branch naming, clean-worktree checks, fast-forward-only semantics, Task Cleanup Policy, and tracker transitions.

## Decision

Personal Symphony allows Manual Task Merge to integrate selected Task Branches into the current Loop-Start Branch even when that branch is a Protected Trunk Branch.

The selected issue identifiers are the operator confirmation of intent. No additional protected-trunk confirmation flag is required.

Manual Task Merge still:

- accepts issue identifiers only, not raw Task Branch names;
- rejects duplicate normalized selectors;
- requires clean Loop-Start and Agent Worktrees;
- preflights the full selected set before merging anything;
- evaluates multi-task fast-forward viability cumulatively in operator-provided order;
- uses fast-forward-only integration;
- applies the configured Task Cleanup Policy after successful or already-contained integration;
- does not push Task Branches or the Loop-Start Branch;
- does not run normal orchestration, Startup Reconciliation, Stage Push, Batch Branch Push, or Batch Pull Request behavior.

## Consequences

Operators can explicitly integrate selected completed task work while on `main` or another Protected Trunk Branch without leaving Symphony's Runtime Contract.

Automated flows remain conservative: auto-merge and Startup Reconciliation still do not integrate Task Branch work into Protected Trunk Branches.
