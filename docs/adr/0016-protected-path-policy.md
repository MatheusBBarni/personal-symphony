# ADR 0016: Protected Path Policy

## Status

Accepted

## Context

Prompt instructions are not a sufficient safeguard for a Self-Dogfooding Workspace Repository. Routine agent work in this Product Repository can accidentally touch package entrypoints, packaged-binary scripts, release workflows, or other sensitive Workspace Repository files even when the issue did not authorize that scope.

The Runtime Home already contains `.symphony/.gitignore`, but that file controls ignored runtime files such as Local Environment, Runtime State, and Agent Workspaces. It is not a policy for which version-controlled Workspace Repository paths agents may modify.

## Decision

Runtime Settings will define the first version of the Protected Path Policy. The policy will not introduce a standalone `.symphonyignore` file in the first version.

Protected Path Policy patterns are repository-root-relative and support files, directories, globs, generated-file paths that would otherwise be committed or integrated, and nested paths. The first version uses gitignore-like path semantics without negation patterns. A changed path is protected when an added, modified, deleted, or renamed path matches a protected pattern.

Protected path changes are allowed only when human-authored issue scope explicitly authorizes the exact protected path or exact policy pattern name before dispatch. Agent output cannot authorize protected path changes.

Symphony checks for unauthorized protected path changes before Stage Commit. When unauthorized changes are present, Symphony moves the task to the Human Attention Status, keeps the work available for inspection, and does not create the Stage Commit. Because Stage Push follows Stage Commit, Stage Push does not run for that task.

Startup Reconciliation, automated Task Branch Integration, Manual Task Merge, and Batch Pull Request handoff must also respect unresolved protected-path attention. Startup Reconciliation and Manual Task Merge must inspect committed Task Branch work before integration. Batch Pull Request creation remains blocked while protected-path attention is unresolved.

This Self-Dogfooding Workspace Repository should configure the policy to protect package and release-sensitive paths such as the CLI Package entrypoint, packaged-binary scripts, release workflows, package metadata, lockfiles, and platform-binary payload paths.

## Consequences

Workspace Repositories get a repository-owned safety rule in the Runtime Contract without adding a second ignore-style file format immediately.

Existing ignored Runtime Home behavior remains separate from Protected Path Policy behavior.

Implementations need focused tests for pattern matching, authorization parsing, Stage Commit blocking, Startup Reconciliation blocking, Manual Task Merge blocking, and Batch Pull Request handoff blocking.

Protected-path attention becomes an operator triage path instead of an agent-retry path because the task requires human scope clarification or human-directed cleanup.
