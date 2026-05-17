---
description: Frontend package rules
globs:
  - "apps/frontend/**"
---

# Frontend Rules

Apply these rules when editing `apps/frontend/**`.

- MUST edit ReScript source files (`.res`) for frontend logic and UI changes.
- NEVER commit generated `apps/frontend/src/*.res.js` files.
- SHOULD leave generated `apps/frontend/lib/**` ReScript build artifacts out of hand edits.
- MUST run `pnpm frontend:build` after ReScript or UI changes.
- MUST run `pnpm frontend:test` after Live Dashboard state parsing or audio notification changes.
- MUST keep Frontend Live Dashboard state shaped by `Runtime_state` snapshots, not event envelopes.
- MUST keep browser-local Audio Notification preferences out of Runtime Settings.
- Vite dev server runs with `pnpm frontend:dev` and proxies `/api` to `http://127.0.0.1:8080`.
- Use existing bindings in `apps/frontend/src/Bindings/**` before introducing new JavaScript interop.
- Keep generated JavaScript changes out of review unless the task explicitly targets the build output.
