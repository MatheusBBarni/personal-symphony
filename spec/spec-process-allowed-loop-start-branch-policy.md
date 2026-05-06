---
title: Allowed Loop-Start Branch Policy
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, runtime-settings, readiness, git, issue-30]
---

# Introduction

This specification defines an Allowed Loop-Start Branch Policy for Personal Symphony. The goal is to let a Workspace Repository restrict automated orchestration to approved Loop-Start Branches and surface a Readiness Gap when Symphony is started from a disallowed branch.

Source issue: [#30 Add allowed Loop-Start Branch readiness policy](https://github.com/MatheusBBarni/symphony-orchestrator/issues/30).

## 1. Purpose & Scope

This specification applies to Runtime Settings, readiness validation, Terminal Console readiness output, Web Dashboard readiness output, dispatch gating, Startup Reconciliation, and Batch Pull Request handoff.

The intended audience is implementers and reviewers working on Git Policy and readiness behavior.

Out of scope:

- Changing default Bootstrap Runtime Settings without explicit approval.
- Replacing `protectedTrunkBranches`.
- Supporting glob or regular-expression branch matching in the first version.

Any implementation that changes runtime semantics MUST add or update an ADR under `docs/adr/`.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Git Policy**: The Runtime Settings section that defines Task Branch and Protected Trunk Branch behavior.
- **Loop-Start Branch**: The Workspace Repository branch checked out when orchestration starts.
- **Allowed Loop-Start Branch Policy**: A Runtime Settings rule that identifies which Loop-Start Branches may dispatch automated orchestration.
- **Protected Trunk Branch**: A configured branch that Symphony must not auto-merge task work into.
- **Readiness Gap**: A missing or invalid runtime requirement that prevents dispatch.
- **Startup Reconciliation**: Startup recovery that checks completed-stage Agent Worktrees for Task Branch commits not present on the Loop-Start Branch.
- **Batch Pull Request**: A pull request opened from the Loop-Start Branch after Orchestration Idle.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime Settings MUST support an Allowed Loop-Start Branch Policy under Git Policy.
- **REQ-002**: If the policy is absent, Symphony MUST preserve existing behavior and allow any Loop-Start Branch.
- **REQ-003**: If the policy is present with an empty branch list, Symphony MUST allow any Loop-Start Branch unless implementation explicitly defines empty as invalid in an ADR.
- **REQ-004**: The first version MUST match literal local branch names only.
- **REQ-005**: Symphony MUST evaluate the current Loop-Start Branch before dispatching any task.
- **REQ-006**: When the current Loop-Start Branch is disallowed, Symphony MUST report a Readiness Gap and MUST NOT create Agent Worktrees.
- **REQ-007**: When the current Loop-Start Branch is disallowed, Symphony MUST NOT move project statuses, run Stage Agents, perform Startup Reconciliation integration, or open a Batch Pull Request.
- **REQ-008**: The Readiness Gap MUST include the current branch, the allowed branches, and remediation instructions.
- **REQ-009**: Terminal Console readiness output MUST show the policy failure.
- **REQ-010**: Web Dashboard readiness output MUST show the policy failure while remaining available.
- **REQ-011**: The policy MUST remain separate from `protectedTrunkBranches`.
- **REQ-012**: A Self-Dogfooding Workspace Repository SHOULD allow only `symphony/dogfood` and keep `main` as a Protected Trunk Branch.
- **CON-001**: The policy MUST NOT automatically change the current Git branch.
- **CON-002**: The policy MUST NOT auto-merge or push anything.
- **GUD-001**: Error text SHOULD use the term Allowed Loop-Start Branch Policy.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

The following shape is the required capability. Final field placement MUST remain inside Git Policy.

```json
{
  "git": {
    "taskBranchPrefix": "symphony/task/",
    "protectedTrunkBranches": ["main"],
    "allowedLoopStartBranches": ["symphony/dogfood"]
  }
}
```

### Readiness Gap Shape

Readiness reporting MUST provide equivalent data even if the internal representation differs.

```json
{
  "kind": "allowed_loop_start_branch_policy",
  "currentBranch": "main",
  "allowedBranches": ["symphony/dogfood"],
  "message": "Current Loop-Start Branch main is not allowed for orchestration.",
  "remediation": "Switch to an allowed Loop-Start Branch or update Runtime Settings."
}
```

## 5. Acceptance Criteria

- **AC-001**: Given Runtime Settings omit the policy, When Symphony starts on any branch, Then readiness behavior matches the current default.
- **AC-002**: Given Runtime Settings allow `symphony/dogfood`, When Symphony starts on `symphony/dogfood`, Then readiness succeeds for this policy.
- **AC-003**: Given Runtime Settings allow `symphony/dogfood`, When Symphony starts on `main`, Then Symphony reports a Readiness Gap and dispatches no work.
- **AC-004**: Given the current Loop-Start Branch is disallowed, When Startup Reconciliation would otherwise integrate a Task Branch, Then no integration occurs.
- **AC-005**: Given the current Loop-Start Branch is disallowed, When the Web Dashboard opens, Then it displays readiness output and remains usable for inspection.
- **AC-006**: Given `main` is a Protected Trunk Branch, When `symphony/dogfood` is allowed, Then Protected Trunk Branch behavior remains unchanged.

## 6. Test Automation Strategy

- **Test Levels**: Unit, backend integration, and optional frontend readiness display tests.
- **Frameworks**: OCaml Alcotest for backend behavior; frontend live-state tests if Web Dashboard state rendering changes.
- **Test Data Management**: Temporary Git repositories with named branches and Runtime Settings fixtures.
- **CI/CD Integration**: Run `pnpm test`; run `pnpm frontend:test` if frontend state rendering changes.
- **Coverage Requirements**: Cover settings parsing, readiness pass, readiness block, Startup Reconciliation block, and Protected Trunk Branch separation.
- **Performance Testing**: Not required.

Required tests:

- Parse omitted, empty, valid, and invalid allowed branch settings.
- Readiness succeeds when the current Loop-Start Branch is allowed.
- Readiness blocks dispatch when the current Loop-Start Branch is not allowed.
- Existing `protectedTrunkBranches` auto-merge behavior remains unchanged.
- A self-dogfooding fixture shows `main` blocked and `symphony/dogfood` allowed.

## 7. Rationale & Context

`protectedTrunkBranches` prevents automated Task Branch Integration into protected trunks, but it does not prevent orchestration from starting on a branch where task dispatch should not happen. A Self-Dogfooding Workspace Repository needs a stronger readiness gate so dogfood work starts from a dedicated integration branch rather than from the Product Repository trunk.

The policy should default to no restriction to preserve existing Workspace Repositories and Bootstrap behavior.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Git - Provides the current local branch name.

### Third-Party Services

- **SVC-001**: GitHub Projects - Dispatch status movement must not occur when the policy blocks readiness.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Settings and Runtime State.

### Data Dependencies

- **DAT-001**: Runtime Settings Git Policy - Source of allowed branch names.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Performs readiness validation and orchestration gating.

### Compliance Dependencies

- **COM-001**: ADR coverage - Runtime semantic changes require an ADR.

## 9. Examples & Edge Cases

```json
{
  "currentBranch": "feature/manual-test",
  "allowedLoopStartBranches": ["symphony/dogfood"],
  "result": "readiness_gap"
}
```

Edge cases:

- Detached HEAD: report a Readiness Gap because there is no valid Loop-Start Branch name.
- Missing Git repository: preserve existing root validation behavior.
- Remote-qualified names such as `origin/main`: reject or normalize only if an ADR defines that behavior.
- Whitespace-only branch names in settings: treat Runtime Settings as invalid.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- Readiness output is visible in Terminal Console and Web Dashboard.
- Dispatch, status movement, Startup Reconciliation integration, and Batch Pull Request creation are blocked on a disallowed Loop-Start Branch.
- Existing default behavior remains unchanged when the policy is absent.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #30](https://github.com/MatheusBBarni/symphony-orchestrator/issues/30)
- [ADR directory](../docs/adr/)
