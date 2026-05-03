let load_config workflow_path =
  let workflow = Workflow.load workflow_path in
  let config = Config.from_workflow workflow in
  (workflow, config)

let run workflow_path port once =
  try
    let workflow, config = load_config workflow_path in
    let state =
      match Config.validate_for_dispatch config with
      | Ok () -> Runtime_state.empty ()
      | Error msg -> Runtime_state.empty ~last_error:msg ()
    in
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

open Cmdliner

let workflow_arg =
  Arg.(value & pos 0 string "WORKFLOW.md" & info [] ~docv:"WORKFLOW" ~doc:"Path to WORKFLOW.md.")

let port_arg =
  Arg.(value & opt (some int) None & info [ "port" ] ~docv:"PORT" ~doc:"HTTP server port. Overrides server.port.")

let once_arg =
  Arg.(value & flag & info [ "once" ] ~doc:"Validate startup and exit without starting the HTTP server.")

let cmd =
  let doc = "Run the Personal Symphony OCaml backend." in
  Cmd.v (Cmd.info "symphony" ~doc) Term.(const run $ workflow_arg $ port_arg $ once_arg)

let () = exit (Cmd.eval' cmd)
