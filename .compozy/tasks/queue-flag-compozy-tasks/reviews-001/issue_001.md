---
provider: manual
pr:
round: 1
round_created_at: 2026-05-13T20:12:51Z
status: pending
file: .symphony/settings.json
line: 35
severity: high
author: claude-code
provider_ref:
---

# Issue 001: Checked-in settings now block or reroute normal dogfood runs

## Review Comment

This PR is supposed to add the Compozy `--queue` shortcut, but the tracked workspace config is also being rewritten from the existing GitHub/task-PR workflow to a Compozy/batch-PR workflow. The most acute part is `pullRequest.mode = "batch"` with `baseBranch = "main"` and `openOnReview = false`.

That is not a harmless local preference change. `Config.readiness_gaps` explicitly rejects batch PR mode when the current Loop-Start Branch matches `pullRequest.baseBranch`, so a normal checkout on `main` now becomes readiness-blocked instead of dispatchable. In the same file, switching `tracker.kind` to `compozy_tasks` also means the checked-in workspace no longer exercises the GitHub tracker path that this feature is supposed to preserve.

If the intent is only to dogfood Compozy locally, keep this as an untracked/local settings change. If the intent is a repository-wide workflow migration, that needs to be split from the queue feature and reviewed as its own behavior change.

## Triage

- Decision: `UNREVIEWED`
- Notes:
