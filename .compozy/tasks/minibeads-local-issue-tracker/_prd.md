# PRD: minibeads Local Issue Tracker

## Overview

Personal Symphony should support minibeads as a first-class Local Issue Tracker for Workspace Repository operators who do not want to use GitHub Issues, GitHub Projects, or GitHub API access.

V1 must let an operator select minibeads in Runtime Settings, run Symphony from Local Issue Files, inspect local work clearly, and complete at least one full GitHub-free orchestration loop. GitHub remains the default Issue Tracker, but minibeads should be documented and presented as an equal explicit option.

## Goals

- Enable a complete GitHub-free local run from one active Local Issue File through dispatch, progress, completion, and persisted local status.
- Make local tracker setup understandable through a clear `settings.json` property and documentation.
- Give operators enough visibility to trust local work: issue state, blockers, errors, queue progress, and current activity.
- Preserve core local issue metadata that helps agent/operator coordination: labels, comments or notes, task links, and priority.
- Keep existing GitHub Tracker behavior unchanged for users who do not opt into minibeads.

## User Stories

- As an agent operator, I want to run Symphony from local issue records so that I can dispatch work without GitHub.
- As an agent operator, I want to see local issue state, blockers, errors, and queue progress so that I can understand why work is or is not moving.
- As a local-first developer, I want issue records to live in the Workspace Repository so that work context is reviewable in normal repository diffs.
- As a maintainer, I want GitHub to remain the default so that existing Workspace Repositories do not change behavior.
- As a self-dogfooding operator, I want labels, notes, links, and priority to appear in the orchestration workflow so that local issues remain useful for real task coordination.

## Core Features

| # | Feature | Priority | Product Requirement |
| --- | --- | --- | --- |
| F1 | Tracker selection | Critical | Operators can select minibeads through Runtime Settings while GitHub remains the default when no local tracker is selected. |
| F2 | GitHub-free readiness | Critical | A minibeads run does not require GitHub owner, repo, project number, or token settings. Missing local tracker requirements produce actionable readiness guidance. |
| F3 | Local issue dispatch | Critical | Active Local Issue Files can enter the same Symphony agent/operator loop used by GitHub issues. |
| F4 | Local status persistence | Critical | Symphony-visible status changes are reflected back into the selected Local Issue File so restart and inspection preserve task state. |
| F5 | Blocker visibility | Critical | Local issue blockers prevent dispatch and are visible to the operator with clear explanations. |
| F6 | Operator visibility | High | Terminal Console and Web Dashboard show local issue state, queue progress, running work, retrying work, and attention conditions without GitHub-specific wording. |
| F7 | Local metadata support | High | Labels, comments or notes, task links, and priority are visible where they help operators understand or select work. |
| F8 | First-class documentation | High | Documentation explains GitHub and minibeads as supported Issue Tracker choices, including when to choose each. |
| F9 | GitHub compatibility | Critical | Existing GitHub Tracker users keep the same defaults, setup expectations, and behavior. |

## User Experience

An operator starts in a Workspace Repository and chooses the Local Issue Tracker in Runtime Settings. The setup documentation explains that GitHub is still the default, while minibeads is the local-first option for users who want issue records in repository files.

After setup, the operator can run Symphony without GitHub credentials. If local tracker requirements are missing, Symphony reports Readiness Gaps with concrete remediation. If local issues are malformed, blocked, duplicated, or unsupported, Symphony explains the problem instead of launching unclear agent work.

During a run, the operator can inspect local issues in the Terminal Console and Web Dashboard. The visible experience should answer: what work exists, what is running, what is blocked, what needs attention, what is queued, and what status Symphony last wrote.

A successful V1 experience ends with one local issue completing the orchestration loop and leaving local status durable enough for restart, review, and follow-up work.

## High-Level Technical Constraints

- The feature must use the existing product language: Workspace Repository, Runtime Home, Runtime Contract, Runtime Settings, Issue Tracker, GitHub Tracker, Local Issue Tracker, Local Issue File, Runtime State, Ordered Queue, and Manual Task Merge.
- GitHub Tracker behavior must remain the default and must not require migration.
- minibeads must not require GitHub API access, GitHub Projects access, or GitHub token configuration.
- Local Issue Files are repository-owned user data and must not be overwritten during Bootstrap.
- Local tracker state changes must not obscure or accidentally mix with unrelated agent work.
- Documentation and examples must not include secret values.

## Non-Goals

- Replacing the GitHub Tracker as the default.
- Syncing Local Issue Files to GitHub Issues or GitHub Projects.
- Supporting upstream Beads storage models in V1.
- Building a general-purpose Jira, Linear, or GitHub Projects replacement.
- Changing Task Branch cleanup, auto-merge defaults, Stage Push behavior, or packaged binary behavior.
- Requiring users to adopt minibeads if their current GitHub workflow works.

## Phased Rollout Plan

### MVP (Phase 1)

- Add visible tracker choice for GitHub vs minibeads.
- Support one end-to-end GitHub-free run from an active Local Issue File.
- Show local readiness, blockers, running work, errors, and final status clearly.
- Preserve GitHub default behavior.

Success criteria: one local issue dispatches, progresses, finishes, and persists status with no GitHub settings or token.

### Phase 2

- Expand local queue workflows for multiple issues.
- Improve list/filter views for state, blockers, labels, priority, and attention.
- Improve documentation for choosing GitHub or minibeads.

Success criteria: an operator can run a multi-issue local queue and understand progress without reading source code.

### Phase 3

- Refine local metadata workflows around notes, task links, and review context.
- Explore a local execution ledger for durable agent attempts and verification evidence.

Success criteria: local issues become a reliable day-to-day issue source for agent/operator workflows.

## Success Metrics

| Metric | Target |
| --- | --- |
| GitHub-free run completion | 1 active Local Issue File can dispatch, progress, finish, and persist status without GitHub settings or token. |
| GitHub default regression | 0 intentional behavior changes for existing GitHub Tracker users. |
| Readiness clarity | 100% of missing local tracker prerequisites produce actionable Readiness Gaps. |
| Operator visibility | Local issue state, blockers, running work, retrying work, queue progress, and attention conditions are visible in Runtime State-backed surfaces. |
| Metadata usefulness | Labels, notes/comments, task links, and priority are available where operators inspect or select local work. |
| Documentation completeness | Setup docs explain the `settings.json` tracker choice and when to choose GitHub vs minibeads. |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| V1 becomes a broad project-management tool | Keep every V1 feature tied to Symphony orchestration and operator visibility. |
| Users misunderstand minibeads as replacing GitHub | Document GitHub as default and minibeads as an explicit first-class option. |
| Local tracker feels technically functional but hard to operate | Require visible state, blockers, errors, and queue progress in V1. |
| Rich metadata delays the core local run | Preserve metadata only where it helps task selection, prompt context, or operator inspection. |
| GitHub users worry about churn | Preserve defaults and communicate that minibeads is opt-in. |

## Architecture Decision Records

- [ADR-001: Scope minibeads as an opt-in local tracker adapter](adrs/adr-001.md) — V1 uses minibeads as an opt-in Local Issue Tracker for Symphony's existing orchestration model.
- [ADR-002: Prioritize a first-class local tracker experience for V1](adrs/adr-002.md) — V1 emphasizes visible, documented, operator-usable local tracking, not only backend dispatch.

## Open Questions

- What exact local comments or notes shape should V1 expose to operators?
- Which task links are required in V1: local paths, branch names, commit references, pull request links, or a smaller set?
- How much list/filter capability belongs in Terminal Console versus Web Dashboard for the first release?
- What wording should documentation use to compare GitHub Tracker and Local Issue Tracker choices?
