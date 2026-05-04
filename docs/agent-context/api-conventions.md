# API Conventions

- Backend HTTP state should expose Runtime State snapshots for the Web Dashboard.
- The frontend consumes snapshots through the Live Dashboard Connection.
- API changes that alter snapshot shape should update `apps/backend/lib/runtime_state.ml`, frontend parsing in `apps/frontend/src/liveState.js`, and tests on both sides.
- GitHub tracker changes should preserve the Issues + Projects boundary and keep token values redacted from user-facing errors.
