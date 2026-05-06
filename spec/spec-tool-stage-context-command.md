---
title: Stage Context Command
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [tool, agent-context, runtime-settings, issue-40]
---

# Introduction

This specification defines a stage-specific Context Command that can add bounded operator-provided context to the Agent Context Snapshot.

Source issue: [#40 Run A Stage Context Command Before Agent Launch](https://github.com/MatheusBBarni/symphony-orchestrator/issues/40).

## 1. Purpose & Scope

The purpose is to allow a trusted local command to generate fresh context immediately before prompt write.

This specification covers Runtime Settings, validation, command execution, stdin JSON, temp-file JSON, stdout injection, warnings, and tests.

Out of scope:

- Dashboard surfacing. Covered by issue #41.
- Persisted diagnostics. Covered by issue #42.

## 2. Definitions

- **Context Command**: A local command configured for a Stage Agent that receives structured context and returns prompt content on stdout.
- **Agent Context Snapshot**: The deterministic prompt section that can include Context Command stdout.
- **Workspace Repository Root**: The root directory where Symphony commands are run.
- **Agent Worktree**: The per-task Git worktree used to run agent work.
- **Readiness Gap**: A pre-dispatch configuration problem.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Context Command configuration MUST be optional and stage-specific.
- **REQ-002**: `command` MUST be an argv array, not a shell string.
- **REQ-003**: `cwd` MUST be constrained to `workspaceRepositoryRoot` or `agentWorktree`.
- **REQ-004**: Invalid configuration MUST create a Readiness Gap before dispatch.
- **REQ-005**: The command MUST run synchronously before the Agent Prompt is written.
- **REQ-006**: The command MUST receive structured JSON on stdin.
- **REQ-007**: The same JSON MUST be written to a temp file and exposed through an environment variable.
- **REQ-008**: Only stdout MAY be injected into the Agent Prompt.
- **REQ-009**: Stderr MUST be diagnostic-only by default.
- **REQ-010**: Timeout, missing executable, non-zero exit, and oversized stdout MUST become bounded warning content.
- **CON-001**: Context Command execution MUST NOT allow cwd outside the Workspace Repository root or Agent Worktree.
- **CON-002**: Context Command failures MUST NOT move a task to retry by themselves.
- **SEC-001**: Secret environment values MUST NOT be added to the structured JSON payload.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

```json
{
  "context": {
    "command": [".symphony/scripts/agent-context.sh"],
    "cwd": "agentWorktree",
    "timeoutMs": 30000,
    "maxOutputBytes": 12000
  }
}
```

### Command Input Shape

```json
{
  "kind": "Context Command Input",
  "issue": {
    "identifier": "#40",
    "title": "Run A Stage Context Command Before Agent Launch",
    "status": "Todo"
  },
  "stageAgent": "engineer",
  "attempt": 1,
  "workspaceRepositoryRoot": "/path/to/workspace",
  "agentWorktree": "/path/to/workspace/.symphony/workspaces/task-40",
  "taskBranch": "symphony/task/40-run-a-stage-context-command-before-agent-launch"
}
```

## 5. Acceptance Criteria

- **AC-001**: Given missing Context Command config, When dispatch runs, Then no command executes.
- **AC-002**: Given valid config, When dispatch runs, Then the command receives stdin JSON and a JSON temp file path.
- **AC-003**: Given command stdout, When prompt composition finishes, Then stdout appears in the Agent Context Snapshot within byte limits.
- **AC-004**: Given command stderr, When prompt composition finishes, Then stderr is absent from the prompt by default.
- **AC-005**: Given timeout or non-zero exit, When dispatch continues, Then a bounded warning is rendered and the task is not retried solely for context failure.
- **AC-006**: Given invalid cwd, When readiness is checked, Then a Readiness Gap names the invalid setting.

## 6. Test Automation Strategy

- **Test Levels**: Backend integration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Use temporary shell scripts, temporary Runtime Home paths, and isolated Workspace Repository fixtures.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Valid command, disabled config, invalid argv, invalid cwd, timeout, missing executable, non-zero exit, stderr exclusion, stdout truncation.
- **Performance Testing**: Verify timeout enforcement.

## 7. Rationale & Context

Some useful launch context is repository-specific and cannot be known by Symphony. A trusted command hook provides this context while keeping execution bounded and explicit.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: Local operating system process execution - Runs configured commands.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Provides temp and diagnostic locations.
- **INF-002**: Agent Worktree - Optional command cwd.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Parses settings and executes commands.

## 9. Examples & Edge Cases

```sh
#!/bin/sh
printf '## Repository Context\n\n'
git status --short
```

Edge cases:

- Command path contains spaces.
- Command writes only stderr.
- Command exits zero with empty stdout.
- Command output exceeds max bytes.

## 10. Validation Criteria

- `pnpm test` passes.
- Commands execute without implicit shell parsing.
- Prompt injection contains stdout only.
- Failure modes are warnings, not task retries.

## 11. Related Specifications / Further Reading

- [Issue #40](https://github.com/MatheusBBarni/symphony-orchestrator/issues/40)
- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)
- [CONTEXT.md](../CONTEXT.md)
