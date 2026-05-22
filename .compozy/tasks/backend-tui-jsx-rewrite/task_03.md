---
status: pending
title: Convert Leaf Node And Text Rendering Helpers To Literal JSX
type: backend
complexity: medium
dependencies:
  - task_02
---

# Task 3: Convert Leaf Node And Text Rendering Helpers To Literal JSX

## Overview
Rewrite the lowest-level Terminal Console view helpers to use literal `Tui.Jsx` tags. This establishes JSX rendering parity for text, rich text, log rows, footer segments, tab labels, and command help rows before converting larger layout containers.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST convert `Tui.Node.t` producing leaf helpers to literal `Tui.Jsx` tags where current JSX wrappers can express exact output.
2. MUST preserve span content, style attributes, tone mapping, spacing, height, margins, no-color distinctions, and empty-state fallback text.
3. MUST keep string shaping, filtering, sanitization, and panel-line generation behavior unchanged.
4. MUST not add new reusable TUI wrappers in this task unless the helper cannot be represented with the current JSX surface and the gap blocks exact parity.
5. SHOULD leave non-node helper functions in their current shape unless a small syntax adjustment is needed by JSX conversion.
</requirements>

## Subtasks
- [ ] 3.1 Convert plain text line helper output to JSX-backed nodes with identical style and fallback behavior.
- [ ] 3.2 Convert content rich-text line helper output to JSX-backed nodes while preserving span construction.
- [ ] 3.3 Convert background log rich-text line helper output to JSX-backed nodes while preserving log-specific fallback text.
- [ ] 3.4 Convert command help row rendering to JSX-backed rich text with identical key and label styling.
- [ ] 3.5 Convert footer and tab node rendering to JSX-backed rich text with identical tone and attribute behavior.
- [ ] 3.6 Add or adjust focused parity assertions for rendered text, log, footer, and tab output if existing tests do not cover the converted helpers.

## Implementation Details
Reference the TechSpec "Development Sequencing" step for leaf node helpers. Keep product-specific span and tone logic in the backend shell module; the TUI package should only receive reusable wrapper changes in the later wrapper-gap task.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` - Reason shell module containing line, log, footer, tab, and command help rendering helpers.
- `apps/tui/lib/jsx.re` - existing JSX wrappers for `Text`, `RichText`, `Row`, `Column`, and related primitives.
- `apps/tui/test/test_tui.re` - JSX wrapper parity examples to follow if a reusable wrapper gap is discovered.
- `apps/backend/test/test_backend.ml` - Terminal Console tests for no-color labels, footer help content, logs, panels, and rendering fixtures.

### Dependent Files
- `apps/backend/bin/terminal_console_preview.ml` - preview output should remain stable after leaf rendering conversion.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - comparison source for visible leaf output.
- `apps/tui/examples/agent_workspace_jsx.re` - style reference for literal Reason JSX syntax.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Requires complete JSX coverage for backend Terminal Console UI construction.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Requires behavior and visual hierarchy parity.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Selects literal Reason JSX as the implementation approach.

## Deliverables
- Leaf `Tui.Node.t` helpers rewritten to literal JSX tags.
- Existing span, style, fallback, and tone behavior preserved.
- Focused backend parity coverage added where current tests do not cover leaf-node output.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for preview output after leaf conversion **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Run Terminal Console tests covering footer help content, no-color label distinction, log panel content, and rendered Runtime State fixtures.
  - [ ] Add a focused assertion if the conversion exposes an untested leaf rendering contract such as log fallback text or tab tone attributes.
  - [ ] Run `pnpm test` after backend rendering helper changes.
- Integration tests:
  - [ ] Run `pnpm backend:build` to confirm literal JSX compiles in the backend shell module.
  - [ ] Run `terminal_console_preview` and compare leaf output against the task 1 baseline.
  - [ ] Confirm no `apps/tui` package checks are required unless this task touched `apps/tui`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Leaf helpers that construct text or rich text nodes use literal `Tui.Jsx` tags.
- Operator-visible strings, spacing, tone, and log/content fallback behavior match the baseline.
- No Runtime State, Runtime Settings, lifecycle, or safe-aid semantics are changed.
