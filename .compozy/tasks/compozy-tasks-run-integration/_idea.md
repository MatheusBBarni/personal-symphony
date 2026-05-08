# Compozy Tasks Run Integration

## Overview

Personal Symphony should support a Compozy-backed **Local Issue Tracker** that uses Compozy task files under `.compozy/tasks/<slug>/task_NN.md` as **Local Issue Files** for the main orchestration lifecycle.

The feature is for a Symphony operator who wants Compozy-generated task files to drive dispatch, **Stage Agent** selection, **Agent Prompt** rendering, **Task Branch** naming, retry behavior, status transitions, and **Runtime State** without depending on GitHub Issues, GitHub Projects, or GitHub API access.

V1 should be a quick win: prove one reliable Compozy-backed local task lifecycle while keeping the **GitHub Tracker** as the default **Issue Tracker**.

## Problem

Personal Symphony currently treats GitHub Issues as issue records and GitHub Projects as the dispatch board. That works for GitHub-centered workflows, but it creates unnecessary setup for operators already using Compozy artifacts inside the **Workspace Repository**.

Compozy already produces structured task files with frontmatter such as `status`, `title`, `type`, `complexity`, and `dependencies`. Those files are versioned, local, reviewable, and close to the shape Symphony needs for a **Local Issue File**. Today, Symphony cannot use them as the issue source.

The core problem is not project management breadth. The problem is that Compozy tasks are executable planning artifacts, but Symphony still needs a separate external tracker to run them through its orchestration loop.

### Market Data

- GitHub reported 180M+ developers and 630M projects in Octoverse 2025, confirming GitHub remains the dominant developer workflow surface.
- Stack Overflow's 2025 survey reported 84% of respondents use or plan to use AI tools, while only 17% of AI-agent users agree agents improved team collaboration.
- ResearchAndMarkets estimates project management software at $9.14B in 2025 and $10.51B in 2026.
- Local and agent-native task tools such as Compozy, Termlings, Tokanban, Task Master, MDTASK, and TICK.md validate demand for repository-owned or agent-readable task state.
- GitHub's agent delegation surfaces show that task trackers are becoming agent launch surfaces, but not all agent work naturally starts as a GitHub Issue.

### Summary / Differentiator

The differentiator is not local markdown alone. The differentiator is that a Compozy task file can become executable by Symphony: dispatchable, status-aware, branch-backed, restart-safe, and visible in **Runtime State** without GitHub API access.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Opt-in Compozy tracker selection | Critical | **Runtime Settings** can select a Compozy-backed **Local Issue Tracker** while the **GitHub Tracker** remains the default. |
| F2 | Compozy task ingestion | Critical | Symphony reads valid Compozy task files and maps them into the internal issue shape needed for prompt rendering, stage selection, and runtime state. |
| F3 | Stable task identity | Critical | V1 defines unique Compozy-backed issue identifiers that cannot collide across workflows containing the same `task_NN.md` names. |
| F4 | Main lifecycle status transitions | Critical | Symphony persists dispatch, retry, success, **Human Attention Status**, and **Merge Attention Status** transitions for selected Compozy task files. |
| F5 | Dependency-aware dispatch | High | Compozy task dependencies prevent dispatch until blockers are terminal or otherwise satisfied by the selected tracker semantics. |
| F6 | Ordered Queue support | High | **Ordered Queue** entries can reference Compozy-backed issue identifiers when the Compozy tracker is selected. |
| F7 | Runtime State visibility | High | Terminal and **Web Dashboard** state show Compozy-backed issues, running work, retrying work, errors, blockers, and status order without GitHub-specific wording. |
| F8 | GitHub regression protection | Critical | Existing GitHub defaults, readiness gaps, status updates, and orchestration behavior continue unchanged. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Runtime Settings | Add an opt-in Compozy tracker mode without changing Bootstrap defaults. |
| Issue Tracker boundary | Reuse the existing Local Issue Tracker direction instead of wiring Compozy files directly into orchestration. |
| Orchestrator | Feed Compozy-backed issues into the existing dispatch, retry, completion, and status-transition lifecycle. |
| Ordered Queue | Validate Compozy-backed identifiers against the selected **Issue Tracker**. |
| Task Branch naming | Use stable Compozy-backed identifiers rather than raw `task_01` filenames. |
| Runtime State | Surface tracker-neutral issue state for dashboard and terminal inspection. |
| Agent Prompt | Render Compozy task title, body, labels/type, dependencies, and status context as issue context. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| GitHub-free lifecycle completion | 1 Compozy task dispatches, runs, finishes, and persists status with 0 GitHub settings or token | Run a fixture Workspace Repository with Compozy tracker selected and no GitHub credentials. |
| Setup time | < 5 minutes from configured Workspace Repository to ready state | Time a fresh local setup using documented Runtime Settings. |
| Status durability | 100% of dispatch, retry, success, and attention transitions persist idempotently | Repeat status transitions in backend tests and compare task file/state output. |
| Identifier reliability | 0 collisions across at least 2 workflows that both contain `task_01.md` | Fixture test with multiple `.compozy/tasks/<slug>/` directories. |
| GitHub regression control | 0 existing GitHub Tracker behavior regressions | Existing backend tracker and orchestrator tests pass unchanged. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win.

## Council Insights

- **Recommended approach:** Build a narrow Compozy-backed **Local Issue Tracker** for Symphony's existing main lifecycle. Keep GitHub as the default and avoid broader project-management scope.
- **Key trade-offs:** A direct file-reader path is faster but risks duplicating GitHub-shaped orchestration behavior. A full shared tracker platform is cleaner but too large for the chosen V1.
- **Risks identified:** Raw Compozy task files are untrusted Workspace Repository input; task identifiers can collide across workflows; status writes can pollute unrelated work; a shallow adapter can hide GitHub assumptions.
- **Stretch goal (V2+):** A richer local execution ledger that links Compozy tasks, Symphony attempts, verification evidence, branches, commits, and review outcomes.

## Out of Scope (V1)

- **Replacing the GitHub Tracker default** — Existing Workspace Repositories must keep current behavior unless they explicitly select the Compozy tracker.
- **Changing Runtime Contract defaults** — Bootstrap defaults in `runtime_home.ml` are not part of this quick-win scope.
- **Building full project-management views** — Assignment, comments, history, cross-workflow planning, and advanced filters are deferred.
- **Two-way sync with GitHub, Linear, or Jira** — V1 removes the external tracker dependency instead of adding sync complexity.
- **Changing Task Branch cleanup or auto-merge defaults** — Tracker storage must not change branch integration semantics.
- **Executing arbitrary Compozy workflow behavior** — V1 treats Compozy task files as issue records, not as a replacement for Compozy's runner.

## Architecture Decision Records

- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — V1 uses Compozy task files as an opt-in Local Issue Tracker adapter for Symphony's existing lifecycle.

## Open Questions

- What exact Compozy-backed issue identifier format should V1 use: `<slug>#task_01`, `<slug>/task_01`, canonical path, or another stable form?
- Should status writes update task file frontmatter directly, a Compozy-managed state surface, or both?
- Which Compozy dependency values map to non-dispatchable blockers in V1?
- Should V1 support only one selected workflow slug or discover all `.compozy/tasks/<slug>/` workflows?
- Should Compozy task metadata such as `type` map to labels, stage selection hints, or remain display-only in V1?
