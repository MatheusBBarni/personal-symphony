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

let _terminal_console_mosaic_link_anchor =
  Symphony_terminal_console_shell.Terminal_console_mosaic.compile_anchor

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

let basename path = Filename.basename path

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

let render_web_dashboard_starting ~port =
  let url = Printf.sprintf "http://0.0.0.0:%d/" port in
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "web_dashboard") (yellow "starting") (dim "url") (cyan url)
    (dim (Printf.sprintf "event=web_dashboard status=starting url=%s" url))

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
      Printf.printf "  %s %s\n%!" (dim "Run") progress.run_id;
      Printf.printf "  %s %s\n%!" (dim "Slug") progress.slug;
      Printf.printf "  %s %s\n%!" (dim "Current step") (Option.value progress.current_step ~default:"none");
      Printf.printf "  %s %d completed, %d failed, %d skipped, %d total\n%!" (dim "Steps") progress.completed
        progress.failed progress.skipped progress.total

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
      let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
      let live = Server.create_live_state ~get_state:(fun () -> state) in
      run_until_stopped (fun () -> Server.serve ~live ~port ~get_state:(fun () -> state) ())
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
        render_bootstrap_report prepared.bootstrap_report;
        let config = prepared.loaded.config in
        let prompt_template = prepared.loaded.prompt_template in
        let ordered_queue, queue_parse_problems = parse_ordered_queue_arg queue_arg in
        let mode = Cli_mode.select ~web in
        render_startup_completed ~mode:(Cli_mode.to_string mode) ~config ~runtime_home:home.runtime_dir;
        if merge_args <> [] then run_manual_merge config merge_args
        else (
          let state = Runtime_readiness.state ?ordered_queue ~queue_parse_problems config in
          if mode = Cli_mode.Web_dashboard then render_banner ();
          if once then (
            if mode = Cli_mode.Terminal_console then render_terminal_console config state;
            0)
          else
            match Runtime_policy.action ~mode ~readiness_gaps:state.Runtime_state.readiness_gaps with
            | Runtime_policy.Serve_readiness_state -> (
                match mode with
                | Cli_mode.Web_dashboard ->
                    let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
                    render_web_dashboard_starting ~port;
                    let live = Server.create_live_state ~get_state:(fun () -> state) in
                    run_until_stopped (fun () -> Server.serve ~live ~port ~get_state:(fun () -> state) ())
                | Cli_mode.Terminal_console ->
                    render_terminal_console config state;
                    run_until_stopped (fun () ->
                        while true do
                          Unix.sleep 60
                        done))
            | Runtime_policy.Run_orchestrator ->
                (match mode with
                | Cli_mode.Web_dashboard ->
                    let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
                    render_web_dashboard_starting ~port;
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
                        Server.serve ~live ~port ~get_state:(fun () -> Orchestrator.get_state orchestrator) ())
                | Cli_mode.Terminal_console ->
                    let orchestrator = Orchestrator.make ?ordered_queue ~config ~prompt_template () in
                    render_terminal_console config state;
                    run_until_stopped (fun () -> Orchestrator.run_forever orchestrator)))
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
