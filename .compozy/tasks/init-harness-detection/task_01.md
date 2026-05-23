---
status: completed
title: Define Bootstrap Harness Detection Boundary
type: backend
complexity: medium
dependencies: []

---

# Task 1: Define Bootstrap Harness Detection Boundary

## Overview
Define the pure Bootstrap Harness detection boundary that later tasks will use for probing, settings generation, and user guidance. This task establishes the secret-free data model, deterministic selection contract, and injected test seam without changing Runtime Home file creation yet.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add the Bootstrap Harness detection model in `apps/backend/lib/bootstrap_harness_detection.re` using ReasonML source.
- R2 MUST define an injectable probe boundary that can represent allowlisted executable, authentication, and status checks without reading or returning secret values.
- R3 MUST define Harness statuses for `codex`, `claude`, `cursor`, `cursor-force`, and `pi`, while ensuring `cursor-force` is never selected automatically.
- R4 MUST define one deterministic selected-Harness priority and cover it in tests; prefer Harnesses with stronger install and auth evidence before Codex executable-only evidence.
- R5 MUST produce guidance-ready result data that distinguishes selected Harness, no usable Harness, and nonselectable Harness definitions without mutating Runtime Settings.
- R6 MUST avoid adding dependencies from `Config` back into any Bootstrap module, preserving one-way integration.
</requirements>

## Subtasks
- [x] 1.1 Define the secret-free Harness status and detection result types.
- [x] 1.2 Define the injected probe contract for executable, auth, and bounded status checks.
- [x] 1.3 Define supported Harness metadata and the deterministic selection priority.
- [x] 1.4 Define guidance categories for selected, missing, and nonselectable Harness outcomes.
- [x] 1.5 Add focused Alcotest coverage for pure selection and guidance classification.

## Implementation Details
Create `apps/backend/lib/bootstrap_harness_detection.re` as the owner of the detection domain described in the TechSpec "Core Interfaces" and ADR-003. Keep the module pure for this task: tests should inject probe results directly and must not invoke real `codex`, `claude`, `cursor-agent`, or `pi` commands. Add tests in `apps/backend/test/test_backend.ml` near the existing Runtime Home and Harness readiness coverage.

### Relevant Files
- `apps/backend/lib/bootstrap_harness_detection.re` — New Reason helper module for detection types, probe contract, selection, and guidance result values.
- `apps/backend/lib/dune` — Existing wrapped-false library stanza automatically includes new modules; confirm no Dune change is needed.
- `apps/backend/test/test_backend.ml` — Existing Alcotest suite where pure detection tests should be added without splitting the large file.
- `.compozy/tasks/init-harness-detection/_techspec.md` — Defines the Bootstrap detection boundary and required data shapes.

### Dependent Files
- `apps/backend/lib/bootstrap_settings.re` — Later task consumes the selected Harness result to generate Runtime Settings.
- `apps/backend/lib/runtime_home.ml` — Later task calls detection from Bootstrap only when settings are absent.
- `apps/backend/bin/main.ml` — Later task renders guidance derived from detection results.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Establishes Bootstrap detection as provisional onboarding input.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) — Requires explicit selected-Harness and next-step guidance.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Assigns detection ownership to a small Reason helper.

## Deliverables
- New `Bootstrap_harness_detection` module with pure, injectable detection types and selection output.
- Deterministic selected-Harness priority documented in code-level tests and result naming.
- Secret-free guidance-ready output model for selected and no-Harness scenarios.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Bootstrap detection consumers are not required in this task, but downstream compatibility points must be identified **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Codex-only probe result selects `codex` while marking Codex readiness confidence as executable-only.
  - [x] Claude-only, Cursor-only, and PI-only probe results each select their matching Harness.
  - [x] Multiple usable Harnesses select the deterministic priority winner and leave all statuses inspectable.
  - [x] `cursor-force` usable-looking input is retained as nonselectable and never becomes the selected Harness.
  - [x] No usable Harness produces no selected Harness and includes remediation categories.
  - [x] Token-like marker strings cannot appear in detection result fields or guidance lines.
- Integration tests:
  - [x] Compile the backend test suite with the new Reason module available to OCaml tests.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Detection selection is deterministic and covered for every supported Harness kind.
- The new module has no side effects and does not mutate Runtime Home files.
- Result values contain capability names and remediation only, never credential contents.
