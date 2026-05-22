# Terminal Console Baseline Preview And Contract Inventory

Captured on 2026-05-22 from the Product Repository worktree at
`.symphony/workspaces/compozy_backend-tui-jsx-rewrite`.

This evidence captures the current backend Terminal Console rendering contract before
the `Terminal_console_tui` source conversion. It does not change Runtime State,
Runtime Settings, Runtime Contract defaults, lifecycle behavior, safe-aid behavior,
or operator-facing Terminal Console semantics.

## Commands

The repository command requested by the task was attempted first:

```sh
rtk pnpm backend:build
```

Result: blocked before script execution by package-manager fetching in this sandbox:

```text
[ERROR] fetch failed
For help, run: pnpm help run
```

The local `pnpm` binary is available as 11.0.5, but this checkout declares
`packageManager: pnpm@10.33.0`; plain `pnpm` attempts to fetch that exact
package manager version. The checkout also has no `node_modules`, so `pnpm with
current run backend:build` needed dependency verification disabled to avoid a
networked install attempt. The build command that successfully exercised the
backend script was:

```sh
rtk env pnpm_config_verify_deps_before_run=false DUNE_ROOT=. DUNE_BUILD_DIR=/private/tmp/compozy_backend_tui_jsx_rewrite_build pnpm with current run backend:build
```

Result:

```text
$ opam exec -- dune build @all
```

Default Dune output under repo `_build` is blocked in this sandbox by
`Error: open(_build/.lock): Operation not permitted`, so the successful build
used the temporary Dune build directory above.

The preview baseline was generated with:

```sh
rtk opam exec -- dune exec --root . --build-dir /private/tmp/compozy_backend_tui_jsx_rewrite_build apps/backend/bin/terminal_console_preview.exe
```

RTK wrapper warnings are omitted from the preview stdout below because they are
not emitted by the preview executable.

## Preview Stdout Baseline

```text
symphony-orchestrator
ATTENTION
Queue | Logs | Tasks | Readiness | Needs attention
generated 2026-05-22T20:33:17Z
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
Updated: 2026-05-22T20:33:17Z
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

## Public Contract Inventory

`apps/backend/bin/dune`

- Library name and module slot: `symphony_terminal_console_shell` exposes
  `terminal_console_tui` and `terminal_console_runtime`.
- Preview executable depends on that shell library and imports
  `Terminal_console_tui` through the same public module path as runtime callers.

`apps/backend/bin/main.ml`

- Uses `compile_anchor` to force linkage.
- Aliases `Symphony_terminal_console_shell.Terminal_console_tui`.
- Builds `settings_state` records with fields `theme` and `port`.
- Returns `Settings_rejected`, `Settings_failed`, and `Settings_saved` from the
  Terminal Console settings save callback.
- Calls `default_web_handoff ~host ~port ()`.
- Calls `local_surface ~label ~root` for `Workspace Repository` and
  `Runtime Home`.

`apps/backend/bin/terminal_console_runtime.ml`

- Uses `default_web_handoff`, `default_settings`, `default_save_settings`, and
  `run` as default handoff/run behavior.
- Constructs the `runtime` record with fields `initial_state`, `initial_logs`,
  `subscribe`, `safe_aid`, `web_handoff`, `local_surfaces`, `settings`, and
  `save_settings`.

`apps/backend/bin/terminal_console_preview.ml`

- Aliases `Terminal_console_tui` as `Shell`.
- Constructs `Shell.runtime` with the same record fields as runtime handoff.
- Calls `Shell.default_web_handoff ~port`, `Shell.local_surface`,
  `Shell.default_settings`, `Shell.default_save_settings`, and `Shell.run`.

`apps/backend/test/test_backend.ml`

- Public functions and values consumed by tests: `status_label`,
  `initial_model`, `render_snapshot`, `render_model`, `rendered_lines`,
  `panel_lines`, `task_detail_panel`, `active_panel`, `view`, `apply_key`,
  `update`, `init`, `ui_key_of_tui_key`, `focused_tab_title`,
  `visible_active_rows`, `compact_path_token`, `compact_log_line`,
  `terminal_console_theme`, `theme_for_name`, `default_interaction`,
  `default_settings`, `default_web_handoff`, `default_save_settings`,
  `local_surface`, `help_lines`, and `settings_modal_lines`.
- Public type/constructor surface consumed by tests: `runtime`, `model`,
  `transition`, `terminal_size`, `settings_state`, `settings_save_result`,
  `settings_modal`, `ui_key`, and `msg`; constructors include `Character`,
  `Enter_key`, `Backspace_key`, `Escape_key`, `Up_key`, `Down_key`,
  `Right_key`, `Space_key`, `Logs`, `Key_press`, and `Settings_saved`.
- Public record fields consumed by tests: `model.status_label`,
  `model.snapshot`, `model.status_message`, `model.settings`,
  `model.interaction`; `interaction.active_tab`, `selected_rows.active`,
  `filter_text`, `filter_active`, `help_visible`, `settings_modal`,
  `logs_scroll`, `expanded_queue_id`; `settings_state.theme`,
  `settings_state.port`; `settings_modal.draft_theme`,
  `settings_modal.validation_message`; `transition.model`,
  `transition.safe_aids`; `panel.title`, `panel.lines`;
  `rendered_snapshot.heading`, `status_label`, `tabs`, `subheading`, and
  `footer`; `runtime.initial_state`.

## Existing Test Coverage Map

The focused backend Alcotest coverage in `apps/backend/test/test_backend.ml`
already maps to the TechSpec parity areas:

- Status labels: `test_terminal_console_tui_status_labels`.
- Projection and sanitization: `test_terminal_console_model_projects_idle`,
  running/retrying/attention/readiness/ordered queue/Compozy progress projection
  tests, and `test_terminal_console_model_sanitizes_untrusted_text`.
- Project title and tabs: `test_terminal_console_tui_project_title_and_tabs`.
- Cursor design theme and no-color distinctions:
  `test_terminal_console_tui_uses_cursor_design_theme` and
  `test_terminal_console_tui_no_color_labels_remain_distinct`.
- Tasks, Queue, Logs, Readiness, Attention, and Task Detail panels:
  `test_terminal_console_tui_active_home_panel`,
  `test_terminal_console_tui_ordered_queue_panel_states`,
  `test_terminal_console_tui_ordered_queue_attention_states`,
  `test_terminal_console_tui_logs_panel_uses_background_logs`,
  `test_terminal_console_tui_logs_panel_newest_first_and_scrolls`,
  `test_terminal_console_tui_readiness_attention_panel_wraps_remediation`,
  `test_terminal_console_tui_task_detail_panel_includes_context`,
  `test_terminal_console_tui_task_detail_includes_goal_loop`, and
  `test_terminal_console_tui_task_detail_omits_absent_optional_fields`.
- Minimum-size rendering:
  `test_terminal_console_tui_minimum_size_message`.
- Navigation, filtering, queue expansion, and log scrolling:
  `test_terminal_console_tui_navigation_is_ui_only`,
  `test_terminal_console_tui_filtering_is_ui_only`,
  `test_terminal_console_tui_queue_space_expands_selected_stage`, and
  `test_terminal_console_tui_logs_panel_newest_first_and_scrolls`.
- Help and settings modal behavior:
  `test_terminal_console_tui_footer_help_content`,
  `test_terminal_console_tui_settings_modal_opens_separately`,
  `test_terminal_console_tui_settings_cancel_keeps_saved_values`,
  `test_terminal_console_tui_settings_theme_cycle_and_applies_theme`,
  `test_terminal_console_tui_invalid_port_rejects_before_save`,
  `test_terminal_console_tui_settings_save_uses_runtime_callback`,
  `test_terminal_console_tui_settings_save_updates_web_handoff`,
  `test_terminal_console_tui_cancelled_settings_do_not_call_save`, and
  `test_terminal_console_tui_closed_settings_preserves_existing_controls`.
- Safe-aid read-only behavior:
  `test_terminal_console_tui_refresh_invokes_only_refresh_aid`,
  `test_terminal_console_tui_web_handoff_guidance_only`,
  `test_terminal_console_tui_invalid_path_is_ui_local`,
  `test_terminal_console_tui_goal_loop_diagnostics_path_is_read_only`, and
  `test_terminal_console_runtime_safe_aid_handler_records_non_mutating_aids`.
- Runtime handoff and latest-state subscription:
  `test_terminal_console_runtime_handoff_latest_state`,
  `test_terminal_console_runtime_handoff_subscribes_latest_snapshot`,
  `test_terminal_console_runtime_readiness_runs_ui_without_orchestration`,
  `test_terminal_console_runtime_orchestrator_notify_updates_initial_ui_state`,
  and `test_terminal_console_runtime_background_orchestration_reports_failures`.

No backend source or test helper was changed for this baseline task, so no new
unit test was added. The behavior contract for touched product code is unchanged;
this artifact is the touched deliverable.

## Preview Coverage Map

Recommended representative preview states from the TechSpec:

| State | Current preview coverage | Evidence |
| --- | --- | --- |
| Idle/ready state | Missing | Preview mock renders top-level `ATTENTION`, not idle or ready. Supplemental preview evidence is needed if later parity review requires idle/ready stdout. Existing unit coverage includes idle projection and status labels. |
| Running Queue with active task | Covered | Queue panel includes `RUNNING #128`, `PENDING #129`, `RETRYING #130`, completed and skipped rows, plus `Next work`. |
| Readiness-blocked state | Partial | Readiness panel includes two `READINESS GAP` rows, but top-level mode is `ATTENTION`, not `readiness_blocked`. Supplemental readiness-blocked preview state is needed for status/header parity. |
| Attention/error state | Covered | Header status is `ATTENTION`; Tasks and Needs attention panels include `#133`, budget exhaustion, and current error lines. |
| Logs tab with background output | Covered | Logs panel includes bootstrap and startup/poll lines from `initial_logs`. |
| Settings modal open | Missing | Current preview executable does not synthesize key input or open the settings modal. Existing tests cover settings modal behavior. |
| Help modal open | Missing | Current preview executable does not synthesize `?` or open the help modal. Existing tests cover help modal behavior. |
| Minimum terminal size message | Missing | Non-interactive preview does not pass a small `terminal_size`. Existing tests cover minimum-size rendering. |
| Task detail signals | Covered | Tasks and Needs attention rows include selected task identity, state, Goal Loop state, attempts, evidence, next action, due time, branch, and current error details from the mock Runtime State. |
| Dedicated Task Detail panel | Missing from preview stdout | `terminal_console_preview` prints `rendered_lines` from `render_snapshot`, whose panels are Queue, Logs, Tasks, Readiness, and Needs attention. The dedicated `Task Detail` panel is covered by tests but needs supplemental preview evidence if required for before/after visual parity. |
| Runtime State projection signals | Covered | Preview includes Workspace Repository name, generated timestamp, mode/status, Ordered Queue, Readiness Gaps, issue errors, Goal Loop summaries, token totals, startup Runtime Home/workspace paths, and log projection. |

## Baseline Conclusion

The current backend Terminal Console shell compiles through the OCaml build when
the sandbox's package-manager fetch and default Dune lock limitations are
bypassed with local-only settings. The current preview executable provides a
single non-interactive ATTENTION-state baseline with Queue, Logs, Tasks,
Readiness, Needs attention, task detail signals, and Runtime State projection
signals. Help modal, settings modal, minimum terminal size, idle/ready header
state, full readiness-blocked header state, and dedicated Task Detail panel
stdout need supplemental evidence in later parity checks.
