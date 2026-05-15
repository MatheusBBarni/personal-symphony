# Reason Backend Migration Plan

## Goal

Validate whether a gradual syntax rewrite from OCaml to Reason is worth doing in the Product Repository without changing runtime behavior.

The migration starts with the standalone `apps/tui` package. Backend work only begins after the TUI trial proves that mixed OCaml and Reason development is stable for this codebase.

## Phase 0: Tooling Setup

Scope:
- Add the required Reason dependencies to the Product Repository toolchain.
- Wire Reason source support into the existing Dune build and formatting workflow.
- Keep the codebase behavior unchanged during this phase.

Verification:
- The Product Repository still builds successfully after the tooling changes.
- Existing OCaml-only modules still compile without modification.
- Tests still run through the normal commands.
- Developers can add a small `.re` or `.rei` file without custom local setup.

Success gate:
- Reason syntax is available as a normal part of the build process.
- The repository can compile mixed OCaml and Reason modules reliably.
- Formatting and developer workflow remain predictable enough to continue to the TUI pilot.

Stop conditions:
- Dependency or formatter setup causes unstable builds.
- Editor or Dune integration becomes inconsistent across normal development flows.
- The setup requires repo-wide churn before any pilot conversion starts.

## Phase 1: TUI Pilot

Scope:
- Start in `apps/tui` only.
- Rewrite one small, self-contained TUI module or extracted helper at a time.
- Avoid changing package behavior, public API shape, or terminal interaction semantics during the pilot.

Verification:
- `pnpm test` still passes from the Product Repository root.
- `apps/tui/test/test_tui.re` still passes through the normal test run.
- TUI examples still build and run as expected.
- The backend Terminal Console paths that depend on the TUI package still run as expected.

Success gate:
- The TUI package can contain a small amount of Reason code without build instability.
- Test coverage remains green.
- Example behavior remains unchanged.
- The backend TUI integration still behaves the same from the operator point of view.

Stop conditions:
- Mixed `.ml` and `.re` development creates toolchain friction that slows normal work.
- Snapshot, rendering, input, or layout behavior changes unintentionally.
- The backend Terminal Console becomes harder to verify or debug.

## Phase 2: Backend Leaf Modules

This phase starts only if Phase 1 succeeds.

Scope:
- Rewrite only small backend leaf modules first.
- Prefer modules with narrow dependencies and strong tests.
- Do not start with large shared modules such as `orchestrator.ml`, `server.ml`, `config.ml`, or `runtime_home.ml`.

Initial candidates:
- `apps/backend/lib/ordered_queue.ml`
- `apps/backend/lib/util.ml`
- Other extracted helpers created specifically to reduce migration risk

Verification:
- `pnpm test` passes after each converted module.
- No Runtime Contract behavior changes.
- No change to Workspace Repository root validation, Bootstrap idempotence, or Task Branch behavior.

Success gate:
- Small backend modules can be rewritten one at a time with no behavior regressions and no noticeable build or maintenance penalty.

## Phase 0/1 Implementation Record

Date: 2026-05-15

- Phase 0 added `reason` to the Product Repository and TUI package dependencies, letting Dune compile `.re` and `.rei` files through its built-in Reason dialect.
- Phase 1 converted the TUI library and test entrypoints to Reason as `apps/tui/lib/tui.re` and `apps/tui/test/test_tui.re`.
- The Unicode helper logic lives in private Reason module `apps/tui/lib/tui_utf.re`.
- `Tui.Utf` remains the public API surface; it delegates to the private helper so existing callers keep the same module path and value names.
- Verification passed for `pnpm test`, `pnpm backend:build`, `pnpm build`, all five TUI examples, and the backend Terminal Console preview.
- `refmt --in-place apps/tui/lib/tui_utf.re` works for Reason formatting. `dune build @fmt` still depends on the existing OCamlFormat setup and currently fails because `ocamlformat` is not installed in the local switch.

## Working Rules

- Migrate by module, not by broad subsystem.
- Extract smaller modules before rewriting large files.
- Keep behavior constant during syntax migration.
- Use explicit interfaces where they reduce churn.
- Treat this as a reversible experiment until both phases prove their value.
