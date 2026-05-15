# Optional Docker Sandbox for Local Agent Execution

## Overview

Personal Symphony should offer an optional Docker-based sandbox for agent execution in a **Workspace Repository** so local developers can run agents with higher confidence on their personal machine. The feature targets users who want stronger isolation than direct host execution, but do not want to move their workflow to a VPS or hosted environment.

The V1 should be a focused **Strategic Bet**: one optional Docker provider, disabled by default, configured through the **Runtime Settings** in the **Runtime Contract**, and designed to feel fast enough for repeated local use. The value is not “containers for everything.” The value is making local agent runs feel trustworthy without turning the product into a full dev-environment platform.

### Summary / Differentiator

Most agent tools frame sandboxing as either fully local-and-unsafe or fully remote-and-managed. Personal Symphony can differentiate by giving local users a clear middle ground: keep orchestration in the **Workspace Repository**, but move agent command execution into an explicit, reusable sandbox boundary that is visible in the **Runtime Contract**.

## Problem

Today, Personal Symphony launches the selected Agent Harness directly on the host inside the current **Agent Worktree**. That is operationally simple, but it creates trust friction for local developers. A user running on a personal laptop may accept agent help for planning or code edits, yet still hesitate to let the same agent execute arbitrary commands on the host machine. The problem is not only accidental file mutation. It is also perceived loss of control: users do not have a clear boundary between “agent work inside my repository” and “agent actions on my computer.”

This trust problem is large enough to affect product adoption. In Docker’s 2025 State of Application Development report, 64% of developers said they primarily use non-local development environments, and container usage among IT respondents reached 92%. CNCF’s 2024 annual survey reported that 91% of organizations use containers in production. The market signal is clear: developers increasingly expect execution boundaries to be explicit, reproducible, and governable.

For Personal Symphony, the current direct-host model is still valid for some operators, especially those running on disposable VPS infrastructure. That is why this capability must remain optional. The product problem is not “replace host execution everywhere.” The product problem is “give local users a safer execution mode that is easy to enable, clear to reason about, and fast enough to keep using.”

### Market Data

- Docker reported in its 2025 survey that **64% of developers primarily use non-local development environments** and **92% of IT respondents use containers**.
- CNCF reported in its 2024 annual survey that **91% of organizations use containers in production**.
- Comparable agent/dev-environment products already normalize explicit sandbox selection:
  - OpenHands exposes `docker`, `process`, and `remote` sandbox modes.
  - Coder and GitHub Codespaces optimize for reusable containerized environments and warm starts.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Optional Sandbox Mode | Critical | Add a `sandbox` section to Runtime Settings so a Workspace Repository can enable or disable agent sandboxing without changing the default host-based behavior for everyone. |
| F2 | Docker Provider V1 | Critical | Support one V1 sandbox provider, `docker`, for launching the selected Agent Harness inside a Docker container while keeping orchestration on the host. |
| F3 | Explicit Safety Contract | Critical | Make the important trust boundaries visible in Runtime Settings: whether the sandbox is active, which image is used, whether the Agent Worktree is writable, whether persistence is enabled, whether network access is allowed, and what CPU/memory limits apply. |
| F4 | Warm Reuse Without Hidden Drift | High | Reuse sandbox state across feature runs to reduce startup time, but constrain persistence so the authoritative repository state remains in the host Agent Worktree and reusable state is limited to approved cache-like storage. |
| F5 | Deterministic Sandbox Lifecycle | High | Give the runtime clear behavior for create, reuse, reset, and recreate so sandbox state does not become invisible operational debt. |
| F6 | Least-Privilege Defaults | High | Default the sandbox to minimal writable scope, bounded resources, and allowlisted environment propagation so the safe path does not require expert configuration. |
| F7 | Runtime Visibility | Medium | Surface whether a task is running sandboxed, what provider is active, and whether the runtime reused or recreated the sandbox instance. |

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| `settings.json` in the Runtime Contract | Adds a new `sandbox` settings block with opt-in behavior. |
| Agent Harness launch path | Redirects command execution from direct host launch to sandboxed execution when enabled. |
| Agent Worktree management | Keeps the Agent Worktree as the authoritative repository state and mount source for sandboxed runs. |
| Runtime Home bootstrap | Adds secret-free default examples and documentation for the sandbox settings shape. |
| Runtime State / dashboard | Reports whether current work is using a sandbox and whether reuse or reset occurred. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Sandbox adoption for local setups | `>= 25%` of local-machine Runtime Homes enable sandbox mode within 90 days | Count Runtime Homes with `sandbox.active = true` among installations that identify as local-machine usage through opt-in telemetry or dogfooding samples |
| Warm sandbox startup time | `p95 < 8s` after first successful setup | Measure elapsed time from dispatch start to harness execution for reused sandbox runs |
| Cold sandbox startup time | `p95 < 90s` on first setup with image already available | Measure first-run initialization time for sandbox-enabled Workspace Repositories |
| Success parity with host mode | `>= 90%` of tasks that pass in host mode also pass in sandbox mode in dogfooding | Compare completion outcomes for representative internal task suites across both modes |
| Host-safety incidents | `0` confirmed writes outside approved mounted Workspace Repository paths during sandboxed runs | Audit bug reports, test fixtures, and protected-path validation logs |
| Retained sandbox usage | `>= 70%` of users who enable sandbox mode keep it enabled for at least 14 days | Track repeated enabled runs across the same Runtime Home in dogfooding or opt-in telemetry |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Must do |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Ship one optional Docker sandbox provider in V1, keep orchestration on the host, and make the safety boundary explicit in Runtime Settings.
- **Key trade-offs:** Faster warm starts require some reuse, but broad mutable container reuse creates hidden state drift; a tiny config is easier to adopt, but critical trust boundaries must still be visible in the Runtime Contract.
- **Risks identified:** Writable bind mounts that are too broad, reused state contaminating later runs, resource exhaustion on developer laptops, secrets leaking into the sandbox, and a “sandbox” label that overpromises relative to actual isolation.
- **Stretch goal (V2+):** Expand from Docker-only local isolation to a broader sandbox model with additional providers or stronger policy controls, but only after V1 proves real adoption and trust gains.

## Out of Scope (V1)

- **Multiple sandbox providers** — V1 should not include `remote`, `process`, Kubernetes, or Compose-style providers because provider breadth expands the testing and support matrix before value is proven.
- **Automatic tool installation orchestration inside the sandbox** — Open-ended mutation via a `tools` installer model should stay out of V1 because it increases drift and support burden; V1 should prefer image-defined capability with tightly scoped cache persistence.
- **Broad writable host mounts** — Mounting the full host home directory, broad Runtime Home write access, or arbitrary extra mount expansion should remain out of scope because it weakens the core safety promise.
- **Full dev-environment management** — Personal Symphony should not become a Codespaces-like workspace platform in V1.
- **Advanced networking and port-publishing controls** — Fine-grained network shaping, published ports, or host networking should be deferred unless a real task class proves they are necessary.
- **Snapshotting and restore semantics** — Full sandbox snapshots add complexity and hidden state before the product has validated basic sandbox value.

## Architecture Decision Records

- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](adrs/adr-001.md) — V1 uses one optional Docker provider with explicit lifecycle and constrained persistence.

## Open Questions

- Should the user-facing config expose `type` only, or a more future-proof `provider` field from day one?
- Should persistence be represented as a simple boolean or as an explicit lifecycle mode with tightly constrained allowed values?
- How much Git metadata must be accessible from inside the sandbox for reliable Task Branch operations?
- What is the minimum image contract required for supported Agent Harnesses across Node, OCaml, and other project toolchains?
- What product language best explains that sandboxing improves local safety without implying perfect isolation?
