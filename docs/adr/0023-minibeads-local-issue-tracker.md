# Use minibeads for local issue tracking

## Status

Accepted

## Context

Personal Symphony currently uses GitHub Issues as issue records and GitHub Projects as the dispatch board. This creates a remote dependency for operators who want to write issue records locally inside a Workspace Repository and have Symphony consume them directly.

The first local tracker investigation compared upstream Beads, minibeads, and other local-first issue trackers. Upstream Beads provides a git-backed dependency-aware tracker, but its primary storage model combines a local SQLite database with a git-tracked JSONL sync file. minibeads keeps the Beads-style dependency-aware workflow while storing issue records as Markdown files with YAML frontmatter under `.beads/issues/`.

The chosen path must preserve Workspace Repository root validation, Runtime Contract semantics, Stage Agent dispatch, tracker status transitions, Agent Worktree and Task Branch behavior, retry, Stage Commit, Stage Push, and Task Branch Integration.

## Decision

Personal Symphony will add a minibeads-backed Local Issue Tracker as an opt-in Issue Tracker selected by Runtime Settings.

The Local Issue Tracker will use minibeads Local Issue Files as the source of issue records. Symphony will consume the human-editable Markdown records and map them into the existing internal issue shape used for Agent Prompt rendering, Stage Agent selection, Runtime State, Ordered Queue validation, and Task Branch naming.

The first implementation will not replace the GitHub Tracker. `tracker.kind: "github"` remains the default. A Workspace Repository chooses local issue dispatch explicitly with a new tracker kind for minibeads.

The Local Issue Tracker must write tracker status transitions back to minibeads issue records when Symphony dispatches, retries, completes, or pauses work. These writes must be idempotent, recoverable, and scoped to the selected issue record.

The Local Issue Tracker must treat missing minibeads installation, missing `.beads/` state, unreadable issue files, invalid frontmatter, unsupported status values, duplicate identifiers, and blocked dependencies as Readiness Gaps or non-dispatchable issue states rather than agent task failures.

Bootstrap must not overwrite existing minibeads files. If future Bootstrap support creates local tracker scaffolding, it may create missing files only when the operator has explicitly selected local issue tracking.

## Consequences

Operators can write issue records locally in a Workspace Repository and run Symphony without GitHub API access.

The orchestration boundary must stop depending directly on `Github_tracker.t` for candidate fetches, issue lookup, status updates, remote readiness, and rate-limit behavior.

Runtime Settings parsing, readiness validation, Manual Task Merge, Ordered Queue validation, Runtime State, dashboard naming, and documentation need review for GitHub-specific assumptions.

Git-tracked Local Issue Files may be modified by orchestration while Task Branch work is also changing repository files. The implementation must define whether status writes occur only in the Loop-Start Branch checkout or also inside Agent Worktrees, and must avoid accidental inclusion of tracker status churn in unrelated Stage Commits.

GitHub Issues + Projects documentation remains valid for the GitHub Tracker path, but tracker documentation needs to describe the Issue Tracker abstraction and the minibeads Local Issue Tracker separately.
