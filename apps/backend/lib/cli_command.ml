open Cmdliner

type runtime_args = {
  workflow_path : string option;
  port : int option;
  once : bool;
  web : bool;
  queue_arg : string option;
  merge_args : string list;
}

type callbacks = {
  run : runtime_args -> int;
  init : unit -> int;
  update : yes:bool -> int;
}

let workflow_arg =
  Arg.(value & pos 0 (some string) None & info [] ~docv:"WORKFLOW" ~doc:"Optional legacy WORKFLOW.md path.")

let port_arg =
  Arg.(value & opt (some int) None & info [ "port" ] ~docv:"PORT" ~doc:"HTTP server port. Overrides server.port.")

let once_arg =
  Arg.(value & flag & info [ "once" ] ~doc:"Validate startup and exit without starting the HTTP server.")

let web_arg =
  Arg.(value & flag & info [ "web" ] ~doc:"Start the backend and Web Dashboard mode instead of the Terminal Console.")

let queue_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "queue" ] ~docv:"ISSUES"
        ~doc:
          "Run an Ordered Queue from comma-separated Workspace Repository issue identifiers. Optional # prefixes are allowed. Only listed issues dispatch, in listed first-admission order, while still respecting agent.maxConcurrentAgents.")

let merge_arg =
  Arg.(
    value
    & opt_all string []
    & info [ "merge" ] ~docv:"ISSUE"
        ~doc:
          "Run a one-shot Manual Task Merge for Workspace Repository issue identifiers. Optional # prefixes, comma-separated values, and repeated --merge flags are allowed.")

let yes_arg =
  Arg.(value & flag & info [ "yes"; "y" ] ~doc:"Update without interactive confirmation.")

let runtime_term callbacks =
  let run workflow_path port once web queue_arg merge_args =
    callbacks.run { workflow_path; port; once; web; queue_arg; merge_args }
  in
  Term.(const run $ workflow_arg $ port_arg $ once_arg $ web_arg $ queue_arg $ merge_arg)

let cmd ~version callbacks =
  let doc = "Run Personal Symphony from a Git Workspace Repository root." in
  let init_cmd =
    Cmd.v (Cmd.info "init" ~doc:"Create missing .symphony runtime files without overwriting edits.")
      Term.(const callbacks.init $ const ())
  in
  let update_cmd =
    Cmd.v (Cmd.info "update" ~doc:"Update the npm-installed CLI Package to the latest npm release.")
      Term.(const (fun yes -> callbacks.update ~yes) $ yes_arg)
  in
  Cmd.group (Cmd.info "symphony" ~doc ~version) ~default:(runtime_term callbacks) [ init_cmd; update_cmd ]

let normalize_help_argv argv =
  Array.map
    (function
      | "-h" -> "--help"
      | "-v" -> "--version"
      | arg -> arg)
    argv
