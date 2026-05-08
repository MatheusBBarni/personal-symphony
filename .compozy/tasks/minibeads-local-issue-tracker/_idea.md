# minibeads Local Issue Tracker

## Overview

Personal Symphony should support a minibeads-backed Local Issue Tracker for Workspace Repository operators who do not want to use GitHub Issues, GitHub Projects, or GitHub API access.

The feature is for agent/operator workflows where local issue records drive Stage Agent selection, Agent Prompt rendering, Agent Worktree creation, Task Branch naming, retry behavior, Stage Commit, Stage Push, and Task Branch Integration. V1 should be a complete local tracker experience for this loop: issue lifecycle, labels, comments or notes, task links, and list/filter views.

The GitHub Tracker remains the default Issue Tracker. minibeads is opt-in and must not replace or degrade existing GitHub behavior.

## Problem

Personal Symphony currently treats GitHub Issues as issue records and GitHub Projects as the dispatch board. That works for GitHub-centered teams, but it creates friction for users who do not want GitHub in the orchestration path. These users may be working offline, using a private repository without hosted issue tracking, avoiding token setup, or running agent/operator workflows where the issue source should live in the Workspace Repository.

The current GitHub dependency also makes the first run heavier than the core product requires. A user must configure GitHub owner, repository, project number, project statuses, and token access before Symphony can consume work. For local-first workflows, that setup is unnecessary overhead: the work item, prompt context, dependencies, and status should be reviewable as repository-owned files.

minibeads fits this gap because it stores issue records as Markdown files with YAML frontmatter under `.beads/issues/`, supports dependency-aware ready work, and is designed for AI agent workflows. Symphony can turn those Local Issue Files into executable orchestration inputs without requiring a remote tracker.

### Market Data

- GitHub remains the dominant developer platform; GitHub Octoverse 2025 reported more than 180 million developers, 630 million projects, and 43.2 million merged pull requests per month.
- Linear reports that coding agents are installed in more than 75% of enterprise workspaces and author nearly 25% of new issues, showing that issue tracking is becoming an agent workflow surface.
- Local Markdown trackers such as minibeads, issy, and flowtorio validate demand for repo-local, account-free, offline issue tracking.
- Beads validates dependency-aware local issue tracking, but its SQLite plus JSONL model is heavier than minibeads' direct Markdown file model for Symphony's Workspace Repository contract.

### Summary / Differentiator

The differentiator is not "local issue files" by themselves. The differentiator is that a Local Issue File becomes executable by Symphony: it can drive dispatch, prompt rendering, status transitions, retries, branch work, commits, pushes, and integration without GitHub API access.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Opt-in minibeads tracker selection | Critical | Runtime Settings can select minibeads as the Issue Tracker while GitHub remains the default. GitHub-only fields and tokens are not required for local tracker runs. |
| F2 | Local Issue File ingestion | Critical | Symphony reads `.beads/issues/*.md`, validates frontmatter and Markdown, maps fields into the internal issue shape, and reports malformed files as diagnostics rather than launching agents. |
| F3 | Lifecycle and status transitions | Critical | Local issue statuses map to Runtime Settings states, and Symphony writes dispatch, success, retry, Human Attention Status, and Merge Attention Status transitions back idempotently. |
| F4 | Dependency-aware dispatch | Critical | minibeads blocking dependencies prevent dispatch until blockers reach terminal states. Ready local work is eligible for the normal Stage Agent pipeline. |
| F5 | Agent/operator metadata | High | Labels, comments or notes, task links, and priority are preserved for prompts, Runtime State, and operator inspection where they affect the orchestration loop. |
| F6 | List and filter views | High | Terminal Console and Web Dashboard expose local issues in list/filter workflows suitable for selecting, inspecting, and monitoring local work. |
| F7 | Ordered Queue and Manual Task Merge support | High | Local issue identifiers work in Ordered Queue validation and Manual Task Merge when minibeads is the selected Issue Tracker. |
| F8 | GitHub regression protection | Critical | Existing GitHub Tracker behavior, tests, defaults, readiness checks, and status updates continue to work unchanged. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Runtime Settings | Add opt-in tracker selection for minibeads without changing GitHub defaults. |
| Issue Tracker boundary | Normalize GitHub and minibeads behavior through one Symphony issue contract. |
| Orchestrator | Replace GitHub-specific orchestration dependencies with selected-tracker operations. |
| Ordered Queue | Validate local issue identifiers against Local Issue Files instead of GitHub Project membership. |
| Manual Task Merge | Resolve selected local issue identifiers through the Local Issue Tracker. |
| Runtime State | Surface local issue status, labels, blockers, notes, links, and diagnostics without GitHub-specific wording. |
| Web Dashboard | Support local tracker list/filter inspection in addition to existing board-style status views. |
| Agent Prompt | Render local issue title, body, comments/notes, labels, task links, blockers, and status context. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Local tracker setup success | >= 90% of first-time minibeads runs reach ready state or actionable Readiness Gap within 5 minutes | Time a fresh Workspace Repository setup with `tracker.kind: "minibeads"` and record readiness outcome. |
| Dispatch parity | 100% of covered Stage Agent, retry, Stage Commit, Stage Push, and Task Branch Integration tests pass for local issues | Backend test suite with minibeads fixtures for the full local issue lifecycle. |
| GitHub independence | 0 GitHub token, owner, repo, or project-number requirements during minibeads runs | Readiness tests and runtime smoke tests with all GitHub settings omitted. |
| Diagnostic clarity | 100% of malformed, duplicate, blocked, or unsupported local issues produce deterministic diagnostics | Fixture tests for invalid frontmatter, duplicate identifiers, unsupported statuses, and dependency blockers. |
| Status durability | 100% of configured tracker transitions persist idempotently to the selected Local Issue File | Status-write tests that repeat transitions and compare file output. |
| GitHub regression control | 0 existing GitHub Tracker behavior regressions | Existing backend tracker/orchestrator tests pass unchanged. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Must do |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet.

## Council Insights

- **Recommended approach:** Build minibeads as an opt-in Local Issue Tracker adapter that preserves one Symphony orchestration model. V1 should be complete enough for the selected agent/operator workflow, but every feature must support the GitHub-free orchestration loop.
- **Key trade-offs:** A minimal dispatch proof would be faster but too thin for real operator evaluation. A full local project-management platform would create long-term semantic drift. The chosen path is a complete local tracker for Symphony dispatch, not a generic tracker product.
- **Risks identified:** Local Issue Files are untrusted repository input; mitigate with strict parsing, path containment, identifier sanitization, deterministic writes, and no execution from issue text. Tracker status churn can pollute Stage Commits; mitigate by defining write locations and commit exclusions.
- **Stretch goal (V2+):** A local execution ledger that records issue state, agent attempts, verification evidence, task links, and status history as a durable repo-local audit trail.

## Out of Scope (V1)

- **Replacing the GitHub Tracker** — GitHub remains the default Issue Tracker and existing GitHub behavior must continue unchanged.
- **Syncing local issues to GitHub Issues** — V1 is a GitHub alternative, not a bidirectional sync feature.
- **Supporting upstream Beads SQLite or JSONL storage** — minibeads Markdown files are the selected local storage model.
- **Changing Runtime Contract defaults** — Defaults in `runtime_home.ml` require separate approval and are not part of this idea.
- **Changing Task Branch cleanup or auto-merge defaults** — The Local Issue Tracker must preserve existing Task Branch behavior.
- **Building a general-purpose project-management platform** — V1 supports Symphony orchestration, not broad Jira/Linear replacement semantics.
- **Overwriting existing `.beads/` content during Bootstrap** — Bootstrap may only create missing files if local tracker setup is explicitly selected in future work.

## Architecture Decision Records

- [ADR-001: Scope minibeads as an opt-in local tracker adapter](adrs/adr-001.md) — V1 uses minibeads as an opt-in Local Issue Tracker adapter for Symphony's existing orchestration model.

## Open Questions

- Should Local Issue File status writes happen only from the Loop-Start Branch checkout, or can Agent Worktrees update selected local issue records?
- Which comments/notes representation should V1 support in minibeads files without creating merge-heavy collaboration semantics?
- What exact task link fields should be supported for V1: local file paths, branch names, PR links, commit hashes, or a smaller subset?
- Should list/filter views be implemented first in the Terminal Console, Web Dashboard, or both at the same time?
- What is the exact status mapping between minibeads defaults and Runtime Settings states for common projects?
