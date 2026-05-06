# Allowed Loop-Start Branch Policy

## Status

Accepted

## Context

Protected Trunk Branches prevent automated Task Branch integration into configured trunks, but they do not stop Symphony from starting orchestration on an unsuitable Loop-Start Branch. A Self-Dogfooding Workspace Repository needs a readiness gate so automated dogfood dispatch starts from a dedicated integration branch instead of from the Product Repository trunk.

## Decision

Runtime Settings may define `git.allowedLoopStartBranches` as the Allowed Loop-Start Branch Policy. The first version matches literal local branch names only.

When `git.allowedLoopStartBranches` is omitted or an empty list, Symphony allows any Loop-Start Branch to preserve existing Runtime Contract behavior and Bootstrap defaults. When the list is non-empty, Symphony compares the current named Loop-Start Branch to the configured set during readiness validation. If the branch is not allowed, or the checkout has no named branch, Symphony reports a Readiness Gap with the current branch state, allowed branch names, and the remediation to switch branches or update Runtime Settings.

The policy is separate from `protectedTrunkBranches`. Protected Trunk Branches still control automated Task Branch integration. The Allowed Loop-Start Branch Policy controls whether automated orchestration may start at all.

## Consequences

A disallowed Loop-Start Branch blocks dispatch before creating Agent Worktrees, moving tracker statuses, running Startup Reconciliation integration, or opening a Batch Pull Request. The Terminal Console and Web Dashboard remain available because Readiness Gaps are served as Runtime State.

Self-dogfooding setups can allow `symphony/dogfood` while keeping `main` as a Protected Trunk Branch. Existing Workspace Repositories that do not configure the policy keep their current behavior.
