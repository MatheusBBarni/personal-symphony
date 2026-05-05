# Manual Task Merge can target protected trunks

## Status

Accepted

## Context

Auto-merge and Startup Reconciliation do not integrate Task Branch work into Protected Trunk Branches because they are automated flows. Manual Task Merge is different: it is a one-shot operator action with explicit issue-identifier selection, so the selected tasks themselves are the operator's confirmation of intent.

## Decision

Personal Symphony allows Manual Task Merge to integrate selected Task Branches into a Protected Trunk Branch without an additional protected-trunk confirmation flag. The command still requires clean Loop-Start and Agent Worktrees, rejects duplicate selectors, preflights the entire selected set before merging anything, uses fast-forward-only semantics, and does not push branches.

## Consequences

Operators can use Symphony to perform an explicit local integration even when orchestration started on `main` or another Protected Trunk Branch. Automated flows remain conservative: auto-merge and Startup Reconciliation still refuse protected-trunk integration.
