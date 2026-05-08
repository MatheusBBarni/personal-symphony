# Runtime Settings Invocation Overrides

## Status

Accepted

## Context

Personal Symphony loads Runtime Settings from the Workspace Repository Runtime Contract after verifying that the command is running from a Workspace Repository root. Operators sometimes need a one-run change to polling cadence, Agent Worktree placement, or agent retry limits without editing the repository-owned `.symphony/settings.json`.

## Decision

Symphony will support Runtime Settings Invocation Overrides as command-line flags on the default `symphony` runtime command. Each override replaces one loaded Runtime Settings field for the current process only. Overrides are applied after `.symphony/settings.json` is loaded and validated enough to construct the runtime config, and before readiness checks, startup reporting, server startup, manual merge handling, or orchestration behavior uses the effective runtime config.

Overrides must not change Bootstrap defaults, must not rewrite `.symphony/settings.json`, and must not weaken the existing requirement that runtime commands start from a Workspace Repository root. The `workspace.root` override changes effective Agent Worktree placement for one run; it does not select a different Workspace Repository. The same path resolution and positive integer validation rules used by Runtime Settings apply to equivalent override values.

## Consequences

Operators can tune a single run from automation or shell history without changing the Runtime Contract for other users.

The CLI layer needs a typed override model instead of ad hoc mutation in orchestration code, so runtime behavior remains explainable and testable.

Legacy `WORKFLOW.md` invocation is not the target of this decision. The override contract applies to the current Runtime Home path based on `.symphony/settings.json`.
