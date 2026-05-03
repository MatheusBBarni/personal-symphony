# GitHub Issues + Projects Tracking

Personal Symphony uses GitHub Issues as the unit of work and GitHub Projects as the dispatch board.

## Required Project Fields

- `Status`: single-select field used as the issue state.
- Active status values: `Todo`, `In Progress`.
- Terminal status values: `Done`, `Closed`, `Cancelled`.

These values should match `tracker.active_states`, `tracker.terminal_states`, and
`tracker.project_status_field` in `WORKFLOW.md`.

## Workflow

1. Create an issue with the `Symphony task` template.
2. Add the issue to the configured GitHub Project.
3. Set `Status` to `Todo` when it is ready for automated dispatch.
4. Symphony reads eligible issues, creates a per-issue workspace, and launches the coding agent.
5. The agent updates the issue and project item according to the repository-owned `WORKFLOW.md`.
6. Move the item to `Done` or another terminal state to stop future dispatch and trigger cleanup.

## Authentication

Set `GITHUB_TOKEN` or `GH_TOKEN` for the backend process. The token needs permission to read issues
and project item metadata for the configured repository/project. If agents are expected to update
issues or project fields, their runtime credentials need the corresponding write permissions.

## Local Smoke Commands

```sh
gh auth status
pnpm backend:dev
pnpm frontend:dev
```
