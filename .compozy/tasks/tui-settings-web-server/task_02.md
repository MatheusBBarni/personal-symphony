---
status: completed
title: "Add Dashboard Identity Endpoint"
type: backend
complexity: medium
dependencies: []

---

# Task 02: Add Dashboard Identity Endpoint

## Overview
This task adds the identity contract that lets Symphony distinguish a compatible Web Dashboard from an unrelated listener on the same port. It keeps the existing Runtime State HTTP routes and Live Dashboard Connection behavior unchanged.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add `GET /api/v1/dashboard/identity`.
- REQ-02 MUST include Workspace Repository root, Runtime Home, dashboard mode, auth requirement, server host, and server port in the identity response.
- REQ-03 MUST keep `/api/v1/state`, `/api/v1/refresh`, `/api/v1/state/live`, and static asset behavior unchanged.
- REQ-04 MUST preserve existing non-loopback auth rules for Runtime State HTTP and Live Dashboard Connection access.
- REQ-05 MUST require a valid dashboard auth token before returning identity when the server is running with an auth token.
- REQ-06 SHOULD keep identity serialization centralized enough for the dashboard service to reuse it.
</requirements>

## Subtasks
- [ ] 2.1 Review the Web Dashboard identity and auth requirements in the TechSpec and ADR-003.
- [ ] 2.2 Add the identity response model and route handling to the backend server boundary.
- [ ] 2.3 Keep route matching and auth behavior explicit for identity versus Runtime State routes.
- [ ] 2.4 Add focused server tests for identity payloads and existing route behavior.
- [ ] 2.5 Confirm non-loopback auth tests remain meaningful after the new route is added.

## Implementation Details
Use the TechSpec "API Endpoints" and "Core Interfaces" sections for the identity fields. Do not add a frontend dependency or change Web Dashboard visual behavior in this task.

### Relevant Files
- `apps/backend/lib/server.ml` — Existing HTTP route handling, auth checks, websocket handling, and `serve` loop.
- `apps/backend/lib/dune` — May need updates if a small ReasonML identity helper is added.
- `apps/backend/test/test_backend.ml` — Existing server tests for Runtime State HTTP, websocket, and non-loopback auth.
- `apps/backend/lib/runtime_home.ml` — Runtime Home values used in identity payloads.
- `apps/backend/lib/config.ml` — Existing `server.host` and `server.port` settings shape.
- `docs/adr/0025-dashboard-loopback-and-auth.md` — Existing project decision for loopback and auth behavior.

### Dependent Files
- `apps/backend/lib/dashboard_service.re` — Later task will probe this endpoint before reusing a dashboard.
- `apps/backend/bin/main.ml` — Later task will pass identity values when starting Web Dashboard mode.
- `apps/backend/bin/terminal_console_runtime.ml` — Later task will start or reuse a dashboard through the identity-aware service.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Requires compatible dashboard reuse.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Selects identity-based reuse.

## Deliverables
- Dashboard identity endpoint with structured JSON response.
- Server route integration that preserves existing Runtime State routes.
- Unit tests with 80%+ coverage for identity serialization and route selection **(REQUIRED)**.
- Integration tests for auth and existing Web Dashboard routes **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Identity JSON contains normalized Workspace Repository root.
  - [ ] Identity JSON contains Runtime Home path, mode, auth requirement, host, and port.
  - [ ] Identity response remains valid when auth is not required for loopback.
  - [ ] Identity response includes exactly `workspace_root`, `runtime_home`, `mode`, `auth_required`, `server_host`, and `server_port`.
- Integration tests:
  - [ ] `GET /api/v1/dashboard/identity` returns the expected identity body.
  - [ ] Missing or invalid auth token does not return identity when `auth_token` is configured.
  - [ ] Valid query token or auth header returns identity when `auth_token` is configured.
  - [ ] Existing `/api/v1/state` response remains unchanged for loopback requests.
  - [ ] Existing `/api/v1/refresh` response remains `202 Accepted`.
  - [ ] Existing websocket auth behavior remains unchanged for non-loopback token-protected surfaces.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- A compatible dashboard can be identified without relying on port-only reuse.
- Runtime State HTTP and Live Dashboard Connection semantics are preserved.
- Focused `server` Alcotest coverage, `pnpm test`, and `pnpm backend:build` pass.
