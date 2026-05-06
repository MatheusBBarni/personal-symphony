# ADR 0016: Stage Concurrency Policy

## Status

Accepted

## Context

`agent.maxConcurrentAgents` is a global orchestration limit. It prevents Symphony from launching more than the configured total number of agents, but it does not let a Workspace Repository reserve or cap work by Stage Agent.

In a Self-Dogfooding Workspace Repository, this makes useful parallelism awkward. The operator may want one planner handling Backlog work, one engineer admitting Todo work, two engineers continuing In Progress work, and two reviewers handling In Review work. A single busy stage should not consume every global slot when other stages also have eligible work, and an empty stage should not launch idle agents.

## Decision

Runtime Settings may define a Stage Concurrency Policy on each configured Stage Agent mapping.

The per-stage setting is named `maxConcurrentAgents`. It is optional and must be a positive integer when present. A missing stage setting preserves the existing global-only behavior for that stage.

Dispatch admission enforces both limits:

- total running agents must not exceed `agent.maxConcurrentAgents`;
- running agents launched for a stage must not exceed that stage's `maxConcurrentAgents` when the stage setting is present.

Stage capacity is counted against the Stage Agent mapping selected at launch time. It is not inferred only from the issue's current tracker status, because `startStatus` can move an issue before the child agent exits.

When a stage has fewer eligible issues than its configured capacity, Symphony launches only the eligible issue count. When a launched agent exits, later polls may admit more eligible work for that stage if both the stage and global limits have capacity.

Ordered Queue order still controls dispatch priority, but a full stage capacity does not block all later queue entries. Later queued entries may be admitted when they are otherwise dispatchable and their selected stage has capacity.

## Consequences

Workspace Repositories can shape concurrent work by Stage Agent while keeping the global agent limit as the hard ceiling.

Existing Runtime Settings continue to behave as they do today when no per-stage `maxConcurrentAgents` values are present.

Runtime State must retain enough running-child stage identity for deterministic capacity accounting across status transitions and process-visible dashboard state.

Invalid non-positive stage caps are configuration errors or readiness gaps, consistent with existing positive integer settings.

This decision does not change Stage Commit, Stage Push, retry, Task Branch Integration, Task Cleanup Policy, or Batch Pull Request behavior.

