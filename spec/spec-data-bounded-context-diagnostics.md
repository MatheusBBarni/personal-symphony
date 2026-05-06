---
title: Bounded Context Diagnostics
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [data, diagnostics, agent-context, secrets, issue-42]
---

# Introduction

This specification defines secret-safe, bounded diagnostics for Agent Context Snapshot and Context Command generation.

Source issue: [#42 Persist Bounded Context Diagnostics](https://github.com/MatheusBBarni/symphony-orchestrator/issues/42).

## 1. Purpose & Scope

The purpose is to allow operators and maintainers to debug context generation without persisting full prompts, full command output, token values, or local environment secrets.

This specification covers diagnostic storage location, metadata fields, redaction, Runtime State references, and tests.

Out of scope:

- Live dashboard rendering. Covered by issue #41.
- Context Command execution semantics. Covered by issue #40.

## 2. Definitions

- **Context Diagnostics**: Bounded metadata that describes context generation behavior.
- **Runtime Home**: The `.symphony/` directory in the Workspace Repository.
- **Runtime Contract**: User-editable, version-controlled runtime files.
- **Local Environment**: Ignored `.symphony/.env` secret file.
- **Context Command**: Optional local command that can add stdout to context.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Diagnostics MUST be written only to ignored Runtime Home state or diagnostic files.
- **REQ-002**: Diagnostics MUST NOT be written to Runtime Contract files.
- **REQ-003**: Diagnostics MUST include command name, cwd kind, exit code, duration, timeout flag, truncation flag, and output byte count when applicable.
- **REQ-004**: Full stdout MUST NOT be persisted unless an explicitly accepted Runtime Settings option enables it.
- **REQ-005**: Runtime State MAY expose a diagnostic path or summary identifier.
- **REQ-006**: Diagnostics MUST be bounded in size.
- **SEC-001**: Diagnostics MUST NOT persist `GITHUB_TOKEN`, `GH_TOKEN`, local `.env` contents, or full rendered Agent Prompt content.
- **SEC-002**: Redaction MUST apply before writing diagnostics.
- **CON-001**: Diagnostics MUST remain compatible with idempotent Bootstrap behavior.

## 4. Interfaces & Data Contracts

### Diagnostic Record

```json
{
  "kind": "Context Diagnostics",
  "issueIdentifier": "#42",
  "stageAgent": "engineer",
  "attempt": 1,
  "snapshot": {
    "enabled": true,
    "renderedBytes": 2048,
    "truncated": false
  },
  "command": {
    "name": ".symphony/scripts/agent-context.sh",
    "cwdKind": "agentWorktree",
    "exitCode": 0,
    "durationMs": 128,
    "timedOut": false,
    "stdoutBytes": 512,
    "stderrBytes": 0,
    "stdoutTruncated": false
  }
}
```

## 5. Acceptance Criteria

- **AC-001**: Given context diagnostics are written, When Runtime Contract files are inspected, Then no diagnostics appear there.
- **AC-002**: Given a successful Context Command, When diagnostics are read, Then command metadata is present without full stdout by default.
- **AC-003**: Given a timeout, When diagnostics are read, Then `timedOut` is true and duration is recorded.
- **AC-004**: Given stdout exceeds the cap, When diagnostics are read, Then truncation is recorded.
- **AC-005**: Given secret-like environment values exist, When diagnostics are written, Then secret values are absent.

## 6. Test Automation Strategy

- **Test Levels**: Backend integration tests.
- **Frameworks**: OCaml Alcotest.
- **Test Data Management**: Temporary Runtime Home, temp scripts, controlled env vars, and fixture output.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Success, timeout, truncation, non-zero exit, disabled full-output persistence, Runtime Contract separation, and secret redaction.
- **Performance Testing**: Verify diagnostic records remain bounded.

## 7. Rationale & Context

Context generation can fail for local reasons. Bounded diagnostics give maintainers enough data to debug command behavior while preserving the privacy and idempotence boundaries of Runtime Home and Runtime Contract files.

## 8. Dependencies & External Integrations

### Infrastructure Dependencies

- **INF-001**: Runtime Home ignored state directory - Stores diagnostics.
- **INF-002**: Runtime State - References diagnostic summaries.

### Data Dependencies

- **DAT-001**: Context generation result - Supplies diagnostic metadata.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Writes diagnostics and applies redaction.

## 9. Examples & Edge Cases

```json
{
  "command": {
    "exitCode": 127,
    "timedOut": false,
    "summary": "executable not found"
  }
}
```

Edge cases:

- Context is skipped.
- Command writes a token-shaped string to stderr.
- Diagnostics directory is missing.
- Full-output persistence is disabled.

## 10. Validation Criteria

- `pnpm test` passes.
- Diagnostics are bounded and secret-free.
- Runtime Contract files remain unchanged by diagnostics.

## 11. Related Specifications / Further Reading

- [Issue #42](https://github.com/MatheusBBarni/symphony-orchestrator/issues/42)
- [Issue #40](https://github.com/MatheusBBarni/symphony-orchestrator/issues/40)
- [Issue #41](https://github.com/MatheusBBarni/symphony-orchestrator/issues/41)
- [CONTEXT.md](../CONTEXT.md)
