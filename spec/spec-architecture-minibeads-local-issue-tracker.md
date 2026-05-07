---
title: minibeads Local Issue Tracker
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Product Repository maintainers
tags: [architecture, runtime-contract, tracker, local-issues, minibeads, issue-68]
---

# Introduction

This specification defines the Runtime Contract and backend architecture required for Personal Symphony to consume minibeads issue records as a Local Issue Tracker.

Source issue: [#68 Research local issue authoring for Symphony dispatch](https://github.com/MatheusBBarni/symphony-orchestrator/issues/68).

## 1. Purpose & Scope

The purpose is to let Workspace Repository operators write issue records locally and have Personal Symphony dispatch them without requiring GitHub Issues, GitHub Projects, or GitHub API access.

This specification applies to Runtime Settings parsing, readiness validation, tracker abstraction, issue fetches, issue lookup, status updates, Agent Prompt rendering, Ordered Queue validation, Manual Task Merge validation, Runtime State, backend tests, and documentation.

In scope:

- Add an opt-in minibeads-backed Local Issue Tracker.
- Preserve the GitHub Tracker as the default Issue Tracker.
- Map minibeads issue records into the existing internal issue shape.
- Update tracker status transitions in minibeads issue records.
- Use minibeads dependency data to determine dispatchable local issue records.
- Keep Stage Agent, Agent Worktree, Task Branch, retry, Stage Commit, Stage Push, Task Branch Integration, Pull Request Policy, and Web Dashboard behavior consistent across tracker kinds.

Out of scope:

- Replacing the GitHub Tracker.
- Synchronizing minibeads records to GitHub Issues.
- Supporting upstream Beads SQLite or JSONL storage in the first local tracker implementation.
- Changing Task Branch cleanup or auto-merge defaults.
- Changing npm package files, `bin/symphony.js`, or packaged-binary behavior.
- Splitting the large backend test file.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Product Repository**: The repository that contains the Personal Symphony source code.
- **Runtime Home**: The `.symphony/` directory that contains Personal Symphony configuration and runtime-owned files for a Workspace Repository.
- **Runtime Contract**: Repository-owned files inside the Runtime Home that define Personal Symphony behavior.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Issue Tracker**: The configured source of Workspace Repository issue records that Personal Symphony polls and updates during orchestration.
- **GitHub Tracker**: An Issue Tracker that uses GitHub Issues as issue records and GitHub Projects status values as dispatch state.
- **Local Issue Tracker**: An Issue Tracker whose issue records live as repository-owned local files inside the Workspace Repository and can be consumed without GitHub API access.
- **Local Issue File**: A human-editable issue record stored by a Local Issue Tracker and used by Personal Symphony to render an Agent Prompt, select a Stage Agent, and update tracker status.
- **minibeads**: A Markdown-based issue tracker whose `mb` command stores issue records under `.beads/issues/` with YAML frontmatter.
- **Stage Agent**: A Runtime Settings mapping from project statuses to a named agent instruction file, Agent Harness selection, and optional stage behavior.
- **Agent Prompt**: The `prompt.md` Runtime Contract content rendered with issue and stage context for a dispatched task.
- **Agent Worktree**: An Agent Workspace backed by a Git worktree for one dispatched task.
- **Task Branch**: A Git branch created from the Loop-Start Branch for one dispatched task.
- **Readiness Gap**: A missing or invalid runtime requirement that prevents dispatch while still allowing operator inspection.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime Settings MUST support `tracker.kind: "minibeads"` as an opt-in Local Issue Tracker.
- **REQ-002**: Runtime Settings MUST preserve `tracker.kind: "github"` as the default Issue Tracker.
- **REQ-003**: The backend MUST introduce a tracker abstraction that covers candidate fetches, issue lookup by identifier, status updates, readiness checks, terminal-state checks, active-state checks, and tracker-specific retry behavior.
- **REQ-004**: The minibeads Local Issue Tracker MUST use the Workspace Repository root as its discovery boundary.
- **REQ-005**: The minibeads Local Issue Tracker MUST treat `.beads/issues/*.md` records as the issue source.
- **REQ-006**: The minibeads Local Issue Tracker MUST map minibeads issue fields into the existing internal issue shape: `id`, `identifier`, `title`, `description`, `labels`, `priority`, `state`, `blocked_by`, `created_at`, `updated_at`, and optional `url`.
- **REQ-007**: The minibeads Local Issue Tracker MUST use the Local Issue File identifier as the stable identifier for Ordered Queue entries, Runtime State, diagnostics, and Task Branch naming.
- **REQ-008**: The minibeads Local Issue Tracker MUST update Local Issue File status when Symphony applies dispatch, success, retry, Human Attention Status, or Merge Attention Status transitions.
- **REQ-009**: minibeads dependency records of type `blocks` MUST make an issue non-dispatchable while any blocking dependency is not terminal.
- **REQ-010**: Runtime Settings project states MUST remain the canonical Symphony stage selection and transition vocabulary.
- **REQ-011**: The implementation MUST define deterministic status mapping between minibeads status values and Runtime Settings state values.
- **REQ-012**: Missing minibeads installation, missing `.beads/`, unreadable issue files, invalid frontmatter, unsupported status values, duplicate identifiers, and dependency cycles MUST surface as Readiness Gaps or issue-level non-dispatchable reasons.
- **REQ-013**: The Web Dashboard and Terminal Console MUST continue exposing issues, running work, retrying work, and issue errors through Runtime State without GitHub-specific wording for local tracker runs.
- **REQ-014**: Manual Task Merge MUST accept local issue identifiers when the minibeads Local Issue Tracker is selected.
- **REQ-015**: Ordered Queue validation MUST validate identifiers against the selected Issue Tracker.
- **REQ-016**: Bootstrap MUST NOT overwrite existing `.beads/` content or existing Local Issue Files.
- **CON-001**: The implementation MUST NOT require GitHub API access when `tracker.kind` is `minibeads`.
- **CON-002**: The implementation MUST NOT replace or degrade the GitHub Tracker.
- **CON-003**: The implementation MUST NOT change Task Branch cleanup or auto-merge defaults.
- **CON-004**: The implementation MUST NOT include tracker status churn in unrelated Stage Commits.
- **CON-005**: The first implementation MUST NOT support upstream Beads SQLite or JSONL storage.
- **SEC-001**: Documentation and examples MUST NOT include token values, webhook URLs, or local `.env` contents.
- **GUD-001**: Documentation MUST use Issue Tracker, GitHub Tracker, Local Issue Tracker, and Local Issue File consistently.
- **PAT-001**: Prefer behavior tests around tracker parsing, readiness, status updates, dependency blocking, Ordered Queue validation, Manual Task Merge validation, and orchestration dispatch.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

```json
{
  "tracker": {
    "kind": "minibeads",
    "root": ".beads",
    "command": "mb"
  },
  "project": {
    "activeStates": ["open"],
    "terminalStates": ["closed"],
    "startStatus": "in_progress",
    "reviewStatus": "closed",
    "retryStatus": "open"
  }
}
```

The `root` and `command` fields are local tracker settings. The final implementation may choose different field names, but it MUST keep GitHub-only fields optional and ignored for `tracker.kind: "minibeads"`.

### Local Issue File Shape

```md
---
title: Add local issue dispatch
status: open
priority: 1
issue_type: feature
labels:
  - enhancement
dependencies:
  mb-12: blocks
created_at: 2026-05-07T10:00:00Z
updated_at: 2026-05-07T10:15:00Z
---

# Description

Implement local issue dispatch for Symphony.

# Acceptance Criteria

- [ ] Symphony dispatches this issue from the minibeads Local Issue Tracker.
```

### Internal Issue Mapping

| Internal field | minibeads source | Requirement |
| --- | --- | --- |
| `id` | minibeads issue id | Required |
| `identifier` | minibeads issue id | Required; stable across runs |
| `title` | frontmatter `title` | Required |
| `description` | Markdown body and recognized sections | Optional |
| `labels` | frontmatter `labels` | Optional; normalized consistently with GitHub labels |
| `priority` | frontmatter `priority` | Optional integer |
| `state` | frontmatter `status` mapped to Runtime Settings state | Required |
| `blocked_by` | `dependencies` entries with `blocks` | Optional |
| `created_at` | frontmatter `created_at` | Optional |
| `updated_at` | frontmatter `updated_at` | Optional |
| `url` | absent | `None` for local tracker issues |

### Tracker Abstraction

```text
Tracker.fetch_candidates(config) -> Issue list
Tracker.fetch_by_identifiers(config, identifiers) -> (identifier, Issue option) list
Tracker.update_status(config, issue, status) -> unit result
Tracker.readiness_gaps(config) -> ReadinessGap list
Tracker.is_active(config, status) -> bool
Tracker.is_terminal(config, status) -> bool
```

The concrete OCaml interface may differ, but it MUST remove GitHub-specific types from orchestration boundaries that are shared by all trackers.

## 5. Acceptance Criteria

- **AC-001**: Given Runtime Settings omit `tracker.kind`, When settings load, Then the GitHub Tracker remains selected by default.
- **AC-002**: Given Runtime Settings set `tracker.kind` to `minibeads`, When settings load, Then GitHub-only requirements such as `tracker.owner`, `tracker.repo`, `tracker.projectNumber`, and `tracker.apiKeyEnv` do not produce Readiness Gaps.
- **AC-003**: Given a valid Local Issue File with an active status and no blocking dependencies, When Symphony polls the minibeads Local Issue Tracker, Then the issue appears as a dispatchable candidate.
- **AC-004**: Given a Local Issue File depends on another non-terminal issue with dependency type `blocks`, When Symphony polls candidates, Then the dependent issue is not dispatched.
- **AC-005**: Given a local issue is dispatched, When Symphony applies the start status, Then the selected Local Issue File status is updated idempotently.
- **AC-006**: Given a local issue succeeds, retries, or requires Human Attention Status, When Symphony applies the tracker transition, Then the selected Local Issue File status records the configured transition.
- **AC-007**: Given `.beads/` is missing for `tracker.kind: "minibeads"`, When readiness is evaluated, Then Symphony reports a Readiness Gap that explains how to initialize minibeads.
- **AC-008**: Given a Local Issue File has invalid frontmatter, When readiness is evaluated or candidates are fetched, Then Symphony reports a deterministic issue-level error and does not launch an agent for that issue.
- **AC-009**: Given an Ordered Queue contains local issue identifiers, When the minibeads Local Issue Tracker is selected, Then queue validation resolves those identifiers against Local Issue Files.
- **AC-010**: Given Manual Task Merge receives a local issue identifier, When the minibeads Local Issue Tracker is selected, Then validation uses the Local Issue Tracker and does not require GitHub Project membership.
- **AC-011**: Given a GitHub Tracker Workspace Repository, When this feature ships, Then existing GitHub issue dispatch, status movement, readiness gaps, and tests continue to behave as before.

## 6. Test Automation Strategy

- **Test Levels**: Backend unit tests and integration-style tests with temporary Workspace Repository fixtures.
- **Frameworks**: OCaml Alcotest through `pnpm test`.
- **Test Data Management**: Use temporary `.beads/issues/*.md` files with deterministic frontmatter and dependency graphs. Avoid invoking real GitHub APIs.
- **CI/CD Integration**: Run focused backend tests after tracker abstraction changes; run `pnpm test` before merge.
- **Coverage Requirements**: Cover Runtime Settings parsing, GitHub default preservation, minibeads readiness gaps, Local Issue File parsing, issue mapping, dependency blocking, status writes, Ordered Queue validation, Manual Task Merge validation, and orchestration dispatch.
- **Performance Testing**: Not required for the first implementation. Add regression tests only if candidate polling over local issue files becomes visibly slow.

## 7. Rationale & Context

The existing code uses GitHub-specific tracker functions directly in orchestration, readiness, queue validation, and merge flows. A minibeads Local Issue Tracker requires a real tracker abstraction because the local path must not depend on GitHub repository ownership, project membership, tokens, or GraphQL status metadata.

minibeads is selected over upstream Beads for the first local tracker because its issue records are human-editable Markdown files with YAML frontmatter. That model fits the Workspace Repository ownership model and makes local issue authoring reviewable in normal Git diffs. The trade-off is that Symphony targets minibeads-specific storage first instead of upstream Beads SQLite and JSONL.

Status writes are required in the first implementation because Symphony already treats tracker transitions as part of stage progression. An input-only local tracker would dispatch work but lose retry, review, and attention state after process restart.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Git - Stores Workspace Repository files, Agent Worktrees, Task Branches, and Local Issue Files.
- **EXT-002**: GitHub Issues + Projects - Remains the default GitHub Tracker path.

### Third-Party Services

- **SVC-001**: minibeads CLI - Provides local issue initialization, authoring, status updates, dependency operations, and optional JSON output.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Contract, Runtime State, Agent Workspaces, and Runtime Diagnostics.
- **INF-002**: `.beads/` directory - Stores minibeads Local Issue Files and tracker metadata.

### Data Dependencies

- **DAT-001**: Local Issue Files - Markdown files with YAML frontmatter under the minibeads issue directory.
- **DAT-002**: Runtime Settings project states - Defines Symphony active, terminal, start, review, retry, and attention statuses.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Owns Runtime Settings parsing, readiness validation, tracker abstraction, orchestration, and Runtime State.
- **PLT-002**: Markdown and YAML parsing - Required for deterministic Local Issue File parsing if the implementation reads files directly.
- **PLT-003**: Shell-compatible command execution - Required if the implementation invokes `mb` instead of reading Local Issue Files directly.

### Compliance Dependencies

- **COM-001**: ADR coverage - Required because adding a Local Issue Tracker changes Runtime Contract and tracker runtime semantics.
- **COM-002**: Secret handling - Examples and tests must not include token values or local `.env` contents.

## 9. Examples & Edge Cases

### Dispatchable Local Issue

```md
---
title: Improve dashboard status labels
status: open
priority: 2
issue_type: feature
labels: [frontend]
dependencies: {}
created_at: 2026-05-07T12:00:00Z
updated_at: 2026-05-07T12:00:00Z
---

# Description

Update the Web Dashboard labels for local tracker runs.
```

Expected behavior: the issue is eligible when `open` is in `project.activeStates`.

### Blocked Local Issue

```md
---
title: Run local tracker from dashboard
status: open
priority: 2
issue_type: feature
dependencies:
  mb-42: blocks
created_at: 2026-05-07T12:00:00Z
updated_at: 2026-05-07T12:00:00Z
---

# Description

Expose local tracker controls after backend support exists.
```

Expected behavior: the issue is not dispatchable while `mb-42` is not terminal.

### Edge Cases

- Duplicate identifiers across Local Issue Files: report a Readiness Gap and do not dispatch either issue.
- Unknown dependency identifier: report the dependent issue as non-dispatchable with an issue-level error.
- Unsupported status value: report a Readiness Gap or issue-level error before launch.
- Status write conflict because the Local Issue File changed between fetch and update: retry safely or report Human Attention Status without losing user edits.
- Agent modifies Local Issue Files as part of task work: Protected Path Policy should be considered in the implementation plan to avoid unapproved tracker mutations.

## 10. Validation Criteria

- Runtime Settings with `tracker.kind: "github"` continue to pass existing tests.
- Runtime Settings with `tracker.kind: "minibeads"` do not require GitHub token configuration.
- Local Issue File parsing is deterministic and rejects malformed records with actionable diagnostics.
- Status updates are idempotent and scoped to one selected Local Issue File.
- Dependency blocking prevents dispatch without changing issue status by itself.
- Ordered Queue and Manual Task Merge use the selected Issue Tracker.
- Documentation uses the glossary terms introduced for Issue Tracker, GitHub Tracker, Local Issue Tracker, and Local Issue File.

## 11. Related Specifications / Further Reading

- [ADR 0023: Use minibeads for local issue tracking](../docs/adr/0023-minibeads-local-issue-tracker.md)
- [GitHub Issues + Projects Tracking](../.github/project-tracking.md)
- [minibeads 0.13.1 documentation](https://docs.rs/crate/minibeads/0.13.1)
- [upstream Beads documentation](https://steveyegge.github.io/beads/)
