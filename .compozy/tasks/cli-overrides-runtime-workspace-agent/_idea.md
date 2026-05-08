# Runtime Settings Invocation Overrides

## Overview

Runtime Settings Invocation Overrides let automation authors and Product Repository maintainers replace selected Runtime Settings fields for one `symphony` process without editing `.symphony/settings.json`.

V1 targets issue 66 only: polling cadence, Agent Worktree root, global agent concurrency, max agent turns, and retry backoff cap. The feature is a Quick Win with a durable policy: command-line flags affect only the current invocation, never rewrite the Runtime Contract, and never weaken Workspace Repository root validation.

## Problem

Automation authors need to tune Symphony runs from scripts, scheduled jobs, and development workflows. Today, changing values such as polling interval, Agent Worktree placement, or concurrency requires editing Runtime Settings. That creates repository churn, risks committing machine-specific paths, and makes one-off experiments look like durable Runtime Contract changes.

Product Repository maintainers also need fast, repeatable ways to validate runtime behavior. Editing `.symphony/settings.json` during dogfooding is slow and error-prone because it mixes temporary execution choices with repository-owned semantics.

### Market Data

Mature CLI tools commonly give command-line arguments highest precedence over config files for one invocation. Anchore documents precedence as command-line arguments, environment variables, explicit config file, discovered config file, then defaults. Porter documents flags as highest precedence over environment variables and config files. GitHub CodeQL states that command-line options override config values for the same option.

CLI guidance also supports this split: values likely to vary from one invocation to the next should be flags, while stable project behavior belongs in version-controlled config. Stack Overflow's 2025 Developer Survey had over 49,000 responses, showing a large developer audience that depends on predictable tooling behavior.

Sources: [Anchore configuration](https://oss.anchore.com/docs/reference/configuration/), [Porter configuration](https://porter.sh/docs/introduction/concepts-and-components/intro-configuration/), [GitHub CodeQL config](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/scan-from-the-command-line/specifying-command-options-in-a-codeql-configuration-file), [CLI Guidelines](https://clig.dev/), [Stack Overflow 2025 Survey](https://survey.stackoverflow.co/2025/).

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Polling Interval Override | Critical | `--polling.intervalMs VALUE` overrides `polling.intervalMs` for the current process only. |
| F2 | Agent Worktree Root Override | Critical | `--workspace.root VALUE` overrides Agent Worktree placement using Runtime Settings path resolution. |
| F3 | Global Concurrency Override | Critical | `--agent.maxConcurrentAgents VALUE` overrides the global concurrent-agent cap for the current run. |
| F4 | Agent Turn Limit Override | High | `--agent.maxTurns VALUE` overrides max agent attempt behavior for the current run. |
| F5 | Retry Backoff Override | High | `--agent.maxRetryBackoffMs VALUE` overrides the retry backoff cap for the current run. |
| F6 | Non-Persistence Guarantee | Critical | Overrides never rewrite `.symphony/settings.json` and never change Bootstrap defaults. |
| F7 | Help and Validation Clarity | High | `symphony --help` documents every flag with current-invocation wording, and invalid integers fail startup clearly. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Effective override coverage | 5/5 supported fields | Backend config or CLI tests prove each flag changes effective runtime config. |
| Runtime Contract preservation | 0 byte changes | Test compares `.symphony/settings.json` before and after override startup. |
| Invalid integer rejection | 100% of invalid classes | Tests cover zero, negative, decimal, empty, and non-numeric values. |
| Path resolution coverage | 3/3 path classes | Tests cover relative, absolute, and home-relative `--workspace.root`. |
| Help coverage | 5/5 flags documented | Help-output test checks each flag and current-invocation wording. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Maybe |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Strong |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win with a Compounding Feature policy.

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| CLI parser | Add runtime-only flags to the default `symphony` command in `apps/backend/bin/main.ml`. |
| Runtime Settings loading | Apply typed overrides after `.symphony/settings.json` load and before readiness, server, manual merge, Terminal Console, Web Dashboard, and orchestration use config. |
| Path resolution | Reuse the existing Runtime Settings path resolver for `workspace.root`. |
| Orchestration | Effective config controls polling interval, Agent Worktree creation, global concurrency, retry backoff, and max turns. |
| Runtime Home validation | Keep Workspace Repository root validation before overrides are applied. |

## Council Insights

- **Recommended approach:** Keep V1 as a fixed issue-66 allowlist and normalize flags into a typed internal override record at the Runtime Settings load boundary.
- **Key trade-offs:** Narrow allowlist preserves delivery speed; typed internal model prevents scattered config mutation. Full generic overrides are out of scope.
- **Risks identified:** `--workspace.root` may be mistaken for a Workspace Repository selector; `--agent.maxTurns` must map to real runtime behavior; invalid numeric values must fail closed.
- **Stretch goal (V2+):** Add effective-config diagnostics showing which Runtime Settings values came from the Runtime Contract vs invocation overrides.

## Out of Scope (V1)

- **Generic dot-path override system** — Too broad for issue 66 and risks creating an accidental Runtime Settings mutation platform.
- **Persistent settings rewrites** — Violates the current-invocation requirement and creates Runtime Contract churn.
- **Overrides for tracker, project, Git policy, Stage Agent, Agent Harness, pull request, or Protected Path Policy** — These are Runtime Contract semantics, not one-run tuning values.
- **Support on `symphony init`, `symphony update`, or legacy positional `WORKFLOW.md` mode** — V1 targets the default runtime command only.
- **Effective-config diagnostics command** — Valuable later, but not required to solve the immediate automation ergonomics problem.

## Architecture Decision Records

- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — V1 uses a fixed allowlist with process-local behavior and typed internal override application.

## Open Questions

- Should `--agent.maxTurns` ship only after orchestration proves `agent.maxTurns` is currently enforced?
- If the same override flag is repeated, should Cmdliner's observed behavior be documented as-is or should Symphony reject duplicates explicitly?
- Should help output include examples for common automation runs, or keep wording limited to flag descriptions?
