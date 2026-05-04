let load_config workflow_path =
  let workflow = Workflow.load workflow_path in
  let config = Config.from_workflow workflow in
  (workflow, config)

let readiness_state config =
  let local_gaps = Config.readiness_gaps config in
  let gaps = match local_gaps with [] -> Github_tracker.remote_readiness_gaps config | gaps -> gaps in
  let last_error =
    match gaps with
    | [] -> None
    | gap :: _ -> Some (gap.requirement ^ ": " ^ gap.remediation)
  in
  let readiness_gaps =
    List.map
      (fun (gap : Config.readiness_gap) ->
        { Runtime_state.requirement = gap.requirement; remediation = gap.remediation })
      gaps
  in
  Runtime_state.empty ?last_error ~readiness_gaps ()

let colors_enabled () =
  Sys.getenv_opt "NO_COLOR" = None

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

let render_startup_completed ~mode ~config ~runtime_home =
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "startup") (green "ready") (dim mode)
    (Printf.sprintf "%s/%s" config.Config.tracker.owner config.tracker.repo)
    (dim (Printf.sprintf "project #%d - %s" config.tracker.project_number runtime_home))

let render_web_dashboard_starting ~port =
  let url = Printf.sprintf "http://0.0.0.0:%d/" port in
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "web_dashboard") (yellow "starting") (dim "url") (cyan url)
    (dim (Printf.sprintf "event=web_dashboard status=starting url=%s" url))

let symphoony_banner =
  [
    " ____  __   __ __  __ ____  _   _  ___   ___  _   _ __   __";
    "/ ___| \\ \\ / /|  \\/  |  _ \\| | | |/ _ \\ / _ \\| \\ | |\\ \\ / /";
    "\\___ \\  \\ V / | |\\/| | |_) | |_| | | | | | | |  \\| | \\ V / ";
    " ___) |  | |  | |  | |  __/|  _  | |_| | |_| | |\\  |  | |  ";
    "|____/   |_|  |_|  |_|_|   |_| |_|\\___/ \\___/|_| \\_|  |_|  ";
  ]

let print_section title = Printf.printf "\n%s\n%!" (cyan title)

let render_banner () = List.iter (fun line -> Printf.printf "%s\n%!" (blue line)) symphoony_banner

let render_terminal_console config state =
  render_banner ();
  print_section "Tracker";
  Printf.printf "  %s %s/%s\n%!" (dim "Repository") config.Config.tracker.owner config.tracker.repo;
  Printf.printf "  %s GitHub Project #%d\n%!" (dim "Project") config.tracker.project_number;
  Printf.printf "  %s %s\n%!" (dim "Workspace") config.workspace.root;
  print_section "Activity";
  Printf.printf "  %s %d running, %d retrying\n%!" (dim "Agents") (List.length state.Runtime_state.running)
    (List.length state.retrying);
  Printf.printf "  %s %d total\n%!" (dim "Tokens") state.codex_totals.total_tokens;
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
  try
    let workflow, config = load_config workflow_path in
    let state = readiness_state config in
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
      Server.serve ~port ~get_state:(fun () -> state);
      0
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

let load_runtime_config home =
  Runtime_home.load_env home;
  let config = Config.from_settings_file ~workspace_root:home.Runtime_home.workspace_root home.settings_path in
  let prompt_template = Runtime_home.load_prompt home in
  let example_issue = Issue.empty ~id:"local" ~identifier:"#0" ~title:"Local dry run" ~state:"Todo" in
  let _rendered = Prompt.render ~issue:example_issue ~attempt:None prompt_template in
  (config, prompt_template)

let run_runtime port once web =
  try
    match Runtime_home.require_workspace_root () with
    | Error msg ->
        Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
        1
    | Ok workspace_root ->
        let home, report = Runtime_home.bootstrap workspace_root in
        render_bootstrap_report report;
        let config, prompt_template = load_runtime_config home in
        let mode = Cli_mode.select ~web in
        let state = readiness_state config in
        render_startup_completed ~mode:(Cli_mode.to_string mode) ~config ~runtime_home:home.runtime_dir;
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
                  Server.serve ~port ~get_state:(fun () -> state);
                  0
              | Cli_mode.Terminal_console ->
                  render_terminal_console config state;
                  while true do
                    Unix.sleep 60
                  done;
                  0)
          | Runtime_policy.Run_orchestrator ->
              let orchestrator = Orchestrator.make ~config ~prompt_template () in
              (match mode with
              | Cli_mode.Web_dashboard ->
                  let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
                  render_web_dashboard_starting ~port;
                  ignore (Thread.create Orchestrator.run_forever orchestrator);
                  Server.serve ~port ~get_state:(fun () -> Orchestrator.get_state orchestrator);
                  0
              | Cli_mode.Terminal_console ->
                  render_terminal_console config state;
                  Orchestrator.run_forever orchestrator;
                  0)
  with
  | Runtime_home.Runtime_home_error msg | Config.Invalid_config msg | Prompt.Template_render_error msg
  | Workspace.Workspace_error msg ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
      1
  | exn ->
      Printf.eprintf "event=startup outcome=failed reason=%s\n%!" (Printexc.to_string exn);
      1

let run workflow_path port once web =
  match workflow_path with
  | Some path -> run_legacy path port once
  | None -> run_runtime port once web

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

open Cmdliner

let workflow_arg =
  Arg.(value & pos 0 (some string) None & info [] ~docv:"WORKFLOW" ~doc:"Optional legacy WORKFLOW.md path.")

let port_arg =
  Arg.(value & opt (some int) None & info [ "port" ] ~docv:"PORT" ~doc:"HTTP server port. Overrides server.port.")

let once_arg =
  Arg.(value & flag & info [ "once" ] ~doc:"Validate startup and exit without starting the HTTP server.")

let web_arg =
  Arg.(value & flag & info [ "web" ] ~doc:"Start the backend and Web Dashboard mode instead of the Terminal Console.")

let cmd =
  let doc = "Run Personal Symphony from a Git Workspace Repository root." in
  let default = Term.(const run $ workflow_arg $ port_arg $ once_arg $ web_arg) in
  let init_cmd =
    Cmd.v (Cmd.info "init" ~doc:"Create missing .symphony runtime files without overwriting edits.") Term.(const init $ const ())
  in
  Cmd.group (Cmd.info "symphony" ~doc) ~default [ init_cmd ]

let () = exit (Cmd.eval' cmd)
