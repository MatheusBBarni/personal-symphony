# Persist dispatched Agent Prompt archives

## Status

Accepted

## Context

Operators need to debug why an agent behaved a certain way after a dispatch has already started or after an Agent Worktree has been removed. The Agent Worktree contains a transient `prompt.md`, but that file belongs to task execution state and may disappear with Task Cleanup Policy. The Runtime Contract `prompt.md` is only the template, not the exact Agent Prompt after Stage Agent instructions, Stage Goal handoff, Agent Context Snapshot, Context Command output, Previous Attempt Output, and issue or Compozy Task Step context have been rendered.

## Decision

Personal Symphony persists an Agent Prompt Archive under ignored Runtime Home state for every dispatched task. Each dispatch writes the exact final Agent Prompt sent to the selected Harness as `.symphony/state/task-prompts/<archive-id>.md` and writes structured launch metadata beside it as `.json`.

The Agent Prompt Archive is Runtime Diagnostics, not Runtime Contract. Archive files are written with private file permissions, and the archive directory is private. Archive persistence is best-effort: a failure to write diagnostics is surfaced as a runtime error summary but must not prevent dispatch.

## Consequences

Operators can inspect the exact prompt that produced an agent run without relying on Agent Worktree retention.

Prompt archive files may include any context intentionally rendered into the Agent Prompt, so they remain ignored Runtime Home state and must not be committed.

Because archive files are per-dispatch diagnostics, they may grow over long-running repositories. Cleanup is an operator maintenance concern rather than Task Cleanup Policy behavior.
