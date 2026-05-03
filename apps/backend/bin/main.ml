let load_config workflow_path =
  let workflow = Workflow.load workflow_path in
  let config = Config.from_workflow workflow in
  (workflow, config)

let readiness_state config =
  let gaps = Config.readiness_gaps config in
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

let render_bootstrap_report report =
  List.iter
    (fun (item : Runtime_home.bootstrap_item) ->
      Printf.eprintf "event=bootstrap status=%s path=%s\n%!" (Runtime_home.status_to_string item.status) item.path)
    report

let render_terminal_console config state =
  Printf.printf "Personal Symphony Terminal Console\n%!";
  Printf.printf "tracker=github owner=%s repo=%s project_number=%d\n%!" config.Config.tracker.owner
    config.tracker.repo config.tracker.project_number;
  match state.Runtime_state.readiness_gaps with
  | [] -> Printf.printf "Readiness: ready\n%!"
  | gaps ->
      Printf.printf "Readiness Gaps:\n%!";
      List.iter
        (fun (gap : Runtime_state.readiness_gap) ->
          Printf.printf "- %s: %s\n%!" gap.requirement gap.remediation)
        gaps;
      Printf.printf "Dispatch disabled until readiness gaps are resolved.\n%!"

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
  let config = Config.from_settings_file ~workspace_root:home.Runtime_home.workspace_root home.settings_path in
  let prompt_template = Runtime_home.load_prompt home in
  let example_issue = Issue.empty ~id:"local" ~identifier:"#0" ~title:"Local dry run" ~state:"Todo" in
  let _rendered = Prompt.render ~issue:example_issue ~attempt:None prompt_template in
  config

let run_runtime port once web =
  try
    match Runtime_home.require_workspace_root () with
    | Error msg ->
        Printf.eprintf "event=startup outcome=failed reason=%s\n%!" msg;
        1
    | Ok workspace_root ->
        let home, report = Runtime_home.bootstrap workspace_root in
        render_bootstrap_report report;
        let config = load_runtime_config home in
        let mode = Cli_mode.select ~web in
        let state = readiness_state config in
        Printf.eprintf
          "event=startup outcome=completed mode=%s tracker=github owner=%s repo=%s project_number=%d runtime_home=%s\n%!"
          (Cli_mode.to_string mode) config.tracker.owner config.tracker.repo config.tracker.project_number home.runtime_dir;
        if once then (
          if mode = Cli_mode.Terminal_console then render_terminal_console config state;
          0)
        else
          match mode with
          | Cli_mode.Web_dashboard ->
              let port = Option.value port ~default:(Option.value config.server.port ~default:8080) in
              Printf.eprintf "event=web_dashboard status=starting url=http://127.0.0.1:%d/\n%!" port;
              Server.serve ~port ~get_state:(fun () -> state);
              0
          | Cli_mode.Terminal_console ->
              render_terminal_console config state;
              while true do
                Unix.sleep 60
              done;
              0
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
