---
title: Protected Path Policy
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, runtime-settings, safety, git, issue-32]
---

# Introduction

This PRD defines a Protected Path Policy for Personal Symphony. The goal is to let a Workspace Repository declare paths that agent work must not modify unless a human explicitly authorizes that scope before dispatch.

Source issue: [#32 Add repository-owned protected path policy](https://github.com/MatheusBBarni/symphony-orchestrator/issues/32).

## 1. Purpose & Scope

This specification applies to Runtime Settings, task dispatch validation, changed-path inspection, Stage Commit, Stage Push, Task Branch Integration, Startup Reconciliation, Manual Task Merge, and Batch Pull Request handoff.

The intended audience is implementers and reviewers working on repository-owned file safety.

Out of scope:

- Replacing `.gitignore`.
- Creating a new `.symphonyignore` file in the first version.
- Supporting negation patterns in the first version.

Any implementation that changes runtime semantics MUST add or update an ADR under `docs/adr/`.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Runtime Contract**: Repository-owned files inside Runtime Home that define behavior.
- **Protected Path Policy**: A repository-owned rule that identifies Workspace Repository paths agent work must not modify without explicit authorization.
- **Agent Worktree**: An Agent Workspace backed by a Git worktree for one dispatched task.
- **Task Branch**: A Git branch created from the Loop-Start Branch for one dispatched task.
- **Stage Commit**: A commit created after an agent successfully completes a configured stage.
- **Stage Push**: A non-force push after a Stage Commit when enabled.
- **Human Attention Status**: A paused project status for task work that requires operator triage.
- **Manual Task Merge**: A one-shot operator CLI action that integrates selected completed Agent Worktrees or Task Branches into the current Loop-Start Branch.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The first version MUST store Protected Path Policy in Runtime Settings.
- **REQ-002**: Policy patterns MUST be repository-root-relative.
- **REQ-003**: Policy matching MUST support files, directories, and nested paths.
- **REQ-004**: Policy matching SHOULD use gitignore-like path semantics without negation in the first version.
- **REQ-005**: Symphony MUST evaluate modified, added, deleted, and renamed paths.
- **REQ-006**: Symphony MUST check protected path changes before creating a Stage Commit.
- **REQ-007**: Unauthorized protected path changes MUST pause the task in Human Attention Status and MUST NOT create a Stage Commit.
- **REQ-008**: When unauthorized protected path changes are detected, Symphony MUST NOT run Stage Push, Task Branch Integration, or Batch Pull Request handoff for that task.
- **REQ-009**: Startup Reconciliation MUST check committed Task Branch work for unauthorized protected path changes before integrating into the Loop-Start Branch.
- **REQ-010**: Manual Task Merge MUST check committed Task Branch work for unauthorized protected path changes before integrating into the Loop-Start Branch.
- **REQ-011**: Authorization MUST come from human-authored issue scope before dispatch.
- **REQ-012**: Agent output MUST NOT be able to authorize protected path changes.
- **REQ-013**: Authorization MUST name exact protected paths or exact policy pattern names.
- **REQ-014**: Human Attention diagnostics MUST list the protected paths that changed and the matching policy pattern.
- **REQ-015**: Batch Pull Request creation MUST remain blocked while protected-path attention is unresolved.
- **SEC-001**: Policy examples MUST NOT include secrets, token values, webhook URLs, or local `.env` contents.
- **CON-001**: The policy MUST NOT overwrite user-edited Runtime Contract files during Bootstrap.
- **CON-002**: The policy MUST NOT change ignored Runtime Home file behavior controlled by `.gitignore`.
- **GUD-001**: This Product Repository SHOULD protect package and release-sensitive paths once the policy exists.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

The exact field names may be adjusted during implementation, but Runtime Settings MUST support named protected patterns and a human authorization mechanism.

```json
{
  "paths": {
    "protected": {
      "patterns": [
        {
          "name": "cli-package-entrypoint",
          "pattern": "bin/symphony.js",
          "reason": "Package entrypoint changes require explicit human scope."
        },
        {
          "name": "package-binary-scripts",
          "pattern": "scripts/package-*.js",
          "reason": "Packaging behavior affects npm distribution."
        }
      ],
      "authorization": {
        "issueSection": "Protected Path Authorization"
      }
    }
  }
}
```

### Issue Authorization Shape

Human-authored issue scope MUST use an explicit section or equivalent structured tracker field.

```md
## Protected Path Authorization

- `bin/symphony.js`
- `package-binary-scripts`
```

### Recommended Initial Protected Paths For This Product Repository

```text
bin/symphony.js
scripts/package-binary.js
scripts/package-platforms.js
scripts/validate-npm-export.js
.github/workflows/export-npm.yml
package.json
pnpm-lock.yaml
vendor/symphony-*
```

## 5. Acceptance Criteria

- **AC-001**: Given a policy protecting `bin/symphony.js`, When an agent modifies that file without authorization, Then Symphony pauses the task in Human Attention Status before Stage Commit.
- **AC-002**: Given an issue authorizes `bin/symphony.js`, When an agent modifies that path, Then Symphony allows normal Stage Commit behavior.
- **AC-003**: Given committed Task Branch work modifies a protected path without authorization, When Startup Reconciliation runs, Then Symphony refuses integration and records attention.
- **AC-004**: Given Manual Task Merge targets a Task Branch with unauthorized protected path changes, When the command runs, Then Symphony refuses integration before changing the Loop-Start Branch.
- **AC-005**: Given a protected directory pattern, When a nested file changes, Then the policy matches that path.
- **AC-006**: Given unresolved protected-path attention exists, When Orchestration Idle is reached, Then Batch Pull Request creation remains blocked.

## 6. Test Automation Strategy

- **Test Levels**: Unit and backend integration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Temporary Workspace Repository fixtures with Git worktrees, policy settings, and synthetic issues.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Cover pattern matching, authorization parsing, Stage Commit block, Startup Reconciliation block, Manual Task Merge block, and unchanged `.gitignore` behavior.
- **Performance Testing**: Not required.

Required tests:

- Pattern matching for files, directories, globs, and nested paths.
- Unauthorized protected file modification blocks Stage Commit and keeps the Agent Worktree for inspection.
- Authorized protected file modification proceeds through normal Stage Commit behavior.
- Startup Reconciliation detects protected path changes in committed Task Branch work.
- Manual Task Merge detects protected path changes in committed Task Branch work.
- Existing Runtime Home `.gitignore` behavior remains unchanged.

## 7. Rationale & Context

Self-dogfooding requires stronger safeguards than prompt instructions. Routine agent tasks should not accidentally change package entrypoints, release workflows, packaged binary scripts, or other sensitive files. A repository-owned Protected Path Policy makes those safeguards explicit and enforceable before commits and integrations.

Runtime Settings is the preferred first storage location because it keeps policy configuration in the Runtime Contract and avoids introducing a new file format before the matching and authorization semantics are stable.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Git - Provides changed-path data and integration operations.
- **EXT-002**: GitHub Issues - Provides human-authored issue scope and authorization.

### Third-Party Services

- **SVC-001**: GitHub remote - Receives Stage Push only after protected path validation passes.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Settings and Runtime State.

### Data Dependencies

- **DAT-001**: Changed path list - Derived from Agent Worktree and Task Branch comparisons.
- **DAT-002**: Issue authorization section - Human-authored scope that permits protected path changes.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Performs policy parsing, matching, and orchestration blocking.

### Compliance Dependencies

- **COM-001**: ADR coverage - Runtime semantic changes require an ADR.
- **COM-002**: Secret safety - Policy examples and diagnostics must not include secret values.

## 9. Examples & Edge Cases

```json
{
  "changedPath": "scripts/package-binary.js",
  "matchedPattern": "package-binary-scripts",
  "authorized": false,
  "result": "human_attention"
}
```

Edge cases:

- Rename from unprotected path to protected path: treat as protected path change.
- Rename from protected path to unprotected path: treat as protected path change.
- Deleted protected path: treat as protected path change.
- Generated ignored file under Runtime Home: ignore according to `.gitignore`; Protected Path Policy governs Workspace Repository changes that would otherwise be committed or integrated.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- Unauthorized protected path changes block Stage Commit and integration paths.
- Authorized protected path changes require explicit human-authored issue scope.
- Diagnostics identify changed protected paths and matching patterns.
- Existing Runtime Home ignored-file behavior remains unchanged.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [ADR 0016: Protected Path Policy](../docs/adr/0016-protected-path-policy.md)
- [Issue #32](https://github.com/MatheusBBarni/symphony-orchestrator/issues/32)
- [ADR directory](../docs/adr/)
