---
status: completed
title: "Adopt Mosaic Dependency And Executable Shell"
type: infra
complexity: medium
dependencies:
  - task_01
---

# Task 02: Adopt Mosaic Dependency And Executable Shell

## Overview
Add Mosaic as the explicit Terminal Console UI dependency and create the minimal executable-side shell needed to compile a Mosaic-backed Terminal Console. This task validates the dependency and build impact before runtime wiring or full panel rendering begins.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST add Mosaic as a direct dependency for the backend executable path that owns the Terminal Console.
- MUST update Dune/opam metadata explicitly, including any Dune version requirement needed by Mosaic.
- MUST create a minimal `Terminal_console_mosaic` executable-side module that can render a projected snapshot from `Terminal_console_model`.
- MUST keep Mosaic-specific code out of core orchestration modules.
- MUST NOT introduce an alternate TUI framework, Matrix-only implementation, or separate non-OCaml terminal client.
- SHOULD validate package/build impact early because the CLI Package carries the backend executable.
</requirements>

## Subtasks
- [x] 2.1 Update Product Repository build metadata for the Mosaic dependency.
- [x] 2.2 Add a minimal executable-side Mosaic module that consumes the projection from task 01.
- [x] 2.3 Keep the shell non-mutating and independent from orchestration runtime wiring.
- [x] 2.4 Add compile-focused tests or smoke coverage for the shell boundary.
- [x] 2.5 Run backend build validation after dependency changes.
- [x] 2.6 Record any dependency compatibility findings for later tasks.

## Implementation Details
Modify build metadata and Dune files so the dependency is reproducible. Reference the TechSpec "Mosaic / opam / Dune" section and ADR-004 for the dependency decision. The initial shell should prove Mosaic can render from the view-model projection without starting orchestration or adding lifecycle controls.

Do not change npm package files, `bin/symphony.js`, or packaged-binary behavior in this task. If build validation produces generated vendor artifacts, treat them according to existing repository packaging guidance and do not broaden the task scope.

### Relevant Files
- `dune-project` — Product package dependencies and Dune language version.
- `apps/backend/bin/dune` — Backend executable dependencies.
- `apps/backend/lib/dune` — Backend library dependencies, if the projection module needs metadata changes.
- `apps/backend/bin/main.ml` — Later runtime entry point; should not be rewired yet.
- `scripts/package-binary.js` — Packaging depends on the backend executable output path; relevant for validation only.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — New Mosaic shell module created by this task.
- `apps/backend/lib/terminal_console_model.ml` — Projection consumed by the shell.
- `package.json` — Provides validation scripts; should not be modified unless explicitly required and approved.

### Related ADRs
- [ADR-004: Add Mosaic as the direct Terminal Console dependency](adrs/adr-004.md) — Primary dependency decision for this task.
- [ADR-005: Use a pure Terminal Console view-model projection](adrs/adr-005.md) — Requires Mosaic-specific code to consume the projection boundary.

## Deliverables
- Explicit Mosaic dependency metadata in Dune/opam configuration.
- Minimal `Terminal_console_mosaic` shell that compiles and renders a projected snapshot.
- Dependency/build notes for Dune version or opam package requirements.
- Unit tests with 80%+ coverage for new non-UI helpers, if any **(REQUIRED)**.
- Integration tests or build checks proving the executable compiles with Mosaic **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Any shell helper that maps projected status to display labels returns stable labels for idle, running, retrying, attention, and readiness-blocked modes.
  - [x] Any shell helper for initial model construction uses sanitized projection fields from task 01.
- Integration tests:
  - [x] `pnpm backend:build` succeeds with Mosaic dependency metadata.
  - [x] Existing `pnpm test` backend suite still compiles after dependency metadata changes.
  - [x] The minimal Mosaic module can be linked into the backend executable without changing `--web` or `--once` behavior.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Mosaic is an explicit, reproducible dependency of the Terminal Console executable path.
- Core orchestration modules do not import Mosaic.
- No npm package or launcher behavior changes are introduced.
