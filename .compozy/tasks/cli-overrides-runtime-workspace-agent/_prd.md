# Runtime Settings Invocation Overrides PRD

## Overview

Runtime Settings Invocation Overrides let automation authors and Product Repository maintainers tune selected Runtime Settings for one `symphony` process without editing `.symphony/settings.json`.

The MVP delivers the full issue-66 flag set for the default runtime command: polling interval, Agent Worktree root, global concurrency, max turns, and retry backoff cap. Overrides are temporary, explicit, and scoped to the current invocation. They preserve the Runtime Contract as the durable source of Workspace Repository behavior.

The primary product value is automation ergonomics. Scripts, scheduled runs, and maintainer dogfooding can adapt runtime behavior for one run without creating config churn or risking accidental Runtime Contract changes.

## Goals

- Let operators override five selected Runtime Settings fields for one default `symphony` runtime invocation.
- Preserve `.symphony/settings.json` byte-for-byte when overrides are used.
- Keep Workspace Repository root validation unchanged and earlier than override behavior.
- Make unsupported command modes fail clearly when runtime-only override flags are used.
- Document every new flag in `symphony --help` with current-invocation wording.
- Ensure every shipped override has observable user-facing behavior.

## User Stories

### Automation Author

- As an automation author, I want to tune a single Symphony run from a script so that I do not edit repository-owned Runtime Settings for temporary execution needs.
- As an automation author, I want invalid override values to fail before dispatch so that scripts do not run with accidental defaults.
- As an automation author, I want override flags to affect only the current process so that later runs return to the Runtime Contract values.

### Product Repository Maintainer

- As a maintainer, I want to run Web Dashboard or Manual Task Merge with temporary runtime tuning so that I can dogfood behavior without creating config churn.
- As a maintainer, I want `symphony --help` to explain invocation-only behavior so that the feature is discoverable without reading source code.
- As a maintainer, I want all five issue-66 flags to ship together so that the product surface is complete and consistent.

## Core Features

### Current-Invocation Override Flags

The default `symphony` runtime command supports:

- `--polling.intervalMs VALUE`
- `--workspace.root VALUE`
- `--agent.maxConcurrentAgents VALUE`
- `--agent.maxTurns VALUE`
- `--agent.maxRetryBackoffMs VALUE`

Each flag replaces the corresponding loaded Runtime Settings value for the current process only.

### Runtime Contract Preservation

Overrides must not rewrite `.symphony/settings.json`, change Bootstrap defaults, or create alternate Runtime Contract files.

### Preserved Root Boundary

`symphony` must still start from a Workspace Repository root. `--workspace.root` controls Agent Worktree placement for the current run; it does not select or discover a Workspace Repository.

### Clear Unsupported-Mode Failure

Runtime-only override flags are not accepted for `symphony init`, `symphony update`, or legacy positional `WORKFLOW.md` mode. When used there, Symphony fails clearly and tells the user the flag only works on the default runtime command.

### Help Discoverability

`symphony --help` lists every new flag and states that it overrides the Runtime Settings value for the current invocation only.

## User Experience

Primary MVP flow:

1. A maintainer starts from a valid Workspace Repository root.
2. The maintainer runs `symphony --web` or `symphony --merge` with one or more override flags.
3. Symphony validates the Workspace Repository root normally.
4. Symphony loads Runtime Settings and applies the supplied invocation overrides for this process.
5. The selected runtime mode uses the effective values.
6. `.symphony/settings.json` remains unchanged.
7. A later run without flags uses Runtime Settings again.

Failure flow:

1. An operator supplies an invalid integer override such as `0`, `-1`, `1.5`, an empty value, or non-numeric text.
2. Symphony fails startup clearly before dispatch.
3. The error identifies the invalid override field.
4. No Runtime Contract file is rewritten.

Unsupported-mode flow:

1. An operator runs `symphony init --polling.intervalMs 1000`.
2. Symphony rejects the runtime-only flag.
3. The message explains that Runtime Settings Invocation Overrides apply only to the default runtime command.

## High-Level Technical Constraints

- Overrides apply after Runtime Settings are loaded and before readiness checks, startup reporting, Web Dashboard startup, Terminal Console rendering, Manual Task Merge, or orchestration uses the config.
- Positive integer override values must reject zero, negative, decimal, empty, and non-numeric values.
- `--workspace.root` must follow the same user-facing path behavior as Runtime Settings: relative values are based on the Workspace Repository root; absolute and home-relative values keep existing behavior.
- Secret-bearing settings, including token values and webhook URLs, are not part of this override surface.
- `GITHUB_TOKEN` and `GH_TOKEN` values must never appear in docs, examples, logs, or errors.

## Non-Goals (Out of Scope)

- Generic dot-path Runtime Settings override mechanism.
- Persistent writes to `.symphony/settings.json`.
- Bootstrap default changes.
- Overrides for tracker, project, Git policy, Stage Agent, Agent Harness, pull request, Protected Path Policy, server settings, secrets, or webhook URLs.
- Support for `symphony init`, `symphony update`, or legacy positional `WORKFLOW.md` mode.
- Effective-config diagnostics or startup display of active override values.
- Documentation examples beyond `symphony --help` wording.

## Phased Rollout Plan

### MVP (Phase 1)

Deliver all five issue-66 runtime override flags on the default runtime command.

Success criteria:

- All five flags affect current-process behavior.
- `.symphony/settings.json` remains unchanged.
- Invalid values fail startup clearly.
- Unsupported modes reject runtime-only flags.
- `symphony --help` documents each flag.

### Phase 2

Improve discoverability if users need more guidance.

Possible additions:

- Short docs examples for common automation and dogfooding invocations.
- Effective-config visibility that shows non-secret active override values.

Success criteria:

- Reduced support questions about precedence and invocation-only behavior.
- Operators can explain whether a value came from Runtime Settings or an override.

### Phase 3

Evaluate whether additional Runtime Settings fields deserve invocation overrides.

Success criteria:

- Any new override candidates are backed by real operator use cases.
- Contract-level semantics remain excluded unless a separate product decision changes that boundary.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Supported override coverage | 5/5 flags | Each flag has observable current-process behavior. |
| Runtime Contract preservation | 0 byte changes | Settings file comparison after override startup. |
| Invalid value rejection | 100% of invalid classes | Zero, negative, decimal, empty, and non-numeric values fail. |
| Unsupported-mode rejection | 3/3 modes | `init`, `update`, and legacy `WORKFLOW.md` mode reject runtime-only flags. |
| Help discoverability | 5/5 flags | Help output lists every flag with current-invocation wording. |
| Root-boundary preservation | 100% | Override usage outside a Workspace Repository still fails root validation. |

## Risks and Mitigations

- **Risk: `--agent.maxTurns` ships without real user-visible behavior.**
  Mitigation: make observable max-turn behavior part of MVP acceptance.

- **Risk: users mistake `--workspace.root` for a Workspace Repository selector.**
  Mitigation: help text must say it controls Agent Worktree placement for the current invocation, not Runtime Contract discovery.

- **Risk: automation scripts silently run with wrong values.**
  Mitigation: invalid values fail clearly before dispatch.

- **Risk: users expect overrides to persist.**
  Mitigation: help text uses current-invocation wording and Runtime Contract preservation is a core product guarantee.

- **Risk: override scope expands into sensitive or contract-level settings.**
  Mitigation: V1 is limited to the five issue-66 operational tuning values.

## Architecture Decision Records

- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — V1 uses a fixed allowlist with process-local behavior and typed internal override application.
- [ADR-002: Full Issue-66 Runtime Override Scope](adrs/adr-002.md) — PRD scope includes all five issue-66 flags, including `--agent.maxTurns`.

## Open Questions

- Should duplicate uses of the same override flag be rejected explicitly, or should the CLI parser's default repeated-option behavior be documented?
- Should Phase 2 include effective-config visibility if users ask for more confidence during automation debugging?
