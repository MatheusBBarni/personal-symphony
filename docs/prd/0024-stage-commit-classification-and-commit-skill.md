# PRD: Richer Stage Commit Classification and Commit-Specific Stage Skill Load

## Problem Statement

Personal Symphony can create a **Stage Commit** after a **Stage Agent** completes, but the current
classification model is too shallow. Each stage has one configured commit type, and the generated
message cannot reflect issue labels, richer repository taxonomy, or commit guidance that a
**Self-Dogfooding Workspace Repository** wants to apply consistently.

Operators need **Stage Commit** messages that communicate what kind of work happened without asking
agents to create commits manually. The system also needs a clear answer to whether richer tagging
belongs in **Runtime Settings**, in a personalized skill, or in both, so engineers do not blur
**Stage Commit** behavior with agent-side Git workflows.

## Solution

Model the feature as both:

1. **Runtime Settings**-driven **Stage Commit Classification**: the authoritative source for commit
   type, optional scope, and ordered tags used when Symphony renders a **Stage Commit** message.
2. Optional commit-specific **Stage Skill Load**: a skill reference that can be loaded for stages
   with **Stage Commit** enabled, so the agent receives repository-specific guidance for producing
   work that will later be committed by Symphony.

**Runtime Settings** remain authoritative for commit metadata. A personalized commit skill may guide
the agent, but it must not perform the **Stage Commit** and must not override resolved **Stage
Commit Classification** unless **Runtime Settings** explicitly allow a future structured stage
completion metadata input.

## User Stories

1. As an operator, I want **Stage Commits** to use issue labels when selecting a commit type, so that
   bug fixes, docs changes, refactors, and features are classified consistently.
2. As an operator, I want each **Stage Agent** to keep its own default **Stage Commit
   Classification**, so that planner, engineer, and reviewer stages can behave differently.
3. As an operator, I want **Runtime Settings** to define the repository's commit classification
   taxonomy, so that commit messages do not depend on each agent's memory.
4. As an operator, I want label-based classification rules to be deterministic, so that the same
   issue and stage configuration always produce the same **Stage Commit** message.
5. As an operator, I want conflicting label rules to produce an explicit **Readiness Gap** or
   configured deterministic fallback, so that ambiguous commit metadata does not silently produce
   misleading history.
6. As an operator, I want missing or malformed commit classification configuration to be caught
   before dispatch when possible, so that a task does not fail after agent work is complete.
7. As an operator, I want richer **Stage Commit** message tokens for type, scope, tags, issue
   identifier, issue title, stage transition, and **Stage Agent** name, so that repositories can
   choose their own commit style.
8. As an operator, I want existing **Stage Commit** message templates to keep working, so that
   current **Runtime Contracts** are not broken by the richer model.
9. As an engineer **Stage Agent**, I want a commit-specific skill to be loaded when my stage will
   create a **Stage Commit**, so that I know how to shape final work outputs without running Git
   commit commands myself.
10. As a planner **Stage Agent**, I want commit-specific guidance to stay disabled unless my stage
    creates **Stage Commits**, so that PRD-only planning work is not polluted by engineering commit
    instructions.
11. As a maintainer, I want generated work outputs to influence the generated summary text but not
    silently override explicit **Runtime Settings** classification, so that commit metadata remains
    reviewable and deterministic.
12. As a maintainer, I want **Stage Commit Classification** to be tested independently from Git
    commit execution, so that classification behavior can be verified without expensive repository
    setup.
13. As a maintainer, I want **Stage Skill Load** validation to cover automatically loaded commit
    skills, so that missing, malformed, or duplicate skill identifiers are surfaced as **Readiness
    Gaps**.
14. As a reviewer, I want the PRD to make clear that this feature does not change **Stage Push**,
    **Task Branch Integration**, auto-merge, or **Batch Pull Request** behavior, so that
    implementation scope stays narrow.
15. As a **Self-Dogfooding Workspace Repository** maintainer, I want commit classification language
    to use `CONTEXT.md` terms, so that future agents do not reintroduce "stage tag" or "commit
    label" terminology.

## Implementation Decisions

- Use **Stage Commit Classification** as the domain term. Avoid "commit label", "stage tag", or
  "arbitrary prefix" in product docs and implementation naming.
- Extend the **Stage Commit** policy model rather than replacing it. Existing `commit.enabled`,
  `commit.type`, `commit.message`, and `commit.push` semantics should continue to work.
- The richer classification should resolve to a small structured value: required type, optional
  scope, and an ordered tag list. The rendered commit message may expose these through new template
  tokens while preserving existing tokens.
- Classification source precedence should be deterministic:
  1. explicit per-stage commit classification defaults in the **Stage Agent** configuration;
  2. label rules from **Runtime Settings** that match the issue labels present in **Stage Goal
     Context** or tracker data;
  3. stage-level fallback classification when no label rule matches;
  4. generated summary text from work outputs only for the subject or body summary, not for
     authoritative type, scope, or tag selection.
- **Runtime Settings** should define repository-owned label rules. A rule may match one or more
  issue labels and produce type, scope, and/or tags. Rules should be ordered only if the conflict
  policy allows first-match behavior.
- Default conflict behavior should be conservative: conflicting matched rules for the same
  classification field should be a **Readiness Gap** or completion blocker with a clear remediation.
  If a later implementation adds `firstMatch` or priority-based conflict handling, that behavior
  must be explicit in **Runtime Settings**.
- Tag propagation should preserve configured order and de-duplicate repeated tags. Stage-level tags
  should appear before label-derived tags unless the final implementation documents a different
  deterministic order.
- The personalized commit skill should be modeled as a commit-specific **Stage Skill Load**
  reference, not as a separate Git commit runner. Symphony remains responsible for creating the
  **Stage Commit** after successful agent completion.
- The commit-specific skill may be loaded automatically only for stages with **Stage Commit** enabled
  and a configured commit skill. Auto-loading must participate in the same skill identifier
  validation used by normal **Stage Skill Load**.
- If the same skill appears in both the normal **Stage Skill Load** and the commit-specific
  **Stage Skill Load**, Symphony should load it once in deterministic order and report duplicate
  configuration clearly.
- Generated work outputs should support the generated message portion by using existing issue and
  stage data and, if added later, a bounded structured completion summary. Free-form agent prose must
  not be parsed as authoritative classification metadata in the first implementation.
- Because this changes **Runtime Settings** semantics for **Stage Commit Classification** and
  optional automatic skill loading, the implementation should add or update an ADR before shipping.
- Do not change **Runtime Contract** defaults in the first implementation unless Human attention
  explicitly approves it. Add examples to documentation without changing bootstrap defaults if
  default behavior is not approved.

Likely modules to touch are configuration parsing and readiness validation, **Stage Commit** message
rendering, orchestration completion behavior around **Stage Commit** creation, **Runtime Contract**
documentation, ADR documentation, and focused backend tests around config and **Stage Commit**
behavior.

## Testing Decisions

- Add pure tests for **Stage Commit Classification** resolution. These should cover stage defaults,
  label-derived classification, ordered tag propagation, de-duplication, no matching labels, and
  multiple matching labels.
- Add config and readiness tests for missing, malformed, duplicate, and conflicting classification or
  commit skill configuration.
- Add message rendering tests proving existing templates still work and new tokens render
  deterministically.
- Add **Stage Skill Load** tests proving a configured commit skill is loaded automatically only when
  **Stage Commit** is enabled for the stage, and that missing or duplicate commit skills are treated
  like existing skill readiness gaps.
- Add focused orchestration tests around **Stage Commit** creation to prove classification affects
  the commit message before the success status transition and does not affect **Stage Push**
  ordering.
- Keep tests near existing backend coverage for **Runtime Settings**, **Stage Goal Handoff**,
  **Stage Skill Load**, **Stage Commit** rendering, and Git-backed **Stage Commit** execution.
- Prefer tests of externally visible behavior: parsed config values, readiness gaps, rendered prompt
  skill load, rendered commit message, and Git commit result. Do not test helper function internals
  unless a deep classification resolver module is introduced with a stable interface.

## Out of Scope

- Changing **Stage Push** behavior.
- Changing **Task Branch Integration**, auto-merge, **Manual Task Merge**, or **Batch Pull Request**
  behavior.
- Asking agents to run Git commits manually.
- Parsing arbitrary agent final-answer prose as authoritative commit metadata.
- Replacing GitHub Issues + Projects as the tracker model.
- Changing **Runtime Contract** defaults without Human attention.
- Splitting the large backend test file unless a separate test-structure issue explicitly scopes
  that work.

## Further Notes

This issue is implementation-ready after the product decision above. The key engineering risk is
avoiding two competing sources of truth: **Runtime Settings** should own **Stage Commit
Classification**, while the personalized skill should only guide the agent's work and any optional
structured summary it produces.

The implementation should keep current **Stage Commit** behavior backward compatible: repositories
that only configure `commit.type` and `commit.message` should see the same messages they see today.
