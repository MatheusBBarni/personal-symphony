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
