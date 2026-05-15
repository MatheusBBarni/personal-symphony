# Optional Docker Sandbox for Local Agent Execution

## Executive Summary

This feature adds an optional, repository-owned Docker sandbox to Personal Symphony by extending the existing **Runtime Settings**, **Readiness Gap**, and launch-path architecture instead of introducing a second orchestration model. When `sandbox.enabled` is `true`, Symphony validates sandbox prerequisites during config/runtime readiness, blocks orchestration if those prerequisites are not met, and launches the selected **Agent Harness** inside a repository-scoped Docker container while preserving existing **Agent Worktree**, **Task Branch**, prompt, log, and retry semantics.

The primary technical trade-off is explicit: V1 favors a narrow integration with existing launch and readiness seams over a larger execution abstraction. That keeps the implementation reversible and aligned with current architecture, but it also means Docker-specific behavior remains close to orchestrator and config code in V1.

## System Architecture

### Component Overview

- `Config` in [config.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml): parse `sandbox` from the **Runtime Settings**, validate static shape, and emit sandbox-related **Readiness Gaps** only when `sandbox.enabled = true`.
- `Runtime_readiness` and `Runtime_policy` in [runtime_readiness.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_readiness.ml) and [runtime_policy.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_policy.ml): aggregate sandbox gaps into the existing startup/runtime blocking path so Terminal Console and Web Dashboard both show the same blocked state.
- New `Sandbox_runtime` helper module: plan Docker command lines, derive repository-scoped container identity, inspect reuse health, run first-create bootstrap commands, and return launch metadata to orchestrator. This is one new backend helper file, not a new subsystem.
- `Orchestrator` in [orchestrator.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/orchestrator.ml): keep ownership of worktree creation, prompt writing, stdout/stderr files, and child tracking; wrap `shell_launch` with sandbox-aware command construction when sandboxing is enabled.
- `Runtime_home` in [runtime_home.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_home.ml): add secret-free sandbox examples to bootstrap defaults while preserving idempotent file creation.
- `Runtime_state`, `Server`, and dashboard projection in [runtime_state.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_state.ml), [server.ml](/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/server.ml), and [RuntimeStateSnapshot.res](/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/lib/ocaml/RuntimeStateSnapshot.res): surface sandbox readiness and moderate running-state visibility.

### Data Flow

1. Symphony loads the **Runtime Contract** from `.symphony/settings.json`.
2. `Config` parses `sandbox`; if `sandbox.enabled = true`, it validates shape and local prerequisites.
3. `Runtime_readiness.state` adds sandbox readiness gaps to the existing runtime snapshot.
4. `Runtime_policy.action` blocks orchestration if any readiness gaps remain.
5. When orchestration runs, `Orchestrator` prepares the **Agent Worktree** as usual.
6. Launch logic asks `Sandbox_runtime` for either a host launch plan or a Docker launch plan.
7. The selected **Agent Harness** still reads the prompt from the worktree and writes `stdout.log` / `stderr.log` in the same worktree.
8. Running-state snapshots include sandbox summary fields for terminal and dashboard projection.

## Implementation Design

### Core Interfaces

```go
type SandboxConfig struct {
    Enabled           bool
    Type              string
    Image             string
    BootstrapCommands []string
    Persistent        bool
    NetworkEnabled    bool
    CPULimit          int
    MemoryMB          int
}
```

```go
type SandboxRuntime interface {
    ReadinessGaps(cfg SandboxConfig, repoRoot string) []ReadinessGap
    EnsureLaunchPlan(cfg SandboxConfig, repoRoot string, worktree string, command string) (SandboxLaunchPlan, error)
}
```

```go
type SandboxLaunchPlan struct {
    Command      string
    Provider     string
    ReuseOutcome string
    Container    string
}
```

Error handling conventions:
- Static config errors become `Config.readiness_gap` entries.
- Environment and health probe failures that can be detected pre-run become runtime readiness gaps.
- Launch-time Docker failures return `Error string` through the existing launch flow and follow current retry/attention behavior.

### Data Models

#### Runtime Settings

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `sandbox.enabled` | `bool` | yes | Main repository toggle. If `false`, sandboxing is ignored entirely. |
| `sandbox.type` | `string` | yes when enabled | V1 accepts only `docker`. |
| `sandbox.image` | `string` | yes when enabled | Base image used for the repository-scoped sandbox container. |
| `sandbox.bootstrapCommands` | `string[]` | no | Runs only on first container creation or explicit recreation. |
| `sandbox.persistent` | `bool` | yes when enabled | V1 should require `true` because the selected reuse model is named-container reuse. |
| `sandbox.networkEnabled` | `bool` | yes when enabled | Explicit user-facing boundary. |
| `sandbox.cpuLimit` | `int` | yes when enabled | Positive integer. |
| `sandbox.memoryMb` | `int` | yes when enabled | Positive integer. |

#### Internal Backend Model

| Entity | Fields | Purpose |
| --- | --- | --- |
| `Config.sandbox` | parsed settings record | Effective sandbox configuration for the **Workspace Repository** |
| `Sandbox_instance` | `container_name`, `repository_root_hash`, `config_hash`, `image`, `created_at` | Derived runtime identity for the reusable repository-scoped container |
| `Sandbox_launch_plan` | `command`, `provider`, `reuse_outcome`, `container_name` | One launch decision returned to orchestrator |
| `Runtime_state.running.sandbox_*` | enabled/provider/reuse outcome | Moderate runtime visibility for running tasks |

#### Runtime State Additions

| Field | Location | Type |
| --- | --- | --- |
| `sandbox_enabled` | running issue row | `bool option` |
| `sandbox_provider` | running issue row | `string option` |
| `sandbox_reuse_outcome` | running issue row | `string option` |

`reuse_outcome` allowed values:
- `created`
- `reused`
- `recreated`

### API Endpoints

V1 adds no new user-initiated API surface.

Existing internal runtime-state surfaces will be extended:
- `GET /api/v1/state`
- WebSocket `GET /api/v1/state/live`

Response changes:
- running issue objects gain sandbox summary fields
- readiness gaps may include sandbox-related requirements such as `sandbox.type`, `sandbox.image`, `sandbox.install`, or `sandbox.health`

No request payload changes are required.

## Integration Points

### Docker CLI / Local Docker Engine

- Purpose: create, inspect, start, and execute commands inside the repository-scoped sandbox container.
- Invocation approach: reuse local shell/process execution helpers already used elsewhere in backend code.
- Auth model: no application-level auth; relies on local Docker access already granted to the operator environment.
- Failure handling: sandbox availability or daemon failures should surface as readiness gaps when detectable before orchestration; launch-time failures should use existing task failure handling.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `apps/backend/lib/config.ml` | modified | Add `sandbox` record, JSON parsing, validation, and readiness rules; medium risk because config is central | Extend types, parser, and readiness checks |
| `apps/backend/lib/runtime_readiness.ml` | modified | Add sandbox runtime checks when enabled; low-medium risk | Aggregate sandbox runtime readiness |
| `apps/backend/lib/runtime_policy.ml` | modified | No semantic redesign, but sandbox gaps must block orchestration; low risk | Reuse existing readiness action |
| `apps/backend/lib/orchestrator.ml` | modified | Wrap host launch with sandbox-aware launch plan while preserving worktree/log semantics; medium-high risk | Integrate `Sandbox_runtime` plan into launch path |
| `apps/backend/lib/runtime_home.ml` | modified | Add sandbox examples without breaking idempotent bootstrap; low risk | Update embedded `settings.json` example |
| `apps/backend/lib/runtime_state.ml` | modified | Add sandbox fields to running-state payload; low risk | Extend snapshot schema |
| `apps/backend/lib/server.ml` | modified | Snapshot endpoints inherit new state fields; low risk | No route changes, only payload propagation |
| `apps/frontend/lib/ocaml/RuntimeStateSnapshot.res` | modified | Map new sandbox fields into dashboard snapshot model; low risk | Extend snapshot conversion |
| `apps/frontend/src/Pages/Dashboard.res` | modified | Display moderate sandbox status and reuse outcome; low risk | Add concise UI treatment |
| `apps/backend/test/test_backend.ml` | modified | Add config, readiness, launch, state, and dashboard snapshot tests; medium risk due to file size | Extend targeted existing suites |
| `apps/backend/lib/sandbox_runtime.ml` | new | Small helper for Docker-specific planning and health checks; low-medium risk | Add new helper file and focused tests |
| `CONTEXT.md` | modified | New runtime term(s) such as sandbox may need glossary coverage | Add or update domain language if implementation introduces stable terms |

## Testing Approach

### Unit Tests

- `Config` parsing:
  - parses `sandbox.enabled`
  - requires Docker-only `sandbox.type`
  - validates required fields only when enabled
  - rejects invalid bootstrap command entries
  - emits no sandbox gaps when disabled
- `Sandbox_runtime`:
  - derives deterministic container name from **Workspace Repository**
  - computes recreate vs reuse based on config hash and health
  - builds expected Docker command with worktree-mounted stdout/stderr semantics
- `Runtime_state`:
  - serializes sandbox running fields correctly
  - omits fields when sandboxing is disabled

### Integration Tests

- readiness:
  - sandbox-enabled config blocks runtime when Docker executable/daemon/image requirements fail
  - sandbox-disabled config behaves exactly like today
- launch:
  - sandbox-enabled launch still runs in the **Agent Worktree**
  - prompt file is still read from the worktree
  - `stdout.log` and `stderr.log` still appear under the same worktree
  - selected **Agent Harness** identity remains correct
- state surfaces:
  - `GET /api/v1/state` includes sandbox fields
  - `/api/v1/state/live` snapshots include sandbox fields
  - readiness snapshot includes sandbox-specific gaps
- invariants:
  - protected-path behavior remains unchanged
  - **Task Branch** and **Agent Worktree** semantics remain unchanged

Environment dependencies:
- unit tests should stub Docker command execution
- integration-style tests can use injected `launch` and shell helpers, following existing orchestrator test patterns instead of requiring a real Docker daemon in CI

## Development Sequencing

### Build Order

1. Extend `Config` with sandbox types, parser, and readiness validation - no dependencies.
2. Extend `Runtime_readiness` to add sandbox runtime checks when `sandbox.enabled = true` - depends on step 1.
3. Add `sandbox_runtime.ml` with container identity, health, bootstrap, and command-plan helpers - depends on step 1.
4. Integrate sandbox-aware launch planning into `Orchestrator.shell_launch` while preserving current worktree/log/session semantics - depends on steps 1 and 3.
5. Add sandbox fields to `Runtime_state` and snapshot serialization - depends on step 4.
6. Extend `server.ml`, `RuntimeStateSnapshot.res`, and `Dashboard.res` for moderate runtime visibility - depends on step 5.
7. Update `runtime_home.ml` bootstrap examples and any required glossary/docs - depends on step 1.
8. Add and refine backend/frontend tests across config, readiness, launch, runtime state, and dashboard projections - depends on steps 1 through 6.

### Technical Dependencies

- Local Docker CLI must be detectable when sandboxing is enabled.
- Docker daemon reachability must be probeable from runtime readiness code.
- The chosen image contract must support the selected **Agent Harness** command set.
- If stable new runtime terms are introduced, `CONTEXT.md` must be updated to preserve domain language consistency.

## Monitoring and Observability

- Key metrics:
  - count of sandbox readiness gaps by requirement
  - count of sandbox launches by provider
  - reuse outcome counts: `created`, `reused`, `recreated`
  - sandbox launch failure count
- Log events:
  - sandbox readiness evaluation result
  - container create/reuse/recreate decision
  - bootstrap command execution start/finish
  - sandbox launch command plan summary without secrets
- Alerting thresholds:
  - repeated sandbox launch failures for the same **Workspace Repository**
  - high recreate rate indicating unstable reuse
  - bootstrap command failures on first-create paths

## Technical Considerations

### Key Decisions

- Decision: keep sandboxing as a top-level **Runtime Settings** block rather than a new **Agent Harness** kind.
  Rationale: sandboxing is repository-level execution policy, not logical-agent backend selection.
  Trade-off: less future abstraction in V1.
  Alternatives rejected: harness-kind modeling, launch-only implicit config.

- Decision: enforce sandbox readiness primarily through `Config.readiness_gaps` and `Runtime_readiness` when `sandbox.enabled = true`.
  Rationale: preserves strict blocking across CLI, Terminal Console, and Web Dashboard.
  Trade-off: more startup validation code.
  Alternatives rejected: launch-only validation.

- Decision: attach sandboxing at the launch boundary and preserve orchestrator ownership.
  Rationale: current `launch` seam is already strong and minimizes regression risk.
  Trade-off: some Docker-specific logic remains close to orchestrator.
  Alternatives rejected: full execution subsystem rewrite.

- Decision: reuse a named container per **Workspace Repository** and run bootstrap commands only on first create or explicit recreation.
  Rationale: matches the selected warm-start model.
  Trade-off: introduces container lifecycle drift risks that must be constrained.
  Alternatives rejected: per-run fresh containers.

### Known Risks

- Repository-scoped container reuse can accumulate stale state.
  Mitigation: derive config hash, recreate on mismatch, and surface `reuse_outcome`.

- Startup readiness and launch-time reality can diverge if checks are incomplete.
  Mitigation: keep static checks in readiness and treat launch failures as explicit task failures with clear diagnostics.

- Bootstrap commands can become an uncontrolled mutation surface.
  Mitigation: limit them to first-create/recreate semantics and validate them as a list of non-empty commands.

- Dashboard visibility can become noisy.
  Mitigation: keep V1 to moderate fields only: enabled, provider, reuse outcome.

## Architecture Decision Records

- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](adrs/adr-001.md) — V1 uses one optional Docker provider with explicit lifecycle and constrained persistence.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](adrs/adr-002.md) — Sandbox-enabled repositories block execution when sandboxing is unavailable rather than falling back to host mode.
- [ADR-003: Model Sandbox as a Repository-Owned Runtime Settings Block With Startup Readiness Gating](adrs/adr-003.md) — `sandbox.enabled` governs a top-level settings block and readiness only applies when enabled.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](adrs/adr-004.md) — sandbox execution wraps the existing launch path and reuses one named container per repository.
