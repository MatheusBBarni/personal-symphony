# Frontend Scope

Use this when editing `apps/frontend/**`.

- MUST edit `.res` files first; `.res.js` files are generated outputs.
- MUST run `pnpm frontend:test` for live-state parsing changes.
- MUST run `pnpm frontend:build` for ReScript or UI changes.
- MUST keep the Live Dashboard Connection as Runtime State snapshots, not an event envelope.
- MUST keep browser-local Audio Notification preferences out of Runtime Settings.
- Use `apps/frontend/src/liveState.js` as the JavaScript boundary for stream parsing.
- Vite dev server runs at `127.0.0.1:5173` and proxies `/api` to `127.0.0.1:8080`.
