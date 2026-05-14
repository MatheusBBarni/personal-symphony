module Shell = Symphony_terminal_console_shell.Terminal_console_tui

let issue ?branch_name ?(state = "Todo") ~id ~identifier ~title () =
  { (Issue.empty ~id ~identifier ~title ~state) with branch_name }

let running issue =
  {
    Runtime_state.issue;
    stage_agent = Some "engineer";
    harness_name = Some "codex";
    harness_kind = Some "codex";
    stage_states = [ "Todo"; "In progress"; "Review" ];
    session_id = Some "preview-session-01";
    turn_count = 7;
    last_event = Some "agent_output";
    last_message = Some "Updated orchestration state and waiting on backend build";
    started_at = "2026-05-14T13:00:00Z";
    last_event_at = Some "2026-05-14T13:08:00Z";
    tokens = { Runtime_state.input_tokens = 18240; output_tokens = 4112; total_tokens = 22352 };
    goal_usage =
      Some { Runtime_state.status = Some "active"; time_used_seconds = Some 486.; tokens_used = Some 22352 };
  }

let retrying ~issue_id ~issue_identifier =
  {
    Runtime_state.issue_id;
    issue_identifier;
    attempt = 2;
    due_at = "2026-05-14T13:15:00Z";
    error = Some "backend build failed after dependency graph changed";
    goal_usage = Some { Runtime_state.status = Some "retrying"; time_used_seconds = Some 91.; tokens_used = Some 6200 };
  }

let issue_error ~issue_id ~issue_identifier =
  {
    Runtime_state.issue_id;
    issue_identifier;
    error = "manual review needed before touching Task Branch cleanup defaults";
    goal_usage = Some { Runtime_state.status = Some "attention"; time_used_seconds = Some 140.; tokens_used = Some 7300 };
  }

let ordered_queue =
  {
    Runtime_state.entries =
      [
        { Runtime_state.issue_identifier = "#128"; title = Some "Wire terminal preview data"; state = "running"; skip_reason = None };
        { Runtime_state.issue_identifier = "#129"; title = Some "Tighten Queue tab spacing"; state = "pending"; skip_reason = None };
        { Runtime_state.issue_identifier = "#130"; title = Some "Audit Logs copy density"; state = "retrying"; skip_reason = None };
        { Runtime_state.issue_identifier = "#131"; title = Some "Document visual preview script"; state = "completed"; skip_reason = None };
        {
          Runtime_state.issue_identifier = "#132";
          title = Some "Remove obsolete Mosaic docs";
          state = "skipped";
          skip_reason = Some "covered by previous migration task";
        };
      ];
  }

let compozy_progress =
  {
    Runtime_state.run_id = "preview-run-20260514";
    slug = "backend-tui-preview";
    current_step = Some "task_03_visual_review.md";
    completed = 4;
    failed = 1;
    skipped = 1;
    total = 9;
    lifecycle_state = Some "active";
    dispatch_state = Some "In progress";
    stage_agent = Some "engineer";
    pr_readiness = Some "not-ready";
    reason = Some "visual review in progress";
    handoff_status = Some "draft";
  }

let mock_state () =
  let workspace_root = Sys.getcwd () in
  let runtime_home = Filename.concat workspace_root ".symphony" in
  let running_issue =
    issue ~id:"ISSUE-128" ~identifier:"#128" ~title:"Wire terminal preview data"
      ~state:"In progress" ~branch_name:"symphony/preview-terminal-console" ()
  in
  let retry_issue =
    issue ~id:"ISSUE-130" ~identifier:"#130" ~title:"Audit Logs copy density" ~state:"Todo"
      ~branch_name:"symphony/logs-density" ()
  in
  let attention_issue =
    issue ~id:"ISSUE-133" ~identifier:"#133" ~title:"Confirm Runtime Contract wording"
      ~state:"In progress" ~branch_name:"symphony/runtime-contract-copy" ()
  in
  let base =
    {
      (Runtime_state.empty ~workspace_repository_name:"symphony-orchestrator" ~tracker_kind:"compozy_tasks"
         ~ordered_queue ~compozy_progress
         ~readiness_gaps:
           [
             {
               Runtime_state.requirement = "GITHUB_TOKEN";
               remediation = "Set GITHUB_TOKEN in .symphony/.env before dispatch can push Task Branches.";
             };
             {
               Runtime_state.requirement = "stageAgents.engineer.context.command";
               remediation =
                 "Configure a safe context command so each Task Branch starts with current Workspace Repository context.";
             };
           ]
         ())
      with
      issues = [ running_issue; retry_issue; attention_issue ];
      running = [ running running_issue ];
      retrying = [ retrying ~issue_id:"ISSUE-130" ~issue_identifier:"#130" ];
      issue_errors = [ issue_error ~issue_id:"ISSUE-133" ~issue_identifier:"#133" ];
      usage_totals = { Runtime_state.input_tokens = 61240; output_tokens = 15420; total_tokens = 76660 };
      seconds_running = 644.;
      last_error = Some "Preview data includes one attention row so the Tasks tab has contrast.";
      startup_reconciliation =
        [
          {
            Runtime_state.issue_id = Some "ISSUE-128";
            issue_identifier = Some "#128";
            task_branch = Some "symphony/preview-terminal-console";
            workspace_path = Some workspace_root;
            category = "reused";
            message = "Reused existing preview worktree";
          };
        ];
      task_branch_integrations =
        [
          {
            Runtime_state.issue_id = "ISSUE-131";
            issue_identifier = "#131";
            task_branch = "symphony/document-preview";
            workspace_path = Some runtime_home;
            result = "merged";
            direct_fast_forward = true;
            task_branch_updated_from_loop_start = false;
            attention = None;
            message = "Preview documentation landed cleanly";
          };
        ];
    }
  in
  base
  |> Runtime_state.set_context_status "ISSUE-128"
       (Runtime_state.make_context_status ~state:"ok" ~summary:"Context snapshot attached"
          ~diagnostics_path:"apps/backend/bin/terminal_console_tui.ml" ())
  |> Runtime_state.set_context_status "ISSUE-130"
       (Runtime_state.make_context_status ~state:"warning" ~summary:"Logs tab needs visual review"
          ~diagnostics_path:"apps/backend/test/test_backend.ml" ())

let run () =
  let initial_state = mock_state () in
  let initial_logs =
    [
      "bootstrap 0 created 12 already configured";
      "present .symphony /Users/matheusbbarni/projects/symphony-orchestrator/.symphony";
      "kept settings.json /Users/matheusbbarni/projects/symphony-orchestrator/.symphony/settings.json";
      "kept prompt.md /Users/matheusbbarni/projects/symphony-orchestrator/.symphony/prompt.md";
      "present state /Users/matheusbbarni/projects/symphony-orchestrator/.symphony/state";
      "present workspaces /Users/matheusbbarni/projects/symphony-orchestrator/.symphony/workspaces";
      "startup ready terminal_console tracker compozy_tasks /Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks event=startup outcome=completed mode=terminal_console tracker=compozy_tasks project_number=0 runtime_home=/Users/matheusbbarni/projects/symphony-orchestrator/.symphony workspace_root=/Users/matheusbbarni/projects/symphony-orchestrator/.symphony/workspaces";
      "18:09:52 poll checking compozy_tasks tracker, 0 running, 0 retrying";
    ]
  in
  let runtime : Shell.runtime =
    {
      initial_state;
      initial_logs;
      subscribe = (fun dispatch -> dispatch initial_state);
      safe_aid = (fun _ -> ());
      web_handoff = Shell.default_web_handoff ~port:8080 ();
      local_surfaces =
        [
          Shell.local_surface ~label:"Workspace Repository" ~root:(Sys.getcwd ());
          Shell.local_surface ~label:"Runtime Home" ~root:(Filename.concat (Sys.getcwd ()) ".symphony");
        ];
    }
  in
  Shell.run runtime

let () = run ()
