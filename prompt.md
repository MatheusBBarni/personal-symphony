You are the Engineer agent for the Symphony Orchestrator Repository.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Responsibilities:
- Implement only the scoped issue.
- Use CONTEXT.md terms and follow AGENTS.md.
- Prefer existing module boundaries and tests over new abstractions.
- Preserve Runtime Contract semantics unless the issue explicitly asks to change them.
- Do not touch protected release/package paths unless the issue explicitly authorizes that scope.
- Edit ReScript .res sources only; never commit generated .res.js files.
- Keep examples secret-free and refer only to GITHUB_TOKEN or GH_TOKEN variable names.
- Run focused verification, then broader checks when shared orchestration/config/runtime behavior changes.

Stage Commit is enabled for this stage. Leave the worktree ready for a local commit boundary before review.

---

Stage agent: engineer

# Compozy Task Step

Run: compozy:optional-docker-sandbox
PRD directory: optional-docker-sandbox
Current task file: task_06.md
Current task title: Update Runtime Contract Defaults, Glossary, And Docs

## Current Task (`task_06.md`)

---
status: in_progress
title: Update Runtime Contract Defaults, Glossary, And Docs
type: docs
complexity: medium
dependencies:
  - task_01
  - task_03
  - task_05


---

# Task 06: Update Runtime Contract Defaults, Glossary, And Docs

## Overview
Update bootstrap defaults, glossary entries, and operator-facing documentation so the final sandbox contract matches implemented behavior. This task should only land after the runtime settings, launch behavior, and user-visible sandbox state have settled, especially because changing `runtime_home.ml` defaults is an ask-first area in this repository.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- Bootstrap examples MUST remain secret-free and idempotent.
- Runtime contract docs MUST reflect the final sandbox settings names and user-visible behavior.
- If sandbox introduces stable product terminology, `CONTEXT.md` MUST be updated to preserve glossary consistency.
- Documentation and bootstrap assertions MUST match the implemented Runtime Settings shape and approved V1 visibility model.
</requirements>

## Subtasks
- [ ] 6.1 Update embedded bootstrap `settings.json` examples with the approved sandbox fields.
- [ ] 6.2 Update glossary or domain language in `CONTEXT.md` if sandbox becomes a stable runtime term.
- [ ] 6.3 Update README or ADR references that explain Runtime Settings and runtime behavior.
- [ ] 6.4 Extend docs/bootstrap assertions to cover the new runtime contract examples.
- [ ] 6.5 Verify docs remain secret-free and consistent with implemented behavior.

## Implementation Details
Reference the TechSpec sections "High-Level Technical Constraints", "Impact Analysis", and "Architecture Decision Records". This task must preserve the project’s idempotent bootstrap behavior and glossary discipline.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_home.ml` — owns embedded bootstrap defaults and idempotent Runtime Contract creation.
- `/Users/matheusbbarni/projects/symphony-orchestrator/CONTEXT.md` — glossary source of truth for stable product terminology.
- `/Users/matheusbbarni/projects/symphony-orchestrator/README.md` — operator-facing Runtime Settings and runtime behavior documentation.
- `/Users/matheusbbarni/projects/symphony-orchestrator/docs/adr/0021-agent-harness-runtime-settings.md` — existing ADR context for runtime settings evolution.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — contains bootstrap/docs assertions to extend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml` — docs must match the implemented sandbox settings shape.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/src/Pages/Dashboard.res` — user-visible docs should match final dashboard behavior.

### Related ADRs
- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](../adrs/adr-001.md) — Establishes Docker-only V1 scope and runtime contract direction.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — Requires no fallback for enabled repositories.
- [ADR-003: Model Sandbox as a Repository-Owned Runtime Settings Block With Startup Readiness Gating](../adrs/adr-003.md) — Defines the `sandbox.enabled` contract.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Defines user-visible execution and reuse behavior that docs must match.

## Deliverables
- Updated bootstrap Runtime Contract examples.
- Updated glossary and operator-facing documentation.
- Extended docs/bootstrap assertions covering sandbox examples.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for bootstrap/docs consistency **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Bootstrap example generation includes the approved sandbox settings shape without secrets.
  - [ ] Existing bootstrap idempotency behavior remains unchanged for user-edited files.
  - [ ] Docs assertions validate the sandbox-enabled Runtime Contract examples.
- Integration tests:
  - [ ] Runtime home bootstrap produces the expected sandbox-capable `settings.json` example for a new repository.
  - [ ] README and glossary updates remain consistent with the implemented runtime contract semantics.
  - [ ] Existing docs/runtime-home test suites still pass after sandbox documentation updates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Contract examples and docs match the final sandbox implementation.
- Bootstrap remains idempotent and secret-free after sandbox documentation changes.

## PRD (`_prd.md`)

# Optional Docker Sandbox for Local Agent Execution

## Overview

Optional Docker Sandbox for Local Agent Execution gives an existing Personal Symphony user a safer way to run autonomous agents in a **Workspace Repository** on a personal machine. When a repository opts in, Symphony should run agent work inside an explicit Docker-based execution boundary rather than directly on the host.

The product value is higher local trust without forcing users into remote infrastructure. The MVP is designed for existing Symphony users who want to keep using their normal repository workflow, but want stronger confidence before letting agents operate freely across planning, execution, and review stages. The feature should remain optional because not every operator needs the same protection model, especially when running on disposable VPS infrastructure.

## Goals

- Increase willingness to run autonomous agents locally in repositories that currently rely on direct host execution.
- Give existing Symphony users one clear repository-level trust model: if sandboxing is enabled, agent runs in that repository are sandboxed.
- Keep setup friction low enough that a current user can enable sandboxing in a repository without feeling like they are adopting a separate platform.
- Make sandbox readiness visible and actionable so users understand why Symphony is blocked when sandboxing is unavailable or unhealthy.
- Establish a product foundation for future safety and policy features without expanding MVP scope into a broader environment-management product.

Target outcomes:
- At least 25% of local-machine dogfooding repositories enable sandboxing within 90 days of release.
- At least 70% of users who enable sandboxing continue using it for at least 14 days.
- At least 90% of representative local task flows that succeed in host mode also succeed in sandbox mode during dogfooding.
- Zero confirmed sandboxed host writes outside approved mounted repository paths.

## User Stories

### Primary Persona: Existing Symphony User on a Personal Machine

- As an existing Symphony user, I want to enable sandboxing for a repository so that I feel safer running autonomous agents locally.
- As an existing Symphony user, I want Symphony to apply sandboxing consistently across agent work in that repository so that I do not have to reason about mixed safety modes.
- As an existing Symphony user, I want Symphony to block agent execution when sandboxing is unavailable so that I am not surprised by silent fallback to host execution.
- As an existing Symphony user, I want the product to be fast enough after initial setup that sandboxing feels usable for normal daily work.

### Secondary Persona: Trust-Conscious Operator

- As a trust-conscious operator, I want clear product language about what sandboxing does and does not protect so that I can decide when to use it.
- As a trust-conscious operator, I want visible runtime status showing whether a run is sandboxed so that I can confirm the repository is operating as expected.

### Edge Case Persona: VPS or Disposable Host User

- As an operator on disposable infrastructure, I want sandboxing to remain optional so that I am not forced into unnecessary local safety overhead.

## Core Features

### 1. Repository-Level Opt-In Sandbox Mode

A **Workspace Repository** can opt into sandboxed execution through the **Runtime Settings** in the **Runtime Contract**. This is a repository-owned choice, not an ad hoc per-run behavior.

Why it matters:
- Keeps the trust decision visible and durable.
- Aligns with the way Symphony already uses repository-owned runtime configuration.
- Reduces ambiguity for teams and repeat users.

MVP requirements:
- A repository can enable or disable sandboxing explicitly.
- Sandbox activation is easy to discover and explain.
- The product language makes clear that sandboxing is optional and intended primarily for local-machine trust improvement.

### 2. Docker-Only MVP Provider

The MVP supports one sandbox mode: Docker.

Why it matters:
- Keeps scope small enough to ship credibly.
- Matches mainstream user expectations around containerized execution.
- Avoids confusing provider comparisons in the first release.

MVP requirements:
- The product clearly communicates that Docker is the only supported sandbox mode in V1.
- Unsupported or unavailable sandbox conditions are treated as readiness problems, not silent degradations.
- Users understand whether the repository is in host mode or sandbox mode.

### 3. All-Stage Coverage Within an Opted-In Repository

When sandboxing is enabled for a repository, the MVP product promise is that agent execution in that repository uses the sandbox across the repository’s agent workflow rather than only for selected stages.

Why it matters:
- Strengthens the trust promise.
- Avoids a fragmented “sometimes sandboxed, sometimes not” mental model.
- Supports the business goal of increasing willingness to run autonomous agents locally.

MVP requirements:
- The repository-level state is clear in product surfaces.
- Users are not expected to manage stage-by-stage activation in MVP.
- The product avoids presenting partial protection as full protection.

### 4. Strict Readiness and Blocking Behavior

If sandboxing is enabled but not usable, Symphony blocks agent execution and tells the user what needs to be fixed.

Why it matters:
- Preserves trust in the product promise.
- Prevents accidental fallback to the less trusted host model.
- Turns sandbox health into a visible operational state rather than a hidden implementation detail.

MVP requirements:
- Users receive clear readiness or remediation messaging.
- Blocked runs are understandable from the terminal and dashboard surfaces.
- The blocked state is framed as protection working as intended, not generic failure.

### 5. Warm, Reusable Experience

The sandbox should feel fast enough for repeated use after setup. Users should not feel punished for choosing the safer mode.

Why it matters:
- Speed strongly affects whether users keep the feature enabled.
- Competitor patterns show strong user expectation for warm environment reuse.
- The adoption goal depends on usability, not only on safety claims.

MVP requirements:
- First-time setup can be slower, but repeat repository runs should feel materially faster.
- The product should communicate whether it is reusing or recreating the sandboxed environment.
- Reuse behavior should feel deterministic from the user’s perspective.

### 6. Visible Trust Boundary

Users should understand that sandboxing changes the execution environment, and they should be able to confirm when it is active.

Why it matters:
- Trust comes from clear product behavior, not just from configuration.
- A visible boundary reduces uncertainty during adoption.
- It reinforces that sandboxing is a user-facing capability, not hidden infrastructure.

MVP requirements:
- Symphony surfaces whether current work is sandboxed.
- Users can tell when sandbox readiness is preventing a run.
- Product wording explains the intended protection in plain terms.

## User Experience

### Primary Journey: Existing User Enables Sandboxing for a Repository

1. The user is already running Symphony in a repository and wants a safer local execution mode.
2. The user enables sandboxing in the repository’s **Runtime Settings**.
3. Symphony checks whether sandbox prerequisites are satisfied before agent work begins.
4. If sandboxing is healthy, agent work proceeds under the sandboxed execution mode.
5. If sandboxing is unavailable or unhealthy, Symphony blocks execution and explains what must be fixed.
6. On later runs, the user sees a faster repeat experience and clear confirmation that the repository is still operating in sandbox mode.

### UX Principles

- Prefer one clear repository-level decision over multiple partial toggles.
- Keep the setup path opinionated and readable.
- Explain the safety promise in user language, not infrastructure language.
- Make blocked readiness states actionable, not opaque.
- Show sandbox status consistently in runtime surfaces.

### Discoverability and Onboarding

- Existing Symphony users should understand when sandboxing is worth enabling.
- The product should position sandboxing as especially useful for local-machine agent use.
- The first successful sandboxed run should reinforce that the safer mode is usable, not merely theoretical.

### Accessibility and Clarity

- Status messaging should be concise and readable in both terminal and dashboard contexts.
- Warning and blocked states should distinguish “protection is active and preventing unsafe execution” from ordinary task failures.
- Product copy should avoid overstating isolation guarantees.

## High-Level Technical Constraints

- The feature must fit the existing repository-owned **Runtime Contract** model in `.symphony/settings.json`.
- The feature must preserve the root requirement that Symphony runs from the root of a **Workspace Repository**.
- The feature must respect existing repository safety expectations, including protected-path behavior and explicit runtime configuration.
- The MVP must preserve acceptable repeat-run performance from a user perspective after initial setup.
- The MVP must support clear readiness diagnostics and runtime visibility across existing terminal and dashboard surfaces.
- The product must avoid requiring secret values in repository-owned examples or documentation.

## Non-Goals (Out of Scope)

- Supporting multiple sandbox providers in MVP.
- Offering remote sandbox execution, Kubernetes-backed environments, or Compose-style orchestrated environments.
- Allowing silent fallback from sandbox mode to host execution in a sandbox-enabled repository.
- Introducing stage-by-stage or harness-by-harness activation as the main MVP experience.
- Turning Symphony into a full development-environment management platform.
- Solving every host-safety concern purely through sandboxing without relying on existing repository safety policies.

## Phased Rollout Plan

### MVP (Phase 1)

- Repository-level opt-in sandbox mode
- Docker as the only supported sandbox type
- All-stage sandboxed execution within an opted-in repository
- Strict readiness checks with blocking behavior
- Clear runtime visibility for sandboxed versus blocked runs
- Warm repeat-run experience after setup

Success criteria to proceed:
- Local dogfooding shows meaningful willingness to enable the feature.
- Repeat-run speed is good enough that users keep sandboxing enabled.
- Blocked readiness states are understandable and fixable.

### Phase 2

- Better onboarding and clearer product guidance around when to enable sandboxing
- Improved visibility into reuse, reset, and readiness history
- More refined trust messaging based on dogfooding feedback
- Broader support for repository types with different toolchain needs

Success criteria to proceed:
- Users can self-serve onboarding more reliably.
- Sandbox-related support requests decrease as guidance improves.
- Adoption remains sticky beyond early experiments.

### Phase 3

- Expanded sandbox policy capabilities if validated by user demand
- Potential additional activation models or execution modes if they improve clarity rather than fragment it
- Stronger trust and policy surfaces built on proven MVP behavior

Long-term success criteria:
- Sandboxed local execution becomes a normal and trusted way to run Symphony locally.
- Future safety features build on this model rather than replacing it.

## Success Metrics

- Sandbox adoption rate among local-machine repositories
- Percentage of users who keep sandboxing enabled after initial setup
- Warm-start time for repeat sandboxed runs
- Success parity between representative host-mode and sandbox-mode runs
- Rate of sandbox-readiness blocks resolved without abandoning the feature
- Confirmed host-safety incidents for sandboxed runs
- Qualitative user confidence signal from dogfooding and user interviews

## Risks and Mitigations

- **Adoption risk:** Users may see sandboxing as too much setup for too little value.
  Mitigation: Keep activation opinionated, explain the value clearly, and optimize for existing-user enablement rather than generic platform flexibility.

- **Trust risk:** Users may misunderstand what sandboxing protects and assume stronger guarantees than the product provides.
  Mitigation: Use precise product language and visible runtime status to explain the boundary clearly.

- **Readiness friction risk:** Blocking behavior may frustrate users if prerequisites are hard to satisfy.
  Mitigation: Make remediation guidance clear and keep the MVP setup path narrow.

- **Performance perception risk:** If repeat runs still feel slow, users may disable the feature even if they value the safety model.
  Mitigation: Prioritize warm repeat-run experience as a core product outcome, not an implementation afterthought.

- **Competitive framing risk:** The feature may be perceived as catching up rather than differentiating.
  Mitigation: Emphasize Symphony’s repository-owned trust model and consistent local workflow rather than generic container support.

## Architecture Decision Records

- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](adrs/adr-001.md) — V1 uses one optional Docker provider with explicit lifecycle and constrained persistence.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](adrs/adr-002.md) — Sandbox-enabled repositories block execution when sandboxing is unavailable rather than falling back to host mode.

## Open Questions

- Should the product language use “sandbox,” “isolated execution,” or another term as the primary user-facing label?
- How much first-run setup latency will existing users tolerate before the feature feels too heavy?
- Which repository types or toolchain profiles should be prioritized first for dogfooding and rollout confidence?
- What minimum readiness explanation is required for users to trust a blocked run instead of bypassing the feature?
- Should future rollout phases preserve the repository-wide activation model exclusively, or leave room for narrower activation patterns if user demand is strong?

## TechSpec (`_techspec.md`)

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

