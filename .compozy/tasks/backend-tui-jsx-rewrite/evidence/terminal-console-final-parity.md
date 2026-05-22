# Terminal Console Final JSX Parity Evidence

Captured on 2026-05-22 from the Product Repository worktree at
`.symphony/workspaces/compozy_backend-tui-jsx-rewrite`.

This evidence covers the completed backend Terminal Console `Tui.Jsx` rewrite as
a maintainer-facing authoring change. It does not claim a new operator-facing
Terminal Console feature, redesign, Runtime State field, Runtime Settings field,
Runtime Contract default, lifecycle mutation, or safe-aid capability.

## Documentation Alignment

- `apps/tui/README.md` now identifies the backend Terminal Console as the
  production dogfooding surface for `Tui.Jsx`.
- `apps/tui/examples/agent_workspace/README.md` now clarifies that the example
  remains a package-level parity reference while the backend Terminal Console in
  `apps/backend` is the production dogfooding surface.
- Package boundary language is preserved: `apps/tui` remains the reusable TUI
  Toolkit Package; product-specific Terminal Console Runtime State projection,
  settings, shortcuts, and safe local aids remain in `apps/backend`.

## Final JSX Coverage Status

`apps/backend/bin/terminal_console_tui.re` now uses literal `Tui.Jsx` tags for
existing backend Terminal Console UI node construction:

- Leaf text and rich-text nodes use `J.Text` and `J.RichText`.
- Help and settings modals use `J.Modal` with nested JSX children.
- Header, badge row, tab strip, active panel, scroll box, footer, and root
  layout use `J.Box`, `J.Row`, `J.Panel`, `J.ScrollBox`, `J.Badge`,
  `J.Text`, and `J.RichText`.

Allowed remaining direct lower-level package usage is not view construction:

- `Components.Neutral`, `Accent`, `Info`, `Success`, `Warning`, and `Error`
  remain tone data used by spans, badges, and theme mapping.
- `Components.make_design` remains design-context construction, not a UI node.
- `Tui.Style`, `Tui.Theme`, `Tui.Span`, and renderer APIs remain lower-level
  primitives around the JSX-authored `Tui.Node.t` tree.
- No new `apps/tui` JSX wrappers were required for final parity.

## Preview Commands

The direct `pnpm` path still attempts package-manager resolution in this
sandbox, so verification used the same local-runner form documented in the
baseline evidence:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current run backend:build
```

Result: exit code 0.

```text
$ opam exec -- dune build @all
```

The final preview was captured with:

```sh
rtk opam exec -- dune exec --root . --build-dir /private/tmp/compozy_backend_tui_jsx_rewrite_build apps/backend/bin/terminal_console_preview.exe
```

Result: exit code 0.

## Final Preview Stdout

```text
symphony-orchestrator
ATTENTION
Queue | Logs | Tasks | Readiness | Needs attention
generated 2026-05-22T21:02:35Z
Queue
Next work: NEXT PENDING #129 Tighten Queue tab spacing
> RETRYING #130 Audit Logs copy density
RUNNING #128 Wire terminal preview data
PENDING #129 Tighten Queue tab spacing
COMPLETED #131 Document visual preview script
SKIPPED #132 Remove obsolete Mosaic docs - skip reason: covered by previous migration task
Logs
18:09:52 poll checking compozy_tasks tracker, 0 running, 0 retrying
startup ready terminal_console tracker compozy_tasks symphony-orchestrator/.compozy/tasks
event=startup outcome=completed mode=terminal_console tracker=compozy_tasks project_number=0
runtime_home=symphony-orchestrator/.symphony
workspace_root=symphony-orchestrator/.symphony/workspaces
present workspaces symphony-orchestrator/.symphony/workspaces
present state symphony-orchestrator/.symphony/state
kept prompt.md symphony-orchestrator/.symphony/prompt.md
kept settings.json symphony-orchestrator/.symphony/settings.json
present .symphony symphony-orchestrator/.symphony
bootstrap 0 created 12 already configured
Tasks
Status: Needs attention
Updated: 2026-05-22T21:02:35Z
Active: RUNNING 1 | RETRYING 1 | ATTENTION 2
Total tokens: 76660
> ATTENTION #133 Confirm Runtime Contract wording - Goal Loop: state needs_attention | attempt 3 |
outcome needs_attention | evidence Evidence command reported missing operator decision. | next
action Operator...
------------------------------------------------------------------------
BUDGET EXHAUSTED #135 Stop when Goal Loop turn budget is exhausted - Goal Loop: state
budget_exhausted | attempt 4 | outcome budget_exhausted | evidence maxTurns reached before
deterministic evidence. | next action Review the ...
------------------------------------------------------------------------
RETRYING #130 Audit Logs copy density - due 2026-05-14T13:15:00Z | attempt 2 | branch
symphony/logs-density
------------------------------------------------------------------------
RUNNING #128 Wire terminal preview data - Goal Loop: state running | attempt 1 | evidence Agent is
updating Terminal Console projection tests. | next action Continue monitoring agent activity. |
issu...
------------------------------------------------------------------------
GOAL MET #134 Verify preview snapshot renders Goal Loop success - Goal Loop: state goal_met |
attempt 2 | outcome goal_met | evidence pnpm test passed for Terminal Console projection. | next
action Review the Stage Commit d...
Next work: NEXT PENDING #129 Tighten Queue tab spacing
Last state error: Preview data includes one attention row so the Tasks tab has contrast.
Readiness
> READINESS GAP 1 requirement: GITHUB_TOKEN
Remediation: Set GITHUB_TOKEN in .symphony/.env before dispatch can push Task Branches.
READINESS GAP 2 requirement: stageAgents.engineer.context.command
Remediation: Configure a safe context command so each Task Branch starts with current Workspace
Repository context.
Needs attention
> ATTENTION #133 Confirm Runtime Contract wording - Goal Loop: state needs_attention | attempt 3 |
outcome needs_attention | evidence Evidence command reported missing operator decision. | next
action Operator...
Current error: manual review needed before touching Task Branch cleanup defaults
BUDGET EXHAUSTED #135 Stop when Goal Loop turn budget is exhausted - Goal Loop: state
budget_exhausted | attempt 4 | outcome budget_exhausted | evidence maxTurns reached before
deterministic evidence. | next action Review the ...
Current error: maxTurns reached before deterministic evidence.
[q]quit | [Tab]tabs | [h/l]tabs | [j/k]rows [Space]expand | [/]search | [r]refresh | [s]settings | [w]web | [o]path | [?]help
```

## Baseline Comparison

The baseline preview from
`.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md`
and the final preview above were normalized only for volatile generated
timestamps:

```sh
rtk diff -u /private/tmp/compozy-terminal-console-baseline-preview.normalized.txt /private/tmp/compozy-terminal-console-final-preview.normalized.txt
```

Result: exit code 0, no diff output.

Comparison notes:

- Header, status, tab titles, active Queue content, Logs content, Tasks content,
  Readiness Gaps, Needs attention content, and footer shortcuts match the task 1
  baseline after timestamp normalization.
- The preview still covers running queue, attention/error, background logs,
  readiness rows, task rows, Goal Loop summaries, token totals, and Runtime State
  projection signals.
- Baseline preview gaps remain unchanged and are intentionally not overclaimed:
  idle/ready header state, settings modal, help modal, minimum terminal size, and
  dedicated Task Detail panel preview coverage remain covered by backend tests
  rather than this non-interactive preview stdout.

## Verification Results

Backend build:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current run backend:build
```

Result: exit code 0.

Backend tests:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current run test
```

Result: exit code 0.

```text
Test Successful in 36.938s. 487 tests run.
```

Docs/examples validation:

```sh
rtk env pnpm_config_verify_deps_before_run=false pnpm with current run docs:test
```

Result: exit code 0.

```text
Documentation validation passed: 11 JSON examples checked across 2 docs.
```

TUI package tests:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current --filter @symphony-orchestrator/tui test
```

Result: exit code 0.

```text
Test Successful in 0.007s. 36 tests run.
```

TUI package build:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current --filter @symphony-orchestrator/tui build
```

Result: exit code 0.

```text
$ opam exec -- dune build @all
```

Whitespace check:

```sh
rtk git diff --check
```

Result: exit code 0.

Task bundle validation:

```sh
rtk compozy tasks validate --name backend-tui-jsx-rewrite
```

Result: exit code 0.

```text
all tasks valid (6 scanned)
```

Generated frontend artifact check:

```sh
rtk git diff --name-only -- apps/frontend/src
```

Result: exit code 0, no output. No generated `apps/frontend/src/*.res.js`
files are changed.

Coverage note: this repository does not currently define a numeric coverage
reporter in `package.json`, `dune-project`, `apps/backend`, or `apps/tui`.
Fresh verification therefore uses the project-defined Alcotest suites and the
Terminal Console parity coverage mapped in the baseline evidence.
