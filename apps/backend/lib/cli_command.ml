open Cmdliner

type runtime_args = {
  workflow_path : string option;
  port : int option;
  once : bool;
  web : bool;
  queue_arg : string option;
  merge_args : string list;
  overrides : Config.runtime_invocation_overrides;
}

type callbacks = {
  run : runtime_args -> int;
  init : unit -> int;
  update : yes:bool -> int;
}

let workflow_arg =
  Arg.(value & pos 0 (some string) None & info [] ~docv:"WORKFLOW" ~doc:"Optional legacy WORKFLOW.md path.")

let polling_interval_ms_flag = "polling.intervalMs"
let workspace_root_flag = "workspace.root"
let agent_max_concurrent_agents_flag = "agent.maxConcurrentAgents"
let agent_max_turns_flag = "agent.maxTurns"
let agent_max_retry_backoff_ms_flag = "agent.maxRetryBackoffMs"

let runtime_only_override_flags =
  [
    polling_interval_ms_flag;
    workspace_root_flag;
    agent_max_concurrent_agents_flag;
    agent_max_turns_flag;
    agent_max_retry_backoff_ms_flag;
  ]

let runtime_only_override_options = List.map (fun name -> "--" ^ name) runtime_only_override_flags

let strict_positive_int flag =
  let parse raw =
    if raw = "" then Error (`Msg (flag ^ " must be a positive integer"))
    else if not (String.for_all (function '0' .. '9' -> true | _ -> false) raw) then
      Error (`Msg (flag ^ " must be a positive integer"))
    else
      match int_of_string_opt raw with
      | Some value when value > 0 -> Ok value
      | _ -> Error (`Msg (flag ^ " must be a positive integer"))
  in
  Arg.conv (parse, Format.pp_print_int)

let polling_interval_ms_arg =
  Arg.(
    value
    & opt (some (strict_positive_int polling_interval_ms_flag)) None
    & info [ polling_interval_ms_flag ] ~docv:"MS"
        ~doc:"Override Runtime Settings polling.intervalMs for the current invocation only.")

let workspace_root_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ workspace_root_flag ] ~docv:"PATH"
        ~doc:
          "Override Runtime Settings workspace.root for current-invocation Agent Worktree placement only; does not select the Workspace Repository.")

let agent_max_concurrent_agents_arg =
  Arg.(
    value
    & opt (some (strict_positive_int agent_max_concurrent_agents_flag)) None
    & info [ agent_max_concurrent_agents_flag ] ~docv:"COUNT"
        ~doc:"Override Runtime Settings agent.maxConcurrentAgents for the current invocation only.")

let agent_max_turns_arg =
  Arg.(
    value
    & opt (some (strict_positive_int agent_max_turns_flag)) None
    & info [ agent_max_turns_flag ] ~docv:"COUNT"
        ~doc:"Override Runtime Settings agent.maxTurns for the current invocation only.")

let agent_max_retry_backoff_ms_arg =
  Arg.(
    value
    & opt (some (strict_positive_int agent_max_retry_backoff_ms_flag)) None
    & info [ agent_max_retry_backoff_ms_flag ] ~docv:"MS"
        ~doc:"Override Runtime Settings agent.maxRetryBackoffMs for the current invocation only.")

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
          "Run an Ordered Queue from comma-separated Workspace Repository issue identifiers. Optional # prefixes are allowed. When Runtime Settings select tracker.kind = \"compozy_tasks\", this flag also accepts bare Compozy PRD Run slugs as a queue-only shortcut. Only listed issues dispatch, in listed first-admission order, while still respecting agent.maxConcurrentAgents.")

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
  let run workflow_path polling_interval_ms workspace_root agent_max_concurrent_agents agent_max_turns
      agent_max_retry_backoff_ms port once web queue_arg merge_args =
    let overrides =
      {
        Config.polling_interval_ms = polling_interval_ms;
        workspace_root;
        agent_max_concurrent_agents;
        agent_max_turns;
        agent_max_retry_backoff_ms;
      }
    in
    callbacks.run { workflow_path; port; once; web; queue_arg; merge_args; overrides }
  in
  Term.(
    const run $ workflow_arg $ polling_interval_ms_arg $ workspace_root_arg $ agent_max_concurrent_agents_arg
    $ agent_max_turns_arg $ agent_max_retry_backoff_ms_arg $ port_arg $ once_arg $ web_arg $ queue_arg $ merge_arg)

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

let starts_with ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len && String.sub value 0 prefix_len = prefix

let runtime_only_override_option arg =
  List.find_opt (fun option -> arg = option || starts_with ~prefix:(option ^ "=") arg) runtime_only_override_options

let normalize_runtime_override_values argv =
  let argv_len = Array.length argv in
  let rec loop index acc =
    if index >= argv_len then Array.of_list (List.rev acc)
    else
      let arg = argv.(index) in
      match runtime_only_override_option arg with
      | Some option when arg = option && index + 1 < argv_len ->
          loop (index + 2) ((option ^ "=" ^ argv.(index + 1)) :: acc)
      | _ -> loop (index + 1) (arg :: acc)
  in
  loop 0 []

let value_option_names = "port" :: "queue" :: "merge" :: runtime_only_override_flags

let option_consumes_next_value arg =
  match String.split_on_char '=' arg with
  | [ option ] when starts_with ~prefix:"--" option ->
      List.exists (fun name -> option = "--" ^ name) value_option_names
  | _ -> false

let unsupported_runtime_override_error argv =
  let argv_len = Array.length argv in
  let rec scan index skip_value first_positional override_option =
    if index >= argv_len then (first_positional, override_option)
    else
      let arg = argv.(index) in
      if index = 0 then scan (index + 1) false first_positional override_option
      else if skip_value then scan (index + 1) false first_positional override_option
      else
        let override_option =
          match override_option with Some _ -> override_option | None -> runtime_only_override_option arg
        in
        if arg = "--" then
          let first_positional =
            match (first_positional, index + 1 < argv_len) with None, true -> Some argv.(index + 1) | _ -> first_positional
          in
          scan argv_len false first_positional override_option
        else if starts_with ~prefix:"--" arg then
          scan (index + 1) (option_consumes_next_value arg) first_positional override_option
        else if starts_with ~prefix:"-" arg then scan (index + 1) false first_positional override_option
        else
          let first_positional = match first_positional with Some _ -> first_positional | None -> Some arg in
          scan (index + 1) false first_positional override_option
  in
  let first_positional, override_option = scan 0 false None None in
  match (first_positional, override_option) with
  | Some _, Some option ->
      Some
        (Printf.sprintf
           "%s is a Runtime Settings Invocation Override and applies only to the default runtime command." option)
  | _ -> None

let eval ~version callbacks ~argv =
  let argv = normalize_help_argv argv in
  match unsupported_runtime_override_error argv with
  | Some message ->
      Printf.eprintf "event=cli outcome=failed reason=%s\n%!" message;
      1
  | None -> Cmd.eval' ~argv:(normalize_runtime_override_values argv) (cmd ~version callbacks)
