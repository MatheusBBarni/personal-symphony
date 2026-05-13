# GitHub Issues + Projects Tracking

This document applies to the GitHub Tracker path, where `tracker.kind` is `"github"` or omitted.
Personal Symphony uses GitHub Issues as issue records and GitHub Projects as the dispatch board for
that tracker. The active Issue Tracker is configured in Workspace Repository Runtime Settings at
`.symphony/settings.json`.

## Required Project Fields

- `Status`: single-select GitHub Projects field used as the issue state.
- Active status values: values listed in `project.activeStates`.
- Terminal status values: values listed in `project.terminalStates`.
- Transition status values: `project.startStatus`, `project.reviewStatus`, and `project.retryStatus`.

When `project.ensureStatuses` is `true`, Symphony creates missing single-select status options before
moving a GitHub Project item. The token used by the backend must have GitHub Projects write access for
that behavior.

## Runtime Settings

Configure the GitHub Tracker and GitHub Project states in `.symphony/settings.json`:

```json
{
  "tracker": {
    "kind": "github",
    "owner": "your-org",
    "repo": "your-repo",
    "projectNumber": 1,
    "apiKeyEnv": "GITHUB_TOKEN"
  },
  "project": {
    "statusField": "Status",
    "activeStates": ["Backlog", "Todo", "To-Do", "In progress", "In Progress", "In review"],
    "terminalStates": ["Done", "Closed", "Cancelled"],
    "startStatus": "In progress",
    "reviewStatus": "In review",
    "retryStatus": "To-Do",
    "ensureStatuses": true
  }
}
```

`tracker.kind = "github"` selects the GitHub Tracker. `tracker.owner`, `tracker.repo`, and
`tracker.projectNumber` identify the Workspace Repository and GitHub Project that Symphony polls.
`tracker.apiKeyEnv` names the Local Environment variable that contains the GitHub token; store the
value in `.symphony/.env`, not in Runtime Settings.

## Workflow

1. Create a GitHub Issue with the `Symphony task` template.
2. Add the issue to the configured GitHub Project.
3. Set `Status` to one of the configured active status values when it is ready for automated dispatch.
4. Symphony polls eligible issues, creates an Agent Worktree, checks out a Task Branch from the
   Loop-Start Branch, and launches the configured Stage Agent.
5. The Stage Agent follows the Runtime Contract from `.symphony/`, including Stage Commit and Stage
   Push settings when enabled.
6. Move the item to a configured terminal status to stop future dispatch. Merge problems move to the
   configured Human Attention Status.

Legacy `WORKFLOW.md` files are fixture/import compatibility only. They are not the active Runtime
Contract for new Workspace Repository setup.

For minibeads Local Issue Tracker setup, configure `tracker.kind = "minibeads"` in Runtime Settings
and follow the main README. minibeads does not use GitHub Issues, GitHub Projects, or GitHub tracker
token settings for issue dispatch.

For Compozy-backed Local Issue Tracker setup, configure `tracker.kind = "compozy_tasks"` in Runtime
Settings and follow the main README. Symphony treats `.compozy/tasks/<task_name>/` as one Compozy PRD
Run and uses `compozy:<task_name>` selectors where Compozy selector support is available. Compozy
tracking does not use GitHub Issues, GitHub Projects, or GitHub tracker token settings for issue
dispatch.

Compozy tracking reports Compozy PRD Run lifecycle and PR readiness at the run level. Compozy Task
Step progress remains ordered progress inside the run, and Batch Pull Request behavior remains
aggregate in `batch` Pull Request Mode rather than opening per-step pull requests.

## Authentication

Set `GITHUB_TOKEN` or `GH_TOKEN` for the backend process. The token needs permission to read issues
and GitHub Project item metadata for the configured Workspace Repository and GitHub Project. If
Symphony will move statuses or create missing status options, the token also needs GitHub Projects
write permission.

## Local Smoke Commands

```sh
gh auth status
pnpm backend:dev
pnpm frontend:dev
```
