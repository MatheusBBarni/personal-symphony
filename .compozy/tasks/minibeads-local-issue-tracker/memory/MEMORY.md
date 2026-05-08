# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 02 introduced `Issue_tracker` with GitHub as the only implemented adapter for now.
- Task 03 introduced a readiness-only `Minibeads_tracker` adapter skeleton selected through `Issue_tracker` for `tracker.kind = "minibeads"`.
- Task 04 implemented minibeads issue fetch, lookup, blocker filtering, status normalization, and status update behavior behind `Issue_tracker`.
- Task 05 refactored `Orchestrator` polling, dispatch filtering, and status writes to use the selected `Issue_tracker.t`.
- Task 09 preserved Pull Request handoff for minibeads by letting `gh pr` infer the repository from the git remote when tracker owner/repo are empty, while keeping explicit `--repo owner/repo` for GitHub Tracker configs.

## Shared Decisions

## Shared Learnings
- `Issue_tracker.fetch_by_identifiers` follows the TechSpec option-list shape, while `fetch_by_identifiers_detailed` preserves diagnostics such as missing GitHub issue versus absent GitHub Project membership for future Ordered Queue and Manual Task Merge work.
- `Minibeads_tracker` readiness uses an injectable command runner and invokes the configured command from the Workspace Repository root; tests should prefer fake runners instead of requiring a real `mb` install.
- `Minibeads_tracker.command_runner.run` now executes exact command strings. Callers build explicit `mb --version`, `mb --json list`, `mb --json show`, and `mb update --status` commands.
- minibeads status normalization maps common Symphony statuses to `open`, `in_progress`, `blocked`, and `closed`; mapped local issues keep `Issue.comments = []` for V1.
- Orchestrator poll injection now uses `(Issue.t list, Issue_tracker.poll_error) result`; tests and future stubs should return `Ok issues` or generic `Issue_tracker` poll errors.
- Ordered Queue entries are keyed by canonical `issue_identifier`, not numeric issue numbers; use `Ordered_queue.validation_gaps` with the selected `Issue_tracker.t` for existence and dispatchability checks.
- Pull Request handoff remains a git/review remote concern, not an Issue Tracker requirement; minibeads status transitions still use the selected tracker status path.

## Open Risks

## Handoffs
- Future minibeads, Ordered Queue, and Manual Task Merge tasks should use the detailed lookup path when they need operator diagnostics, not only the public option-list lookup.
