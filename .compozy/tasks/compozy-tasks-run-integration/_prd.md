# PRD: Compozy Tasks Run Integration

## Overview

Personal Symphony should support a Compozy-backed **Local Issue Tracker** that lets a Symphony operator run a Compozy PRD directory from `.compozy/tasks/<task_name>/` as one user-facing unit of work.

V1 treats the PRD directory as the local issue identity. The task files inside it, such as `task_01.md` and `task_02.md`, execute as ordered steps in the same **Agent Worktree** and **Task Branch**. Each task-step prompt includes the relevant task file plus `_prd.md` and `_techspec.md` context when those files exist.

The goal is tracker replacement confidence for Compozy-driven work: operators can use repository-owned Compozy task artifacts instead of GitHub Issues and GitHub Projects for this workflow, while the **GitHub Tracker** remains the default **Issue Tracker**.

## Goals

- Let a Symphony operator select a Compozy-backed **Local Issue Tracker** without changing existing GitHub defaults.
- Present `.compozy/tasks/<task_name>/` as one user-facing work item with progress across its task files.
- Keep all task files for one PRD run in the same **Agent Worktree** and **Task Branch**.
- Include `_prd.md` and `_techspec.md` context in every task-step prompt when available.
- Persist PRD-run progress and status clearly enough for restart, inspection, retry, and completion.
- Preserve existing GitHub Tracker behavior for Workspace Repositories that do not opt into Compozy-backed local tracking.

## User Stories

- As a Symphony operator, I want to run a Compozy PRD directory as one Symphony work item so that all related task files share one worktree and branch.
- As a Symphony operator, I want each Compozy task-step prompt to include the PRD and TechSpec so that each step keeps the full product and design context.
- As a local-first operator, I want Compozy task artifacts to replace GitHub Issues and GitHub Projects for this workflow so that I can run without GitHub tracker setup.
- As a self-dogfooding maintainer, I want Runtime State to show PRD-run progress so that I can understand which task step is running, blocked, retrying, or complete.
- As an existing GitHub Tracker user, I want no behavior change unless I explicitly select the Compozy-backed tracker.

## Core Features

| # | Feature | Priority | Product Requirement |
| --- | --- | --- | --- |
| F1 | Compozy tracker selection | Critical | Operators can select Compozy-backed local tracking while GitHub remains the default tracker. |
| F2 | PRD-run work item | Critical | Symphony presents `.compozy/tasks/<task_name>/` as the primary unit of work, not each `task_NN.md` file. |
| F3 | Shared worktree lifecycle | Critical | All task files in one PRD run execute in the same Agent Worktree and Task Branch. |
| F4 | Task-step progression | Critical | Symphony shows progress across task files in order, including running, completed, retrying, and attention states. |
| F5 | PRD and TechSpec context | Critical | Each task-step prompt includes `_prd.md` and `_techspec.md` context when those artifacts exist. |
| F6 | Tracker replacement flows | High | Compozy-backed PRD runs work in tracker-facing flows that operators rely on for issue selection and confidence. |
| F7 | Runtime State visibility | High | Terminal and Web Dashboard surfaces show the selected tracker kind, PRD-run status, current task step, and attention conditions without GitHub-specific wording. |
| F8 | GitHub compatibility | Critical | Existing GitHub Tracker defaults, setup expectations, and runtime behavior remain unchanged. |

## User Experience

An operator starts with an existing Compozy workflow directory under `.compozy/tasks/<task_name>/`. That directory contains `_prd.md`, `_techspec.md`, `_tasks.md`, task files, and ADRs.

The operator selects the Compozy-backed Local Issue Tracker in Runtime Settings. Symphony then treats the PRD directory as one local issue record. In operator-facing surfaces, the work item appears as a PRD run with progress across task files.

When the PRD run starts, Symphony creates or reuses one Agent Worktree and one Task Branch for the whole run. Each task file executes as a step inside that same context. The operator can inspect which task file is currently running, which steps are complete, and whether the run needs attention.

A successful V1 experience ends when one PRD run can progress through its Compozy task files in a single worktree, preserve visible status, and avoid GitHub tracker requirements.

## High-Level Technical Constraints

- Use existing product language: **Workspace Repository**, **Runtime Home**, **Runtime Contract**, **Runtime Settings**, **Issue Tracker**, **GitHub Tracker**, **Local Issue Tracker**, **Local Issue File**, **Agent Worktree**, **Task Branch**, **Runtime State**, and **Ordered Queue**.
- Do not change Bootstrap defaults in `runtime_home.ml`.
- Do not replace the GitHub Tracker as the default.
- Do not require GitHub API access, GitHub Projects access, or GitHub token configuration for Compozy-backed tracker runs.
- Do not split one Compozy PRD run across multiple worktrees or Task Branches in V1.
- Do not overwrite user-authored Compozy task artifacts during setup.
- Do not include secret values, webhook URLs, or local `.env` contents in documentation or examples.

## Non-Goals

- Replacing GitHub as the default Issue Tracker.
- Treating every `task_NN.md` file as a separate Symphony issue.
- Building a full project-management interface for assignment, comments, rich history, or cross-workflow planning.
- Syncing Compozy PRD runs to GitHub Issues, Linear, Jira, or other external trackers.
- Changing Task Branch cleanup, auto-merge defaults, Stage Push behavior, or packaged binary behavior.
- Replacing Compozy's own `compozy tasks run` command.
- Supporting arbitrary Compozy workflow execution semantics beyond the PRD-run lifecycle.

## Phased Rollout Plan

### MVP (Phase 1)

- Select Compozy-backed local tracking explicitly.
- Recognize one `.compozy/tasks/<task_name>/` directory as one PRD-run work item.
- Run task files in that PRD directory as ordered steps in one Agent Worktree and Task Branch.
- Include `_prd.md` and `_techspec.md` context in each task-step prompt.
- Show PRD-run progress and current task-step state in Runtime State-backed surfaces.
- Preserve all GitHub Tracker behavior when GitHub remains selected.

Success criteria: one Compozy PRD run completes across its task files in a single worktree without GitHub tracker settings or token.

### Phase 2

- Improve operator controls for selecting, pausing, retrying, and resuming PRD runs.
- Expand visible task-step progress in terminal and Web Dashboard surfaces.
- Improve documentation for choosing GitHub Tracker versus Compozy-backed Local Issue Tracker.
- Clarify how PRD-run completion maps to review, attention, and follow-up workflows.

Success criteria: an operator can run and inspect multiple Compozy PRD runs with clear status and no GitHub tracker dependency.

### Phase 3

- Explore richer local execution history linking PRD runs, task steps, agent attempts, verification evidence, branches, commits, and review outcomes.
- Consider import or export workflows for teams that also need external tracker visibility.
- Evaluate whether Compozy-backed and minibeads-backed local tracking should share more user-facing documentation and controls.

Success criteria: Compozy-backed PRD runs become a dependable day-to-day local tracking workflow for self-dogfooding and local-first operators.

## Success Metrics

| Metric | Target |
| --- | --- |
| PRD-run completion | 1 Compozy PRD run completes all selected task files in one Agent Worktree and Task Branch. |
| GitHub independence | 0 GitHub tracker settings or token values required for a Compozy-backed tracker run. |
| Prompt context completeness | 100% of task-step prompts include the task file plus `_prd.md` and `_techspec.md` when present. |
| Progress clarity | Runtime State identifies the PRD run, current task step, completed steps, and attention state. |
| Worktree continuity | 100% of task files in the PRD run use the same Agent Worktree and Task Branch. |
| GitHub regression control | 0 intentional behavior changes for existing GitHub Tracker users. |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Users expect each Compozy task file to be a separate issue | Name and document the user-facing unit as a PRD run, with task files shown as steps. |
| Long PRD runs make progress feel opaque | Surface current task step, completed step count, and attention state in Runtime State-backed views. |
| Compozy-backed tracking is mistaken for a full project-management replacement | Keep V1 focused on tracker replacement confidence for Symphony execution, not broad planning workflows. |
| GitHub users worry about migration pressure | Keep GitHub as the default and state that Compozy-backed tracking is opt-in. |
| PRD and TechSpec context becomes stale or missing | Show clear readiness or attention messages when expected Compozy artifacts are absent. |
| The feature overlaps with minibeads local tracking | Use the existing Local Issue Tracker vocabulary and distinguish Compozy PRD runs from minibeads issue files in documentation. |

## Architecture Decision Records

- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — V1 uses Compozy task files through an opt-in Local Issue Tracker adapter instead of a direct special path.
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — V1 presents `.compozy/tasks/<task_name>/` as one work item whose task files run in the same worktree.

## Open Questions

- Exact completion behavior when one task step succeeds but a later task step needs attention.
- Exact user-facing wording for PRD-run status versus task-step status.
- Whether V1 runs every pending `task_NN.md` by default or supports an operator-selected subset.
- How PRD-run review handoff should appear after all task steps complete.
