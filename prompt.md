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

# Compozy PRD Run Stage

Run: compozy:tui-jsx-api
PRD directory: tui-jsx-api
Task step status: completed
Completed task steps: 6/6

## Completed Compozy Task Steps

- task_01.md: Add `Tui.Jsx` Namespace And Core Wrapper Conventions
- task_02.md: Add JSX Wrappers For Existing Components
- task_03.md: Add JSX Wrappers For Existing Patterns
- task_04.md: Add JSX `agent_workspace` Parity Example
- task_05.md: Document JSX Quickstart, Supported Surface, And Migration Path
- task_06.md: Finalize TUI Package Verification And Bundle Readiness

## PRD (`_prd.md`)

# TUI JSX API PRD

## Overview

Build an adoption-ready JSX authoring kit for `symphony-orchestrator-tui`. The feature gives Reason/OCaml developers a familiar, tree-shaped way to build standalone terminal tools while keeping direct component calls available as the lower-level API.

The primary product outcome is external adoption. A new package evaluator should be able to land on the TUI docs, understand that JSX is the recommended path for new screens, and build a small standalone terminal UI without reading Symphony-specific source code first.

## Goals

- Make JSX the recommended authoring path for new TUI screens.
- Help a new user build a small standalone TUI from docs in under 30 minutes.
- Provide public examples that make the package easier to evaluate without reading internal Symphony code.
- Preserve current TUI behavior for existing users.

## User Stories

- As a Reason/OCaml developer, I want JSX-style TUI examples so I can quickly understand how to compose screens.
- As a package evaluator, I want a clear recommended path so I can decide whether the library fits my project.
- As an existing TUI user, I want direct component calls to remain supported so my current code keeps working.
- As a maintainer, I want docs and examples that reduce repeated onboarding explanation.

## Core Features

1. **Recommended JSX Authoring Path**: Public docs present JSX as the default for new TUI screens.
2. **Standalone Quickstart**: A short path from install to a working terminal screen.
3. **Public JSX Examples**: At least three runnable examples covering basic layout, dashboard/status UI, and workflow-oriented UI.
4. **Migration Guidance**: Explain how existing direct component-call examples map to JSX.
5. **Supported Surface Guide**: Make clear which components are ready for JSX use in V1.
6. **Compatibility Messaging**: State that direct components remain supported as the lower-level API.

## User Experience

A new user lands on the TUI README, sees JSX as the recommended path, runs a quickstart, and gets a small terminal UI working without understanding Symphony internals. They can then open examples that match common standalone terminal-tool needs: simple layout, status/dashboard display, and command-center style workflow UI.

Existing users should not feel forced into migration. The docs should frame JSX as the recommended path for new screens and direct components as stable lower-level primitives.

## High-Level Technical Constraints

- The JSX kit must preserve existing TUI rendering behavior from a user perspective.
- The package must remain useful to standalone Reason/OCaml users, not only Symphony contributors.
- JSX docs must not imply React runtime compatibility.
- Existing direct component-call usage remains supported.

## Non-Goals (Out of Scope)

- Full Terminal Console migration.
- React runtime compatibility.
- Covering every TUI component or pattern in V1.
- A new state-management model.
- Deprecating direct `Tui.Components` or `Tui.Patterns` usage.

## Phased Rollout Plan

### MVP (Phase 1)

- Publish JSX quickstart, supported surface guide, migration notes, and 2-3 runnable examples.
- Success: a new user can build a small standalone TUI from docs in under 30 minutes.

### Phase 2

- Expand examples based on V1 gaps and user feedback.
- Success: common standalone terminal-tool layouts no longer require reading lower-level examples first.

### Phase 3

- Consider positioning JSX as the main authoring story across all new public examples.
- Success: docs, examples, and maintainer guidance consistently point new users to JSX first.

## Success Metrics

- New-user quickstart completion: under 30 minutes.
- Public example coverage: at least 3 JSX examples.
- Documentation coverage: quickstart, supported surface, migration guidance, compatibility notes.
- Adoption clarity: README names JSX as the recommended path for new TUI screens.
- Compatibility confidence: direct component-call path remains documented and supported.

## Risks and Mitigations

- **Risk: users think direct components are deprecated.** Mitigation: explicitly document them as stable lower-level primitives.
- **Risk: JSX default feels overpromised if V1 surface is too small.** Mitigation: publish a clear supported surface guide.
- **Risk: examples look polished but do not help real users build.** Mitigation: anchor success on the 30-minute standalone build path.
- **Risk: external docs drift toward Symphony-specific terminology.** Mitigation: write examples for standalone terminal tools first.

## Architecture Decision Records

- [ADR-001: Constrain JSX TUI V1 To An Existing Node Authoring Layer](adrs/adr-001.md) - Superseded conservative scope.
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) - Accepted public JSX kit direction.
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) - Accepted external-adoption-first PRD approach.

## Open Questions

- Final supported JSX component set for V1.
- Exact three public examples to include.
- Whether migration guidance should include before-and-after snippets for every supported component.

## Research Sources

- [Reason JSX](https://reasonml.github.io/docs/en/jsx)
- [ReasonReact JSX](https://reasonml.github.io/reason-react/docs/en/jsx)
- [OpenTUI React bindings](https://opentui.com/docs/bindings/react/)
- [Ink](https://github.com/vadimdemedes/ink)
- [Stack Overflow Developer Survey 2025](https://survey.stackoverflow.co/2025/technology)
- [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/)

## TechSpec (`_techspec.md`)

# TUI JSX API TechSpec

## Executive Summary

Implement the TUI JSX API as public Reason wrapper modules over existing `Tui.Components` and `Tui.Patterns`. The wrappers expose JSX-friendly `make` functions, require explicit text nodes, return `Tui.Node.t`, and preserve direct component calls as the lower-level API.

Primary trade-off: broad V1 wrapper coverage improves external adoption but increases parity and documentation work. The design keeps risk contained by avoiding a second renderer, separate component tree, or implicit string-child conversion.

## System Architecture

### Component Overview

- **Tui.Jsx**: Public module namespace for JSX authoring wrappers.
- **JSX wrapper modules**: Thin wrappers around existing `Components` and `Patterns`.
- **Existing TUI model**: `Tui.Node.t` remains the only rendered tree shape.
- **Examples**: Add JSX examples, with `agent_workspace` as the first parity target.
- **Docs**: Update README and examples index to present JSX as the recommended path for new screens.

## Implementation Design

### Core Interfaces

Reason implementation shape:

```reason
module Text = {
  let make = (~id=?, ~style=Style.default, ~value) =>
    Components.text(~id?, ~style, value);
};

module Box = {
  let make = (~id=?, ~style=Style.default, ~children) =>
    Components.box(~id?, ~style, children);
};
```

Required contract sketch for task planning:

```go
type JSXComponent interface {
    Render(children []TuiNode) TuiNode
}

type TuiNode struct {
    ID       string
    Kind     string
    Children []TuiNode
}
```

### Data Models

- No new persisted data model.
- `Tui.Node.t` remains the only runtime tree model.
- JSX children are typed lists of `Tui.Node.t`.
- Text content is explicit through text-node wrappers, not implicit string children.

### API Endpoints

None. This is a package authoring surface, not a server feature.

## Integration Points

No external service integration. The only integration boundary is the existing public `symphony-orchestrator-tui` package export surface.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/tui/lib/tui.re` | Modified | Exports the JSX namespace. Medium risk if public API names collide. | Add `Jsx` module export carefully. |
| `apps/tui/lib/components/*` | Referenced | Existing behavior is the semantic source of truth. Low risk if wrappers stay thin. | Do not alter component semantics for JSX. |
| `apps/tui/lib/patterns.re` | Referenced | Most patterns get JSX wrappers, excluding edge-case presets. Medium coverage risk. | Prioritize patterns used by `agent_workspace`. |
| `apps/tui/examples/agent_workspace.ml` | Modified or paired | First parity target. Medium risk if example behavior drifts. | Add JSX version and compare rendered output. |
| `apps/tui/README.md` | Modified | Main external adoption path. | Add quickstart, supported surface, and compatibility guidance. |
| `apps/tui/test/test_tui.re` | Modified | Parity and wrapper coverage tests. | Add focused JSX tests. |

## Testing Approach

### Unit Tests

- Verify wrappers return rendered output equivalent to direct components for representative primitives.
- Cover explicit text-node behavior.
- Cover most supported `Components` and `Patterns` wrappers enough to prevent drift.

### Integration Tests

- Render the JSX `agent_workspace` example and compare against the direct-call target.
- Run package-level TUI tests through `pnpm --filter @symphony-orchestrator/tui test`.

## Development Sequencing

### Build Order

1. Add `Tui.Jsx` namespace and minimal wrapper conventions - no dependencies.
2. Add core wrappers for text, box, row, column, and panel - depends on step 1.
3. Add broad wrappers for existing `Components` and `Patterns`, excluding presets - depends on step 2.
4. Add JSX `agent_workspace` parity example - depends on step 3.
5. Add focused wrapper and rendered parity tests - depends on steps 3 and 4.
6. Update README, examples index, supported surface guide, and migration notes - depends on steps 3 through 5.
7. Run TUI package verification - depends on steps 1 through 6.

### Technical Dependencies

- Existing Reason support in the package remains required.
- No new runtime package should be introduced unless the implementation proves Reason JSX support cannot work with current tooling.
- Dune/opam package metadata must stay consistent with the public package surface.

## Monitoring and Observability

No runtime monitoring is required. The useful visibility is package-level:

- Test coverage for wrapper parity.
- Example render stability.
- Documentation completeness against the 30-minute quickstart goal.

## Technical Considerations

### Key Decisions

- **Wrapper modules over existing components**: preserves `Tui.Node.t` and current renderer behavior.
- **Explicit text nodes**: avoids hidden string coercion and keeps child typing predictable.
- **Broad V1 coverage**: supports adoption-ready positioning, with presets excluded to control scope.
- **`agent_workspace` parity target**: exercises realistic standalone command-center composition.
- **TUI-only verification**: keeps completion scoped to the changed package.

### Known Risks

- Wrapper drift from direct components. Mitigation: parity tests and thin delegation.
- Broad coverage delays delivery. Mitigation: prioritize wrappers needed for `agent_workspace`.
- User confusion around explicit text nodes. Mitigation: quickstart explains the rule early.
- Public API naming collisions. Mitigation: isolate wrappers under `Tui.Jsx`.

## Architecture Decision Records

- [ADR-001: Constrain JSX TUI V1 To An Existing Node Authoring Layer](adrs/adr-001.md) - Superseded conservative scope.
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) - Accepted public JSX kit direction.
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) - Accepted external-adoption-first PRD approach.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) - Accepted technical wrapper-module architecture.

