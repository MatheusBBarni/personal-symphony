# ADR 0019: Block self-target Batch Pull Requests at readiness

When automatic Batch Pull Request creation is enabled, Symphony opens one pull request from the Loop-Start Branch to the configured Pull Request Base Branch. GitHub rejects a pull request whose head and base are the same branch, and letting that fail at handoff time leaves completed work with a retryable-looking error that operator action cannot fix by retrying.

Symphony now reports a Readiness Gap when the current Loop-Start Branch equals `pullRequest.baseBranch`. Operators must either switch to a non-trunk Loop-Start Branch before starting orchestration or change the Pull Request Base Branch to the intended target.

This preserves the existing Batch Pull Request model and avoids attempting impossible PR handoffs after task work has already completed.
