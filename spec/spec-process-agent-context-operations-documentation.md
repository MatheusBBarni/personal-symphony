---
title: Agent Context Operations Documentation
version: 1.0
date_created: 2026-05-06
last_updated: 2026-05-06
owner: Product Repository maintainers
tags: [process, documentation, agent-context, issue-43]
---

# Introduction

This specification defines the documentation updates required after Agent Context Snapshot, Context Command, Runtime State, and diagnostics behavior are implemented.

Source issue: [#43 Document Agent Context Operations](https://github.com/MatheusBBarni/symphony-orchestrator/issues/43).

## 1. Purpose & Scope

The purpose is to make accepted context behavior clear to operators, implementers, and future AI agents working in the Product Repository.

This specification covers docs under `docs/agent-context/`, examples, failure behavior, diagnostics, and validation commands.

Out of scope:

- Implementing context behavior.
- Changing package files or CLI binary behavior.

## 2. Definitions

- **Agent Context Snapshot**: Built-in bounded context rendered into Agent Prompt composition.
- **Context Command**: Optional local command that adds stdout to the snapshot.
- **Runtime Settings**: `.symphony/settings.json` configuration.
- **Runtime State**: Live orchestration state exposed by backend and dashboard.
- **Stage Goal Handoff**: Optional Codex goal payload sent before the Agent Prompt.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: `docs/agent-context/architecture.md` MUST describe the accepted high-level context path.
- **REQ-002**: Documentation MUST include secret-free Runtime Settings examples.
- **REQ-003**: Documentation MUST state that context warnings do not retry tasks by themselves.
- **REQ-004**: Documentation MUST explain coexistence with Agent Prompt and Stage Goal Handoff.
- **REQ-005**: Documentation MUST describe diagnostics locations and intentionally omitted data.
- **REQ-006**: Documentation MUST use `CONTEXT.md` glossary terms.
- **CON-001**: Documentation MUST NOT include token values, webhook URLs, or local `.env` contents.
- **CON-002**: Documentation MUST NOT imply that Context Command execution is required by default.
- **GUD-001**: Examples SHOULD be copyable and minimal.

## 4. Interfaces & Data Contracts

### Documentation Targets

| File | Required update |
| --- | --- |
| `docs/agent-context/architecture.md` | High-level architecture and ownership. |
| `docs/agent-context/api-conventions.md` | Runtime State/API shape if applicable. |
| `docs/agent-context/testing-guide.md` | Test commands and coverage expectations. |
| `CONTEXT.md` | Glossary terms when domain language changes. |

### Example Shape

```json
{
  "context": {
    "snapshot": {"enabled": true, "maxOutputBytes": 12000},
    "command": [".symphony/scripts/agent-context.sh"],
    "cwd": "agentWorktree",
    "timeoutMs": 30000
  }
}
```

## 5. Acceptance Criteria

- **AC-001**: Given an operator reads `docs/agent-context/architecture.md`, When they reach context behavior, Then they can identify where the snapshot is generated and where it is injected.
- **AC-002**: Given a Runtime Settings example is copied, When reviewed for secrets, Then it contains no token values or local `.env` contents.
- **AC-003**: Given context generation fails, When docs are read, Then failure behavior explains warning status and no automatic retry.
- **AC-004**: Given Stage Goal Handoff is enabled, When docs are read, Then ordering with Agent Context Snapshot is clear.
- **AC-005**: Given diagnostics are documented, When docs are read, Then full prompt and full stdout persistence limits are explicit.

## 6. Test Automation Strategy

- **Test Levels**: Documentation review plus implementation test verification.
- **Frameworks**: OCaml Alcotest and frontend test runner.
- **Test Data Management**: Use examples that do not depend on local secrets.
- **CI/CD Integration**: Run focused backend tests, `pnpm frontend:test`, and broader `pnpm test` before final handoff after implementation lands.
- **Coverage Requirements**: Docs must reference tests that cover config parsing, prompt composition, command execution, Runtime State exposure, and retry behavior.
- **Performance Testing**: Not required.

## 7. Rationale & Context

Context behavior crosses configuration, prompt composition, local command execution, Runtime State, and diagnostics. Documentation must make ownership and failure behavior explicit so future changes do not turn bounded context into unbounded transcript replay.

## 8. Dependencies & External Integrations

### Data Dependencies

- **DAT-001**: Accepted ADR and `CONTEXT.md` glossary terms.
- **DAT-002**: Implemented Runtime Settings and Runtime State schema.

### Technology Platform Dependencies

- **PLT-001**: Markdown documentation in the Product Repository.

### Compliance Dependencies

- **COM-001**: Secret-free examples.

## 9. Examples & Edge Cases

```text
Context Command failure:
- Agent still launches.
- Prompt includes bounded warning content.
- Runtime State reports context status.
- Diagnostics omit secrets and full prompt content.
```

Edge cases:

- Context disabled.
- Snapshot enabled but command disabled.
- Dashboard receives an older Runtime State snapshot.

## 10. Validation Criteria

- Documentation uses glossary terms consistently.
- Secret-free examples are present.
- Required test commands are documented.
- No generated frontend `.res.js` files are referenced as source files to edit.

## 11. Related Specifications / Further Reading

- [Issue #43](https://github.com/MatheusBBarni/symphony-orchestrator/issues/43)
- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)
- [Issue #40](https://github.com/MatheusBBarni/symphony-orchestrator/issues/40)
- [Issue #41](https://github.com/MatheusBBarni/symphony-orchestrator/issues/41)
- [Issue #42](https://github.com/MatheusBBarni/symphony-orchestrator/issues/42)
