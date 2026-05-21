let load_config workflow_path =
  let workflow = Workflow.load workflow_path in
  let config = Config.from_workflow workflow in
  (workflow, config)

let colors_enabled () =
  Sys.getenv_opt "NO_COLOR" = None

let version_from_package_json package_json =
  try
    match Yojson.Basic.from_file package_json |> Yojson.Basic.Util.member "version" with
    | `String version when Util.trim version <> "" -> Some (Util.trim version)
    | _ -> None
  with _ -> None

let rec package_json_in_parent ?(remaining = 8) dir =
  if remaining < 0 then None
  else
    let package_json = Filename.concat dir "package.json" in
    if Sys.file_exists package_json then Some package_json
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else package_json_in_parent ~remaining:(remaining - 1) parent

let package_json_candidates () =
  let from_env name =
    match Sys.getenv_opt name with
    | Some value when Util.trim value <> "" -> Some value
    | _ -> None
  in
  let launcher_root =
    from_env "SYMPHONY_LAUNCHER_PATH" |> Option.map (fun path -> path |> Filename.dirname |> Filename.dirname)
  in
  let executable_root =
    Sys.executable_name |> Filename.dirname |> Filename.dirname |> fun root -> Some root
  in
  [ from_env "SYMPHONY_PACKAGE_ROOT"; launcher_root; executable_root; Some (Sys.getcwd ()) ]
  |> List.filter_map (fun root -> Option.bind root package_json_in_parent)

let version =
  package_json_candidates () |> List.find_map version_from_package_json |> Option.value ~default:"unknown"

let _terminal_console_tui_link_anchor =
  Symphony_terminal_console_shell.Terminal_console_tui.compile_anchor

module Terminal_console_tui = Symphony_terminal_console_shell.Terminal_console_tui
module Terminal_console_runtime = Symphony_terminal_console_shell.Terminal_console_runtime

let ansi code = if colors_enabled () then "\027[" ^ code ^ "m" else ""
let color code text = ansi code ^ text ^ ansi "0"
let blue text = color "34;1" text
let cyan text = color "36;1" text
let green text = color "32;1" text
let yellow text = color "33;1" text
let red text = color "31;1" text
let dim text = color "2" text

let status_badge = function
  | Runtime_home.Created -> green "created"
  | Runtime_home.Already_present -> cyan "present"
  | Runtime_home.Skipped_existing -> yellow "kept"

let status_text = function
  | Runtime_home.Created -> "created"
  | Runtime_home.Already_present -> "present"
  | Runtime_home.Skipped_existing -> "kept"

let basename path = Filename.basename path

let bootstrap_report_log_lines report =
  let created =
    List.filter (fun (item : Runtime_home.bootstrap_item) -> item.status = Runtime_home.Created) report |> List.length
  in
  let existing = List.length report - created in
  Printf.sprintf "bootstrap %d created %d already configured" created existing
  :: List.map
       (fun (item : Runtime_home.bootstrap_item) ->
         Printf.sprintf "%s %s %s" (status_text item.status) (basename item.path) item.path)
       report

let render_bootstrap_report report =
  let created =
    List.filter (fun (item : Runtime_home.bootstrap_item) -> item.status = Runtime_home.Created) report |> List.length
  in
  let existing = List.length report - created in
  Printf.eprintf "%s %s %s\n%!" (blue "bootstrap") (green (Printf.sprintf "%d created" created))
    (dim (Printf.sprintf "%d already configured" existing));
  List.iter
    (fun (item : Runtime_home.bootstrap_item) ->
      Printf.eprintf "  %s %-7s %s\n%!" (status_badge item.status) (basename item.path) (dim item.path))
    report

let tracker_issue_source config =
  match config.Config.tracker.kind with
  | "github" -> Printf.sprintf "%s/%s" config.tracker.owner config.tracker.repo
  | "minibeads" -> config.tracker.minibeads_root
  | "compozy_tasks" -> config.tracker.compozy_root
  | kind -> kind

let tracker_status_source config =
  match config.Config.tracker.kind with
  | "github" -> Printf.sprintf "GitHub Project #%d" config.tracker.project_number
  | "minibeads" -> Printf.sprintf "Local Issue Files via %s" config.tracker.minibeads_command
  | "compozy_tasks" -> "Compozy PRD-run task files"
  | kind -> kind

let render_startup_completed ~mode ~config ~runtime_home =
  let event = Runtime_startup.startup_completed_event ~mode ~config ~runtime_home in
  Printf.eprintf "%s %s %s %s %s %s %s\n%!" (blue "startup") (green "ready") (dim mode) (dim "tracker")
    (cyan config.Config.tracker.kind) (tracker_issue_source config)
    (dim event)

let startup_completed_log_line ~mode ~config ~runtime_home =
  let event = Runtime_startup.startup_completed_event ~mode ~config ~runtime_home in
  Printf.sprintf "startup ready %s tracker %s %s %s" mode config.Config.tracker.kind
    (tracker_issue_source config) event

let dashboard_url ?auth_token ~host ~port () =
  let base = Printf.sprintf "http://%s:%d/" host port in
  match auth_token with None -> base | Some token -> base ^ "?symphony_auth=" ^ token

let render_web_dashboard_starting ?auth_token ~host ~port () =
  let url = dashboard_url ?auth_token ~host ~port () in
  let auth_status = match auth_token with Some _ -> "required" | None -> "not_required" in
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "web_dashboard") (yellow "starting") (dim "url") (cyan url)
    (dim (Printf.sprintf "event=web_dashboard status=starting server_host=%s server_port=%d auth=%s" host port auth_status))

let symphony_banner =
  [
    " ____  __   __ __  __ ____  _   _  ___  _   _ __   __";
    "/ ___| \\ \\ / /|  \\/  |  _ \\| | | |/ _ \\| \\ | |\\ \\ / /";
    "\\___ \\  \\ V / | |\\/| | |_) | |_| | | | |  \\| | \\ V / ";
    " ___) |  | |  | |  | |  __/|  _  | |_| | |\\  |  | |  ";
    "|____/   |_|  |_|  |_|_|   |_| |_|\\___/|_| \\_|  |_|  ";
  ]

let print_section title = Printf.printf "\n%s\n%!" (cyan title)

let render_compozy_progress = function
  | None -> ()
  | Some (progress : Runtime_state.compozy_progress) ->
      print_section "PRD Run Progress";
      Terminal_console.compozy_progress_lines progress
      |> List.iter (fun (label, value) -> Printf.printf "  %s %s\n%!" (dim label) value)

let render_banner () =
  List.iter (fun line -> Printf.printf "%s\n%!" (blue line)) symphony_banner;
  Printf.printf "\n%!"

let render_terminal_console config state =
  render_banner ();
  print_section "Issue Tracker";
  Printf.printf "  %s %s\n%!" (dim "Kind") config.Config.tracker.kind;
  Printf.printf "  %s %s\n%!" (dim "Issue source") (tracker_issue_source config);
  Printf.printf "  %s %s\n%!" (dim "Status source") (tracker_status_source config);
  Printf.printf "  %s %s\n%!" (dim "Workspace") config.workspace.root;
  print_section "Activity";
  Printf.printf "  %s %d running, %d retrying\n%!" (dim "Agents") (List.length state.Runtime_state.running)
    (List.length state.retrying);
  Printf.printf "  %s %d total\n%!" (dim "Tokens") state.usage_totals.total_tokens;
  render_compozy_progress state.Runtime_state.compozy_progress;
  (match state.Runtime_state.ordered_queue with
  | None -> ()
  | Some queue ->
      let count status =
        queue.entries |> List.filter (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = status) |> List.length
      in
      print_section "Ordered Queue";
      Printf.printf "  %s %d total, %d running, %d retrying, %d completed, %d skipped\n%!" (dim "Entries")
        (List.length queue.entries) (count "running") (count "retrying") (count "completed") (count "skipped");
      (match List.find_opt (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = "pending") queue.entries with
      | Some entry -> Printf.printf "  %s %s\n%!" (dim "Next") entry.issue_identifier
      | None -> ()));
  print_section "Readiness";
  match state.Runtime_state.readiness_gaps with
  | [] -> Printf.printf "  %s ready\n%!" (green "OK")
  | gaps ->
      Printf.printf "  %s %d gap%s\n%!" (yellow "Needs attention") (List.length gaps)
        (if List.length gaps = 1 then "" else "s");
      List.iter
        (fun (gap : Runtime_state.readiness_gap) ->
          Printf.printf "  %s %s\n%!" (red gap.requirement) gap.remediation)
        gaps;
      Printf.printf "  %s\n%!" (dim "Dispatch is disabled until readiness gaps are resolved.")

let run_legacy workflow_path port once =
  let run_until_stopped f =
    f ();
    0
  in
  try
    let workflow, config = load_config workflow_path in
    let state = Runtime_readiness.state config in
    let example_issue = Issue.empty ~id:"local" ~identifier:"#0" ~title:"Local dry run" ~state:"Todo" in
    let _rendered =
      if workflow.prompt_template = "" then "You are working on an issue from GitHub."
      else Prompt.render ~issue:example_issue ~attempt:None workflow.prompt_template
    in
    Printf.eprintf
      "event=startup outcome=completed tracker=github owner=%s repo=%s project_number=%d workspace_root=%s\n%!"
      config.tracker.owner config.tracker.repo config.tracker.project_number config.workspace.root;
    if once then 0
    else
      let host = config.server.host in
      let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
      let auth_token = if Server.host_requires_auth host then Some (Server.generate_auth_token ()) else None in
      let live = Server.create_live_state ~get_state:(fun () -> state) in
      run_until_stopped (fun () -> Server.serve ?auth_token ~live ~host ~port ~get_state:(fun () -> state) ())
  with
  | Workflow.Error err ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" (Workflow.string_of_error err);
      1
  | Config.Invalid_config msg | Prompt.Template_render_error msg | Workspace.Workspace_error msg ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
      1
  | exn ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" (Printexc.to_string exn);
      1

let parse_ordered_queue_arg = function
  | None -> (None, [])
  | Some text -> (
      match Ordered_queue.parse text with
      | Ok queue -> (Some queue, [])
      | Error problems -> (None, problems))

let render_manual_merge_report report =
  List.iter
    (fun (outcome : Manual_merge.outcome) ->
      let action =
        match outcome.integration with Manual_merge.Merged -> "merged" | Manual_merge.Already_integrated -> "already-integrated"
      in
      let status =
        match outcome.status_update with None -> "" | Some status -> Printf.sprintf " status=%s" status
      in
      let cleanup =
        match outcome.cleanup_error with None -> "" | Some error -> Printf.sprintf " cleanup=failed reason=%s" error
      in
      Printf.printf "merge %s branch=%s action=%s%s%s\n%!" outcome.issue.Issue.identifier outcome.branch action status
        cleanup)
    report.Manual_merge.outcomes;
  Printf.printf "summary selected=%d merged=%d already_integrated=%d cleanup_failures=%d\n%!"
    (List.length report.outcomes) report.merged report.already_integrated report.cleanup_failures

let run_manual_merge config merge_args =
  let tracker = Issue_tracker.make config in
  match Manual_merge.run ~tracker config merge_args with
  | Ok report ->
      render_manual_merge_report report;
      if report.cleanup_failures = 0 then 0 else 1
  | Error errors ->
      List.iter (fun error -> Printf.eprintf "merge failed: %s\n%!" error) errors;
      1

let run_runtime port once web queue_arg merge_args overrides =
  let run_until_stopped f =
    f ();
    0
  in
  try
    match Runtime_startup.prepare_runtime ~overrides () with
    | Error msg ->
        Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
        1
    | Ok prepared ->
        let home = prepared.Runtime_startup.home in
        let terminal_console_initial_logs = ref (bootstrap_report_log_lines prepared.bootstrap_report) in
        render_bootstrap_report prepared.bootstrap_report;
        let config = prepared.loaded.config in
        let prompt_template = prepared.loaded.prompt_template in
        let ordered_queue, queue_parse_problems = parse_ordered_queue_arg queue_arg in
        let mode = Cli_mode.select ~web in
        let mode_text = Cli_mode.to_string mode in
        terminal_console_initial_logs :=
          !terminal_console_initial_logs @ [ startup_completed_log_line ~mode:mode_text ~config ~runtime_home:home.runtime_dir ];
        render_startup_completed ~mode:mode_text ~config ~runtime_home:home.runtime_dir;
        if merge_args <> [] then run_manual_merge config merge_args
        else (
          let state = Runtime_readiness.state ?ordered_queue ~queue_parse_problems config in
          let terminal_console_host = config.server.host in
          let terminal_console_port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
          let terminal_console_theme =
            match Terminal_console_settings.load_theme home with
            | Terminal_console_settings.Theme_valid theme -> theme
            | Terminal_console_settings.Theme_fallback { fallback; reason; _ } ->
                terminal_console_initial_logs := !terminal_console_initial_logs @ [ reason ];
                fallback
          in
          let terminal_console_settings : Terminal_console_tui.settings_state =
            { theme = terminal_console_theme; port = terminal_console_port }
          in
          let save_terminal_console_settings (settings : Terminal_console_tui.settings_state) =
            match Terminal_console_settings.validate_theme settings.theme with
            | Terminal_console_settings.Theme_fallback { reason; _ } -> Terminal_console_tui.Settings_rejected reason
            | Terminal_console_settings.Theme_valid theme -> (
                match Terminal_console_settings.validate_port (string_of_int settings.port) with
                | Terminal_console_settings.Port_invalid reason -> Terminal_console_tui.Settings_rejected reason
                | Terminal_console_settings.Port_valid _ -> (
                    try
                      match Terminal_console_settings.save_theme home theme with
                      | Terminal_console_settings.Theme_fallback { reason; _ } ->
                          Terminal_console_tui.Settings_rejected reason
                      | Terminal_console_settings.Theme_valid saved_theme -> (
                          match Terminal_console_settings.save_dashboard_port home (string_of_int settings.port) with
                          | Terminal_console_settings.Port_rejected reason -> Terminal_console_tui.Settings_rejected reason
                          | Terminal_console_settings.Port_update_failed reason -> Terminal_console_tui.Settings_failed reason
                          | Terminal_console_settings.Port_updated port ->
                              Terminal_console_tui.Settings_saved { theme = saved_theme; port })
                    with exn -> Terminal_console_tui.Settings_failed (Printexc.to_string exn)))
          in
          let terminal_console_web_handoff =
            Terminal_console_tui.default_web_handoff ~host:terminal_console_host ~port:terminal_console_port ()
          in
          let terminal_console_local_surfaces =
            [
              Terminal_console_tui.local_surface ~label:"Workspace Repository" ~root:config.repository_root;
              Terminal_console_tui.local_surface ~label:"Runtime Home" ~root:home.runtime_dir;
            ]
          in
          if mode = Cli_mode.Web_dashboard then render_banner ();
          match
            Terminal_console_runtime.select_branch ~once ~mode ~merge_args:[]
              ~readiness_gaps:state.Runtime_state.readiness_gaps
          with
          | Terminal_console_runtime.Manual_merge -> assert false
          | Once ->
              if mode = Cli_mode.Terminal_console then render_terminal_console config state;
              0
          | Web_dashboard Runtime_policy.Serve_readiness_state ->
              let host = config.server.host in
              let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
              let auth_token = if Server.host_requires_auth host then Some (Server.generate_auth_token ()) else None in
              render_web_dashboard_starting ?auth_token ~host ~port ();
              let live = Server.create_live_state ~get_state:(fun () -> state) in
              run_until_stopped (fun () ->
                  Dashboard_service.serve_foreground ~workspace_root:config.repository_root
                    ~runtime_home:home.runtime_dir ~host ~port ~mode:Dashboard_service.web_dashboard_mode ~auth_token
                    ~live ~get_state:(fun () -> state) ())
          | Web_dashboard Runtime_policy.Run_orchestrator ->
              let host = config.server.host in
              let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
              let auth_token = if Server.host_requires_auth host then Some (Server.generate_auth_token ()) else None in
              render_web_dashboard_starting ?auth_token ~host ~port ();
              let orchestrator_ref = ref None in
              let live =
                Server.create_live_state ~get_state:(fun () ->
                    match !orchestrator_ref with
                    | Some orchestrator -> Orchestrator.get_state orchestrator
                    | None -> state)
              in
              let orchestrator =
                Orchestrator.make ?ordered_queue ~config ~prompt_template
                  ~notify_state:(fun _ -> Server.broadcast_live_state live)
                  ()
              in
              orchestrator_ref := Some orchestrator;
              ignore (Thread.create Orchestrator.run_forever orchestrator);
              run_until_stopped (fun () ->
                  Dashboard_service.serve_foreground ~workspace_root:config.repository_root
                    ~runtime_home:home.runtime_dir ~host ~port ~mode:Dashboard_service.web_dashboard_mode ~auth_token
                    ~live ~get_state:(fun () -> Orchestrator.get_state orchestrator) ())
          | Terminal_console_readiness ->
              Terminal_console_runtime.run ~web_handoff:terminal_console_web_handoff
                ~local_surfaces:terminal_console_local_surfaces ~settings:terminal_console_settings
                ~save_settings:save_terminal_console_settings ~initial_logs:!terminal_console_initial_logs
                ~initial_state:state ();
              0
          | Terminal_console_orchestrator ->
              Terminal_console_runtime.run ~web_handoff:terminal_console_web_handoff
                ~local_surfaces:terminal_console_local_surfaces ~settings:terminal_console_settings
                ~save_settings:save_terminal_console_settings ~initial_logs:!terminal_console_initial_logs
                ~initial_state:state
                ~start_orchestration:(fun ~notify_state ->
                  let orchestrator = Orchestrator.make ?ordered_queue ~config ~prompt_template ~notify_state () in
                  notify_state (Orchestrator.get_state orchestrator);
                  ignore
                    (Terminal_console_runtime.start_background_orchestration (fun () ->
                         Orchestrator.run_forever orchestrator)))
                ();
              0)
  with
  | Runtime_home.Runtime_home_error msg | Config.Invalid_config msg | Prompt.Template_render_error msg
  | Workspace.Workspace_error msg ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
      1
  | exn ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" (Printexc.to_string exn);
      1

let run workflow_path port once web queue_arg merge_args overrides =
  match workflow_path with
  | Some path -> run_legacy path port once
  | None -> run_runtime port once web queue_arg merge_args overrides

let init () =
  try
    match Runtime_home.require_workspace_root () with
    | Error msg ->
        Printf.eprintf "event=init outcome=failed reason=%s\n%!" msg;
        1
    | Ok workspace_root ->
        let _, report = Runtime_home.bootstrap workspace_root in
        render_bootstrap_report report;
        Printf.eprintf "event=init outcome=completed runtime_home=%s\n%!" (Filename.concat workspace_root Runtime_home.runtime_dir_name);
        0
  with Runtime_home.Runtime_home_error msg ->
    Printf.eprintf "event=init outcome=failed reason=%s\n%!" msg;
    1

let update yes = Update_cli.run ~current_version:version ~yes ()

let callbacks =
  {
    Cli_command.run =
      (fun args ->
        run args.workflow_path args.port args.once args.web args.queue_arg args.merge_args args.overrides);
    init;
    update = (fun ~yes -> update yes);
  }

let () =
  exit (Cli_command.eval ~version callbacks ~argv:Sys.argv)
