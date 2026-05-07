# Open Batch Pull Requests on review handoff when configured

Personal Symphony already supports a Batch Pull Request from the Loop-Start Branch after Orchestration Idle. Some Workspace Repositories need earlier human review: as soon as an agent finishes, its Task Branch has been integrated, and the issue reaches the review status, the combined Loop-Start Branch should have a pull request ready.

The Pull Request Policy now includes `openOnReview`, disabled by default. When both `pullRequest.enabled` and `pullRequest.openOnReview` are true, Symphony opens or reuses the same Batch Pull Request immediately after a successful stage completion moves an issue to the configured review status. This happens after Stage Commit and Task Branch integration, so the pull request head remains the Loop-Start Branch and not an individual Task Branch.

The default idle trigger remains in place. If the Review Pull Request Handoff fails, Runtime State records a retryable pull request handoff failure and a later idle poll can retry. If the handoff succeeds, Symphony marks Batch Pull Request creation complete so later polls do not create duplicates.

This kept the product language anchored on one Batch Pull Request while allowing earlier operator review for long-running batches. ADR 0020 later adds a separate Task Pull Request mode for Workspace Repositories that need one pull request per Task Branch.
