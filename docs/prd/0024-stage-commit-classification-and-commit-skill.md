# PRD: Stage Commit Classification and Commit Tag Guidance

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
   type or tag used when Symphony renders a **Stage Commit** message.
2. Repository-owned commit tag guidance in `tags.json`: the vocabulary that explains valid
   four-character commit tags to agents and commit rendering.

**Runtime Settings** remain authoritative for commit metadata. A personalized commit skill may guide
the agent only when it is explicitly listed in normal **Stage Skill Load**, but it must not perform
the **Stage Commit** and must not override resolved **Stage Commit Classification** unless
**Runtime Settings** explicitly allow a future structured stage completion metadata input.

## User Stories

1. As an operator, I want **Stage Commits** to use issue labels when selecting a commit type, so that
   bug fixes, docs changes, refactors, and features are classified consistently.
2. As an operator, I want each **Stage Agent** to keep its own default **Stage Commit
   Classification**, so that planner, engineer, and reviewer stages can behave differently.
3. As an operator, I want **Runtime Settings** to define the repository's commit classification
   taxonomy, so that commit messages do not depend on each agent's memory.
4. As an operator, I want label-based classification rules to be deterministic, so that the same
   issue and stage configuration always produce the same **Stage Commit** message.
5. As an operator, I want conflicting label rules to pause the task in **Human Attention Status**,
   so that ambiguous commit metadata does not silently produce misleading history.
6. As an operator, I want missing or malformed commit classification configuration to be caught
   before dispatch when possible, so that a task does not fail after agent work is complete.
7. As an operator, I want a repository-owned `tags.json` file that defines the available
   four-character commit tags, so that agents and **Stage Commit** rendering use the same tag
   vocabulary.
8. As an operator, I want existing **Stage Commit** message templates to keep working, so that
   current **Runtime Contracts** are not broken by the richer model.
9. As an engineer **Stage Agent**, I want a commit-specific skill to be loaded when my stage will
   create a **Stage Commit** only if the Workspace Repository explicitly configures that skill, so
   that I know how to shape final work outputs without running Git commit commands myself.
10. As a planner **Stage Agent**, I want commit-specific guidance to stay disabled unless my stage
    explicitly opts into it, so that PRD-only planning work is not polluted by engineering commit
    instructions.
11. As a maintainer, I want generated work outputs to influence the generated summary text but not
    silently override explicit **Runtime Settings** classification, so that commit metadata remains
    reviewable and deterministic.
12. As a maintainer, I want **Stage Commit Classification** to be tested independently from Git
    commit execution, so that classification behavior can be verified without expensive repository
    setup.
13. As a maintainer, I want **Stage Skill Load** validation to keep catching missing, malformed, or
    duplicate explicitly configured skills, so that commit guidance follows the same readiness model
    as other stage skills.
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
- Keep `commit.type` as the stage-level compatibility fallback. A stage may add a richer
  `commit.classification` policy under its existing commit policy instead of configuring a separate
  global commit subsystem.
- The richer classification should initially resolve to a deterministic commit type or
  four-character tag. A future implementation may add structured scope or additional tokens, but the
  first implementation should keep `<type>` and any future classification token deterministic.
- Classification source precedence should be deterministic:
  1. label rules from **Runtime Settings** that match the issue labels present in **Stage Goal
     Context** or tracker data;
  2. explicit per-stage `commit.classification.default`;
  3. stage-level `commit.type` fallback when `commit.classification.default` is omitted;
  4. generated summary text from work outputs only for the subject or body summary, not for
     authoritative type, scope, or tag selection.
- **Runtime Settings** should define repository-owned label mappings. A mapping matches one issue
  label and resolves to one classification.
- No matching label is normal and should use the stage default classification.
- Multiple matching labels that resolve to the same classification are unambiguous.
- Multiple matching labels that resolve to different classifications should pause the task through
  **Human Attention Status** when `commit.enabled` is `true`; Symphony should not create a
  misleading **Stage Commit** and should not retry agent work to resolve the conflict.
- `commit.classification.conflictBehavior` should support `human_attention` for the first
  implementation. If a later implementation adds `first_match` or priority-based behavior, that
  behavior must be explicit in **Runtime Settings**.
- The generated commit message template stays deterministic. **Stage Commit Classification** chooses
  the `<type>` value or a future classification token, while `<generated_message_max_90char>` remains
  bounded generated summary text rather than unconstrained agent-authored prose.
- Add repository-owned `tags.json` as commit tag/type guidance. The file must be a JSON array. Each
  array item must be an object with `tag` and `instructions` fields.
- Each `tags.json` `tag` must be the four-character commit tag/type value used by **Stage Commit
  Classification**. Each `instructions` value must explain the matching Git commit type semantics in
  four-character-tag form.
- The `tags.json` guidance should be included in every **Stage Commit** step so commit rendering and
  agent guidance use the same tag vocabulary.
- A personalized commit skill should be modeled only as explicit **Stage Skill Load** through
  `stageAgents.stages[].skills`, not as a global commit skill and not as a separate Git commit
  runner. Symphony remains responsible for creating the **Stage Commit** after successful agent
  completion.
- **Stage Skill Load** should resolve Workspace Repository skills before Codex Home skills when both
  locations provide a skill with the same name.
- If the same skill appears more than once in explicit **Stage Skill Load**, Symphony should keep
  reporting duplicate configuration clearly through the existing validation model.
- Generated work outputs should support the generated message portion by using existing issue and
  stage data and, if added later, a bounded structured completion summary. Free-form agent prose must
  not be parsed as authoritative classification metadata in the first implementation.
- Because this changes **Runtime Settings** semantics for **Stage Commit Classification** and adds
  repository-owned `tags.json` guidance, the implementation should add or update an ADR before
  shipping.
- Do not change **Runtime Contract** defaults in the first implementation unless Human attention
  explicitly approves it. Add examples to documentation without changing bootstrap defaults if
  default behavior is not approved.

Likely modules to touch are configuration parsing and readiness validation, `tags.json` parsing,
**Stage Commit** message rendering, orchestration completion behavior around **Stage Commit**
creation, **Runtime Contract** documentation, ADR documentation, and focused backend tests around
config and **Stage Commit** behavior.

## Testing Decisions

- Add pure tests for **Stage Commit Classification** resolution. These should cover stage defaults,
  label-derived classification, no matching labels, multiple matching labels that resolve to the
  same classification, and multiple matching labels that conflict.
- Add config and readiness tests for missing, malformed, duplicate, and conflicting classification or
  skill configuration.
- Add `tags.json` parsing tests for a valid JSON array, missing `tag`, missing `instructions`,
  non-object array items, empty tags, and non-four-character tags.
- Add message rendering tests proving existing templates still work and new tokens render
  deterministically.
- Add **Stage Skill Load** tests proving configured skills remain opt-in, ordered, and resolved from
  Workspace Repository skills before Codex Home skills. Missing, malformed, and duplicate skills
  should remain readiness gaps.
- Add focused orchestration tests around **Stage Commit** creation to prove classification affects
  the commit message before the success status transition and does not affect **Stage Push**
  ordering.
- Add a focused orchestration test proving a commit-enabled stage with conflicting classification
  does not create a **Stage Commit** and records **Human Attention Status** diagnostics that name the
  conflicting labels and classifications.
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
