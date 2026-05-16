# Reason Migration Candidate Analysis

Module-by-module assessment for Phase 2 continuation and beyond. All files under `apps/backend/lib/`.

Excluded from conversion: `orchestrator.ml`, `server.ml`, `config.ml`, `runtime_home.ml`.
Already converted: `util.re`, `issue.re`, `prompt.re`, `ordered_queue.re`.

## Tier 1 — Trivial

Convert in a single pass. Negligible risk.

| Module | Lines | Imported by | Notes |
|--------|-------|-------------|-------|
| `cli_mode.ml` | 5 | 1 (`runtime_policy`) | Standalone enum type + two pure functions. No advanced features. |
| `runtime_policy.ml` | 8 | 0 | One discriminated-union type and one pattern-match function. Only references `Cli_mode` (Tier 1). |
| `terminal_console.ml` | 21 | 2 | One optional-line formatting helper. 2 tests in `runtime-state` group. |
| `workspace.ml` | 30 | 6 | Path sanitization and directory creation. 1 dedicated test group. |

## Tier 2 — Small, straightforward

| Module | Lines | Imported by | Notes |
|--------|-------|-------------|-------|
| `workflow.ml` | 39 | 1 | Front-matter splitting, file loading. Custom exception. Convert together with `simple_yaml`. 1 test group. |
| `runtime_startup.ml` | 46 | 0 | Config loading, bootstrap orchestration. Depends on excluded `Config` and `Runtime_home`. Nothing depends on it. 6 tests. |
| `runtime_readiness.ml` | 73 | 0 | Gap aggregation from multiple sources. Depends on excluded modules. Nothing depends on it. |
| `simple_yaml.ml` | 84 | 1 (`workflow.ml`) | Mini YAML parser using `Hashtbl`, refs, `Buffer`. Only consumer is `workflow.ml`. |
| `cli_command.ml` | 219 | 0 | Heavy Cmdliner `Arg`/`Term` DSL. The local-open `Arg.(...)` syntax needs careful Reason translation. No dependents. 2 tests. |

## Tier 3 — Medium, wider blast radius

| Module | Lines | Imported by | Notes |
|--------|-------|-------------|-------|
| `update_cli.ml` | 237 | 0 | Self-contained CLI subcommand. No dedicated tests. |
| `manual_merge.ml` | 282 | 0 | Heavily coupled to excluded `orchestrator.ml` (calls `run_shell_capture`, `task_branch`, etc.). 12 tests. |
| `terminal_console_model.ml` | 368 | 0 | View-model construction and text sanitization. 20+ tests in `runtime-state` group. |
| `issue_tracker.ml` | 333 | 3 | Widest dependency surface (7 modules). Record-with-function-fields pattern. ~15 indirect tests. |
| `runtime_state.ml` | 467 | 8 | Most-imported candidate. Many `to_yojson` functions. 14+ tests. |

## Tier 4 — Large, convert last

| Module | Lines | Imported by | Notes |
|--------|-------|-------------|-------|
| `github_tracker.ml` | 643 | 1 | Largest candidate. `Yojson.Safe.Util` local-open patterns, inline GraphQL strings. 10 tests. |
| `compozy_lifecycle.ml` | 473 | 3 | Lifecycle state machine, `let*` monadic bind, JSON persistence. 24 tests. |
| `minibeads_tracker.ml` | 496 | 1 | First-class `command_runner` record, shell interaction, custom exceptions. 12 tests. |
| `compozy_tasks_tracker.ml` | 600 | 4 | Complex frontmatter parser, recursive parsing with refs/Hashtbl. 36 tests. |

## Recommended Conversion Order

```
Tier 1 (one pass):  cli_mode → runtime_policy → terminal_console → workspace
Tier 2 batch A:     simple_yaml + workflow (pair, they form a dependency chain)
Tier 2 batch B:     runtime_startup → runtime_readiness
Tier 2 batch C:     cli_command
Tier 3 batch A:     update_cli → manual_merge
Tier 3 batch B:     terminal_console_model
Tier 4 (dependency-first):
                    compozy_tasks_tracker → compozy_lifecycle → runtime_state
                    → issue_tracker → github_tracker → minibeads_tracker
```

`runtime_state.ml` is the critical linchpin: convert only after its own dependencies (`compozy_lifecycle`, `compozy_tasks_tracker`) are done, and before anything that depends on it.
