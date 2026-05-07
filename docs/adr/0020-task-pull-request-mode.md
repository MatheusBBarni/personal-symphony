# ADR 0020: Task Pull Request mode

Some Workspace Repositories need orchestration to start from a Protected Trunk Branch such as `main`, while still preserving normal code review by opening one pull request per completed Task Branch into that same branch. That is not the same runtime model as the existing Batch Pull Request behavior, where completed task work is first integrated into a non-trunk Loop-Start Branch and then one pull request is opened from that Loop-Start Branch into the Pull Request Base Branch.

The Pull Request Policy now includes `mode`, defaulting to `batch`. In `batch` mode, Symphony preserves existing Batch Pull Request semantics: the Loop-Start Branch is the pull request head, the Pull Request Base Branch must differ from the current Loop-Start Branch, and idle or review handoff opens or reuses one Batch Pull Request.

In `task` mode, Symphony opens or reuses a Task Pull Request when a task moves to the review status. The pull request head is the task's Task Branch and the base is the configured Pull Request Base Branch. Because the head is the Task Branch, Symphony may run from `main` with `pullRequest.baseBranch` also set to `main`; the self-target readiness gap applies only to Batch Pull Request mode.

Task Pull Request mode does not change Task Branch creation, Stage Commit, Stage Push, protected-trunk auto-merge rules, or Task Branch Integration semantics. When the Loop-Start Branch is protected, completed Task Branch work remains unintegrated locally, the Agent Worktree is retained for inspection, and the Task Pull Request provides the review path into the protected branch.

Runtime State now records the Pull Request Mode and issue identifier for pull request handoffs, and keeps a list of recorded handoffs while preserving the existing latest `pull_request` field.

Consequences:

- Workspace Repositories can start orchestration on `main` while reviewing each Task Branch through its own pull request.
- Existing Batch Pull Request users remain on the default `batch` mode.
- Operators must choose the mode explicitly when they want per-task review; enabling pull requests without changing mode keeps Batch Pull Request behavior.
