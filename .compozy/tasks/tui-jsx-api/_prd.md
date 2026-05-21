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
