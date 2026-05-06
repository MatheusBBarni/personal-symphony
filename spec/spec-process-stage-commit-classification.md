---
title: Stage Commit Classification
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, runtime-settings, git, stage-commit, issue-24]
---

# Introduction

This specification defines Stage Commit Classification for Personal Symphony. The goal is to make Stage Commit type or tag selection deterministic, configurable, and safe when issue labels or stage defaults provide commit metadata.

Source issue: [#24 Support richer commit stage tags and custom skills](https://github.com/MatheusBBarni/symphony-orchestrator/issues/24).

## 1. Purpose & Scope

This specification applies to Runtime Settings parsing, Stage Agent configuration, Stage Commit message rendering, and optional Stage Skill Load behavior in a Workspace Repository.

The intended audience is implementers, reviewers, and future agents working on Stage Commit behavior. This specification assumes the current Stage Commit flow remains: agent work completes, Stage Commit runs when configured, Stage Push runs only after a successful Stage Commit when enabled, and the issue moves to the stage success status only after the handoff succeeds.

Out of scope:

- Replacing Stage Commit with a separate global commit subsystem.
- Auto-loading a commit skill for every Workspace Repository.
- Allowing generated agent prose to choose unconstrained commit types.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Stage Agent**: A configured agent entry that owns one or more project statuses and transition behavior.
- **Stage Commit**: A commit created by Personal Symphony after an agent successfully completes a configured stage.
- **Stage Commit Classification**: Repository-owned metadata used to choose the commit type or tag for a Stage Commit.
- **Stage Push**: An optional non-force push of the current Task Branch after a Stage Commit is created.
- **Stage Skill Load**: The ordered set of skills configured for a Stage Agent.
- **Human Attention Status**: A paused project status for task work that requires operator triage before Symphony should continue.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime Settings MUST support a stage-level Stage Commit Classification policy when `commit.enabled` is `true`.
- **REQ-002**: A Stage Commit Classification policy MUST support a stage default classification.
- **REQ-003**: A Stage Commit Classification policy MUST support label-derived classification mappings from issue labels to commit classifications.
- **REQ-004**: Classification resolution MUST evaluate matching issue labels before using the stage default.
- **REQ-005**: If no issue label matches, Symphony MUST use the configured stage default classification.
- **REQ-006**: If multiple matching labels resolve to the same classification, Symphony MUST treat the result as unambiguous.
- **REQ-007**: If multiple matching labels resolve to different classifications and `commit.enabled` is `true`, Symphony MUST pause the task in Human Attention Status before creating a Stage Commit.
- **REQ-008**: Stage Commit message rendering MUST use the resolved classification wherever the commit message template references `<type>` or a future classification token.
- **REQ-009**: Stage Skill Load MUST remain opt-in through `stageAgents.stages[].skills`.
- **REQ-010**: Workspace Repository skills MUST resolve before Codex Home skills when both locations provide a skill with the same name.
- **REQ-011**: Runtime State or terminal diagnostics MUST identify the labels and mappings that caused a classification conflict.
- **SEC-001**: Documentation and examples MUST mention only secret variable names, never token values.
- **CON-001**: Stage Commit Classification MUST NOT replace `<generated_message_max_90char>` with unconstrained agent-authored prose.
- **CON-002**: Stage Push MUST remain non-force and MUST still run only after a successful Stage Commit.
- **GUD-001**: Classification names SHOULD be conventional commit types when the repository uses conventional commits.
- **PAT-001**: Implementers SHOULD keep the existing stage-level `commit.type` field as the compatibility fallback.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

The exact field names may be adjusted during implementation, but the data contract MUST preserve the following capabilities:

```json
{
  "stageAgents": {
    "stages": [
      {
        "agent": "engineer",
        "statuses": ["In progress"],
        "successStatus": "In review",
        "skills": ["git-commit"],
        "commit": {
          "enabled": true,
          "type": "feat",
          "message": "<type>: <generated_message_max_90char>",
          "push": false,
          "classification": {
            "default": "feat",
            "labelMap": {
              "bug": "fix",
              "documentation": "docs",
              "refactor": "refactor"
            },
            "conflictBehavior": "human_attention"
          }
        }
      }
    ]
  }
}
```

### Resolution Contract

| Input condition | Expected result |
| --- | --- |
| One matching label | Use the mapped classification. |
| No matching label | Use the stage default classification. |
| Multiple labels map to the same classification | Use that classification. |
| Multiple labels map to different classifications | Pause in Human Attention Status before Stage Commit. |
| `commit.enabled` is `false` | Do not create a Stage Commit and do not require classification resolution. |

## 5. Acceptance Criteria

- **AC-001**: Given a commit-enabled stage with a matching issue label, When Symphony renders the Stage Commit message, Then `<type>` is replaced with the mapped classification.
- **AC-002**: Given a commit-enabled stage without matching labels, When Symphony renders the Stage Commit message, Then `<type>` is replaced with the configured stage default.
- **AC-003**: Given a commit-enabled stage with conflicting mapped labels, When the stage completes, Then Symphony pauses the task in Human Attention Status and does not create a Stage Commit.
- **AC-004**: Given a Stage Agent with configured skills, When Symphony prepares the agent launch, Then Stage Skill Load remains ordered and opt-in.
- **AC-005**: Given `commit.push` is `true`, When the Stage Commit succeeds, Then Stage Push runs after the Stage Commit and remains non-force.
- **AC-006**: Given a documentation example, When it references GitHub authentication, Then it uses only variable names such as `GITHUB_TOKEN` or `GH_TOKEN`.

## 6. Test Automation Strategy

- **Test Levels**: Unit and backend integration tests.
- **Frameworks**: OCaml Alcotest for backend configuration and orchestration behavior.
- **Test Data Management**: Use temporary Workspace Repository fixtures and synthetic issues with labels.
- **CI/CD Integration**: Run through `pnpm test`.
- **Coverage Requirements**: Cover parsing, classification resolution, commit message rendering, conflict attention, and Stage Skill Load validation.
- **Performance Testing**: Not required; classification is local configuration and issue-label evaluation.

Required tests:

- Parse omitted classification, explicit default classification, valid label mappings, and invalid empty classifications.
- Render commit messages for fallback, label-derived, and conflicting classifications.
- Verify conflicting classification does not create a Stage Commit and records attention clearly.
- Verify existing Stage Push ordering remains unchanged.
- Verify Stage Skill Load still catches missing, malformed, and duplicate skills.

## 7. Rationale & Context

Stage Commit already provides deterministic stage-level commit creation. The missing capability is a repository-owned way to derive the commit classification from issue metadata without letting each agent improvise commit semantics.

Label-derived classification should be deterministic because issue labels are structured tracker data. Conflicts should pause for Human Attention Status because a misleading Stage Commit type creates bad repository history and can affect release automation.

Stage Skill Load should remain explicit. A Workspace Repository may opt into a personalized commit skill for a specific Stage Agent, but Symphony should not globally load one without repository configuration.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues - Provides issue labels used as classification input.
- **EXT-002**: Git - Creates Stage Commits and performs Stage Push.

### Third-Party Services

- **SVC-001**: GitHub remote - Receives non-force Stage Push when enabled.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Settings and Runtime State.

### Data Dependencies

- **DAT-001**: Issue labels - Classification input from the Workspace Repository issue tracker.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Parses settings and renders commit messages.

### Compliance Dependencies

- **COM-001**: Secret handling - Examples and diagnostics must not expose token values.

## 9. Examples & Edge Cases

```json
{
  "labels": ["bug", "documentation"],
  "labelMap": {
    "bug": "fix",
    "documentation": "docs"
  },
  "result": {
    "status": "human_attention",
    "reason": "Conflicting Stage Commit Classification values: fix, docs"
  }
}
```

Edge cases:

- A label appears more than once in tracker data: treat duplicates as one label.
- A label mapping references an empty classification: reject Runtime Settings as invalid.
- A commit-disabled stage has classification settings: parse them if present, but do not require resolution.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- Tests demonstrate deterministic fallback, label mapping, and conflict behavior.
- Human Attention diagnostics include enough information for an operator to remove or remap conflicting labels.
- Stage Push behavior remains non-force and ordered after Stage Commit.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #24](https://github.com/MatheusBBarni/symphony-orchestrator/issues/24)
- [GitHub issue labels documentation](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels)
