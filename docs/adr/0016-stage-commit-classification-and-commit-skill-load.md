# ADR 0016: Stage Commit Classification and Commit Skill Load

## Status

Accepted

## Context

Stage Commit currently supports a per-stage commit type and message template. That is enough for a
single repository default, but it cannot express repository-owned classification rules based on issue
labels, stage-specific taxonomy, commit tag guidance, or an optional skill that guides agents whose
work will be committed by Symphony.

Letting agents create commits manually would conflict with Stage Commit ownership. Parsing free-form
agent prose as commit metadata would also make commit history depend on non-deterministic output.

## Decision

Richer commit metadata should be modeled as Stage Commit Classification in Runtime Settings, with
repository-owned commit tag guidance in `tags.json`.

Stage Commit Classification resolves to deterministic metadata such as a commit type or
four-character tag. Runtime Settings own the classification taxonomy, stage defaults, label mappings,
and conflict behavior. Existing Stage Commit settings remain backward compatible, and `commit.type`
remains the stage-level fallback when richer classification is omitted.

Issue labels select classification before the stage default. No matching label uses the configured
fallback. Multiple matching labels that resolve to the same classification are unambiguous. Multiple
matching labels that resolve to different classifications pause the task through Human Attention
Status when Stage Commit is enabled, before Symphony creates a misleading Stage Commit.

`tags.json` is a JSON array of objects with `tag` and `instructions` fields. The `tag` value is the
four-character commit tag/type used by Stage Commit Classification, and `instructions` explains the
matching Git commit type semantics in four-character-tag form. Symphony should include this guidance
in every Stage Commit step so agent guidance and commit rendering use the same vocabulary.

Generated work outputs may contribute to the generated commit summary, but they do not override
authoritative classification metadata unless a future Runtime Settings contract explicitly enables
structured completion metadata.

A personalized commit skill may be configured only through explicit Stage Skill Load for the relevant
Stage Agent. Symphony renders configured skills into the Agent Prompt with the normal Stage Skill
Load, resolving Workspace Repository skills before Codex Home skills. A skill guides work only; it
does not create the Stage Commit and does not replace Runtime Settings classification.

Missing, malformed, duplicate, or conflicting classification and commit-skill configuration should
surface as readiness or completion errors with clear remediation.

## Consequences

Runtime Settings remain the source of truth for Stage Commit messages.

Agents can receive repository-specific commit guidance from `tags.json` and explicit Stage Skill Load
without taking ownership of Git commit creation.

Stage Push, Task Branch Integration, auto-merge, Manual Task Merge, and Batch Pull Request behavior
remain unchanged.

The first implementation should avoid changing Runtime Contract defaults unless Human attention
explicitly approves that change.
