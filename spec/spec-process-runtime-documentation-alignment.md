---
title: Runtime Documentation Alignment
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, documentation, runtime-contract, issue-26]
---

# Introduction

This specification defines the documentation alignment work needed for Personal Symphony. The goal is to make public and repository documentation match the current Runtime Contract under `.symphony/` and reduce legacy `WORKFLOW.md` ambiguity.

Source issue: [#26 Improve README and documentation](https://github.com/MatheusBBarni/symphony-orchestrator/issues/26).

## 1. Purpose & Scope

This specification applies to `README.md`, `.github/project-tracking.md`, and supporting documentation under `docs/`. It is a documentation alignment specification, not a broad rewrite.

The intended audience is maintainers, users installing the CLI Package, contributors developing the Product Repository, and future agents editing documentation.

Out of scope:

- Changing runtime behavior.
- Replacing the GitHub Issues + Projects tracker model.
- Removing fixture or import compatibility references that intentionally mention legacy `WORKFLOW.md`.

## 2. Definitions

- **Product Repository**: The repository that contains the Personal Symphony source code.
- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Runtime Home**: The `.symphony/` directory in a Workspace Repository.
- **Runtime Contract**: The repository-owned files inside the Runtime Home that define Personal Symphony behavior.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Local Environment**: The ignored `.symphony/.env` file that stores local secret values.
- **Bootstrap**: The first-time setup of Personal Symphony runtime files inside a Workspace Repository.
- **Idempotent Bootstrap**: Bootstrap behavior that creates missing Runtime Home files without overwriting user-edited files.
- **Loop-Start Branch**: The Workspace Repository branch checked out when orchestration starts.
- **Protected Trunk Branch**: A configured branch that Symphony must not auto-merge task work into.
- **Batch Pull Request**: A pull request opened from the Loop-Start Branch after Orchestration Idle.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: `README.md` MUST explain the current user path: install the CLI Package, run Bootstrap from a Workspace Repository root, configure Runtime Settings, store secrets only in Local Environment, and run Symphony.
- **REQ-002**: `README.md` MUST describe Runtime Home files created by Bootstrap and state that Bootstrap is idempotent.
- **REQ-003**: `README.md` MUST document current Runtime Settings sections for tracker, project statuses, Stage Agents, Git Policy, Stage Commit, Stage Push, Pull Request Policy, and Web Dashboard startup.
- **REQ-004**: `.github/project-tracking.md` MUST describe GitHub Issues + Projects through Runtime Settings, not legacy `WORKFLOW.md`.
- **REQ-005**: Product Repository development documentation MUST remain separate from Workspace Repository operation documentation.
- **REQ-006**: Product Repository development documentation MUST include the established commands for dependency installation, backend tests, frontend live-state tests, frontend build, backend build, and package payload build.
- **REQ-007**: Release documentation MUST mention the packaged binary and npm export workflow without encouraging routine edits to package-sensitive files.
- **REQ-008**: Documentation MUST use glossary terms from `CONTEXT.md` consistently.
- **REQ-009**: Documentation MUST limit `WORKFLOW.md` references to intentional legacy, fixture, or import compatibility contexts.
- **SEC-001**: Documentation MUST mention only secret variable names such as `GITHUB_TOKEN` and `GH_TOKEN`; it MUST NOT contain token values.
- **CON-001**: Documentation MUST NOT describe `.symphony/.gitignore` as a repository-owned protected path policy.
- **CON-002**: Documentation MUST NOT use ambiguous terms such as `project`, `config`, `base branch`, or `main branch` when a glossary term is available.
- **GUD-001**: Self-Dogfooding Workspace Repository notes SHOULD use the glossary terms Runtime Contract, Loop-Start Branch, Protected Trunk Branch, Batch Pull Request, Stage Commit, Stage Push, and Human Attention Status.

## 4. Interfaces & Data Contracts

### Documentation Surfaces

| File | Required role |
| --- | --- |
| `README.md` | Primary user and contributor documentation. |
| `.github/project-tracking.md` | GitHub Issues + Projects tracker configuration documentation. |
| `docs/` | Architecture, decisions, and supporting operational documentation. |

### Command Contract

Documentation that describes Product Repository development MUST use these commands exactly unless the command behavior changes:

```text
pnpm install
pnpm test
pnpm frontend:test
pnpm frontend:build
pnpm backend:build
pnpm prepack
pnpm backend:dev
pnpm frontend:dev
```

### Secret Example Contract

Allowed:

```text
GITHUB_TOKEN
GH_TOKEN
```

Not allowed:

```text
token-looking literal values
```

## 5. Acceptance Criteria

- **AC-001**: Given a new user reading `README.md`, When they follow the documented path, Then they can distinguish Product Repository development from Workspace Repository operation.
- **AC-002**: Given Bootstrap documentation, When it describes Runtime Home files, Then it states that user-edited Runtime Contract and Local Environment files are not overwritten.
- **AC-003**: Given tracker documentation, When it references active runtime configuration, Then it points to Runtime Settings instead of legacy `WORKFLOW.md`.
- **AC-004**: Given release documentation, When it describes package export, Then it mentions the packaged binary and npm export workflow without exposing secret values.
- **AC-005**: Given a glossary term exists in `CONTEXT.md`, When documentation describes that concept, Then it uses the glossary term.

## 6. Test Automation Strategy

- **Test Levels**: Documentation verification and targeted command checks.
- **Frameworks**: Shell `rg` checks and repository package scripts.
- **Test Data Management**: Use repository documentation files as source data.
- **CI/CD Integration**: Documentation checks may be added to CI when stable.
- **Coverage Requirements**: Cover legacy references, secret examples, and command examples.
- **Performance Testing**: Not applicable.

Required verification:

```sh
rg "WORKFLOW.md|WORKFLOW.example.md" README.md .github/project-tracking.md docs
rg "GITHUB_TOKEN|GH_TOKEN|github_pat_" README.md .github docs
```

If documentation changes command behavior examples, run the smallest relevant command check:

```sh
pnpm backend:build
pnpm frontend:build
```

## 7. Rationale & Context

The current domain model has moved from legacy `WORKFLOW.md` language to a Runtime Contract under `.symphony/`. Documentation must follow that product language so users, maintainers, and agents do not conflate Product Repository source code with Workspace Repository runtime operation.

This work should be narrow. The issue identifies missing information, and the refinement clarifies that the needed outcome is alignment, not a full marketing rewrite or new runtime design.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - The active tracker model described by documentation.

### Third-Party Services

- **SVC-001**: npm - Distribution channel for the CLI Package.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Documentation must describe `.symphony/` contents accurately.
- **INF-002**: Packaged binary workflow - Documentation must describe package export behavior accurately.

### Data Dependencies

- **DAT-001**: `CONTEXT.md` glossary - Source of accepted product terminology.

### Technology Platform Dependencies

- **PLT-001**: pnpm scripts - Source of Product Repository development commands.

### Compliance Dependencies

- **COM-001**: Secret handling - Documentation must not include token values.

## 9. Examples & Edge Cases

```md
Use **Workspace Repository** when describing where a user runs `symphony`.
Use **Product Repository** when describing this source repository.
Do not use "project" when either term is more precise.
```

Edge cases:

- A fixture intentionally imports legacy `WORKFLOW.md`: keep the reference and mark it as compatibility.
- A docs page describes pull request targeting: use **Pull Request Base Branch** for the target and **Loop-Start Branch** for the head.
- A command example mentions GitHub authentication: use only environment variable names.

## 10. Validation Criteria

- Legacy `WORKFLOW.md` references are intentional and explained.
- Secret scans find variable names only and no token-looking values.
- Documentation uses `CONTEXT.md` terms consistently.
- Relevant build checks pass when command examples or build behavior documentation changes.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #26](https://github.com/MatheusBBarni/symphony-orchestrator/issues/26)
- [README.md](../README.md)
- [.github/project-tracking.md](../.github/project-tracking.md)
