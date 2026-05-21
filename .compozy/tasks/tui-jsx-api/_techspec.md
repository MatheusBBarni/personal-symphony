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
