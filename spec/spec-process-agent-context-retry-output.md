---
title: Agent Context Retry Output
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, agent-context, retry, issue-39]
---

# Introduction

This specification defines how bounded previous-attempt output is included in Agent Context Snapshot content for retry launches.

Source issue: [#39 Carry Retry Output Into The Agent Context Snapshot](https://github.com/MatheusBBarni/symphony-orchestrator/issues/39).

## 1. Purpose & Scope

The purpose is to give retrying agents useful failure context without storing or replaying a full Codex transcript.

This specification covers retry-only stdout/stderr tail selection, truncation, prompt ordering, and tests.

Out of scope:

- First-launch snapshot fields. Covered by issue #38.
- Persisted diagnostics. Covered by issue #42.

## 2. Definitions

- **Retry Launch**: A new agent dispatch attempt after a previous attempt failed or stopped unsuccessfully.
- **Previous Attempt Output**: The stdout and stderr files captured from the immediately previous agent process.
- **Agent Context Snapshot**: The bounded markdown section added to the Agent Prompt.
- **Stage Goal Handoff**: Optional Codex goal handoff sent before the normal Agent Prompt.
- **Runtime State**: Snapshot data that records running, retrying, and error activity.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Retry output MUST be omitted on first launch.
- **REQ-002**: Retry output MUST include the previous attempt number.
- **REQ-003**: Retry output SHOULD include bounded tails for stdout and stderr when available.
- **REQ-004**: Truncation MUST be deterministic and marked clearly.
- **REQ-005**: Missing stdout or stderr files MUST render as unavailable, not as an error.
- **REQ-006**: Retry context MUST preserve Stage Goal Handoff ordering.
- **CON-001**: Retry context MUST NOT persist full Codex transcripts.
- **CON-002**: Retry context MUST NOT include full rendered Agent Prompt content.
- **GUD-001**: Prefer byte caps over line caps when enforcing maximum prompt contribution size.

## 4. Interfaces & Data Contracts

### Retry Snapshot Section

````md
### Previous Attempt

- Previous attempt: 1
- stdout tail bytes: 4096
- stderr tail bytes: 4096

#### stdout tail

```text
...
```

#### stderr tail

```text
...
```
````

### Truncation Marker

```text
[truncated to 4096 bytes]
```

## 5. Acceptance Criteria

- **AC-001**: Given attempt `1`, When the Agent Context Snapshot renders, Then previous attempt output is absent.
- **AC-002**: Given attempt `2` and captured stdout/stderr, When the snapshot renders, Then bounded tails are present.
- **AC-003**: Given output larger than the byte cap, When the snapshot renders, Then content is truncated with a stable marker.
- **AC-004**: Given Stage Goal Handoff is enabled, When a retry prompt is composed, Then retry context remains after the normal prompt content.
- **AC-005**: Given one output file is missing, When rendering occurs, Then the missing stream is reported as unavailable.

## 6. Test Automation Strategy

- **Test Levels**: Backend unit tests and orchestration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Use temporary stdout/stderr files with known content.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: First launch, retry launch, missing files, stdout truncation, stderr truncation, and ordering.
- **Performance Testing**: Verify bounded file reading for large files.

## 7. Rationale & Context

Retries need concrete failure context, but full transcripts create size, privacy, and determinism problems. Captured process output already exists in Symphony's launch model and can be bounded before prompt injection.

## 8. Dependencies & External Integrations

### Infrastructure Dependencies

- **INF-001**: Agent Worktree launch artifacts - Provide stdout and stderr paths.
- **INF-002**: Runtime Home - Contains ignored runtime artifacts.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Implements retry and prompt composition.

## 9. Examples & Edge Cases

```text
Attempt 1: no previous output section.
Attempt 2: previous attempt 1 stdout and stderr tails included.
Attempt 3: previous attempt 2 output included, not attempt 1 output.
```

Edge cases:

- Empty stdout.
- Empty stderr.
- Binary or invalid UTF-8 output.
- Output files deleted during cleanup.

## 10. Validation Criteria

- `pnpm test` passes.
- Retry prompt content is bounded and deterministic.
- Full transcript content is not stored or rendered.

## 11. Related Specifications / Further Reading

- [Issue #39](https://github.com/MatheusBBarni/symphony-orchestrator/issues/39)
- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)
- [CONTEXT.md](../CONTEXT.md)
