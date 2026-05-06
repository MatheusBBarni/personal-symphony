# ADR 0016: Stage Commit Classification and Commit Skill Load

## Status

Accepted

## Context

Stage Commit currently supports a per-stage commit type and message template. That is enough for a
single repository default, but it cannot express repository-owned classification rules based on issue
labels, stage-specific taxonomy, or an optional skill that guides agents whose work will be committed
by Symphony.

Letting agents create commits manually would conflict with Stage Commit ownership. Parsing free-form
agent prose as commit metadata would also make commit history depend on non-deterministic output.

## Decision

Richer commit metadata should be modeled as Stage Commit Classification in Runtime Settings.

Stage Commit Classification resolves to deterministic metadata such as type, optional scope, and
ordered tags. Runtime Settings own the classification taxonomy, stage defaults, label rules, and
conflict behavior. Existing Stage Commit settings remain backward compatible.

Issue labels may select classification through explicit Runtime Settings rules. Stage Agent
configuration supplies defaults and optional stage-level tags. Generated work outputs may contribute
to the generated commit summary, but they do not override authoritative classification metadata unless
a future Runtime Settings contract explicitly enables structured completion metadata.

A personalized commit skill may be configured as commit-specific Stage Skill Load for stages with
Stage Commit enabled. Symphony may render that skill into the Agent Prompt with the normal Stage
Skill Load, but the skill guides work only; it does not create the Stage Commit and does not replace
Runtime Settings classification.

Missing, malformed, duplicate, or conflicting classification and commit-skill configuration should
surface as readiness or completion errors with clear remediation.

## Consequences

Runtime Settings remain the source of truth for Stage Commit messages.

Agents can receive repository-specific commit guidance without taking ownership of Git commit
creation.

Stage Push, Task Branch Integration, auto-merge, Manual Task Merge, and Batch Pull Request behavior
remain unchanged.

The first implementation should avoid changing Runtime Contract defaults unless Human attention
explicitly approves that change.
