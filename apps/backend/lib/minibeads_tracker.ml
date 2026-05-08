type command_status = Exited of int | Signaled of int | Stopped of int

type command_result = {
  status : command_status;
  stdout : string;
  stderr : string;
}

type command_runner = {
  command_available : string -> bool;
  run : cwd:string -> command:string -> command_result;
}

let is_env_assignment word =
  match String.index_opt word '=' with None -> false | Some index -> index > 0

let rec drop_env_assignments = function
  | word :: rest when is_env_assignment word -> drop_env_assignments rest
  | words -> words

let command_words command =
  String.split_on_char ' ' command |> List.filter (fun word -> Util.trim word <> "")

let command_executable command =
  let words =
    match command_words command with
    | "env" :: rest -> drop_env_assignments rest
    | words -> drop_env_assignments words
  in
  match words with executable :: _ -> Some executable | [] -> None

let executable_available executable =
  if String.contains executable '/' then
    try
      Unix.access executable [ Unix.X_OK ];
      true
    with Unix.Unix_error _ -> false
  else
    match Unix.system (Printf.sprintf "command -v %s >/dev/null 2>&1" (Util.shell_quote executable)) with
    | Unix.WEXITED 0 -> true
    | _ -> false

let default_run ~cwd ~command =
  let shell_command =
    Printf.sprintf "cd %s && %s --version 2>&1" (Util.shell_quote cwd) command
  in
  let ic = Unix.open_process_in shell_command in
  let output =
    Fun.protect ~finally:(fun () -> ()) (fun () ->
        let buffer = Buffer.create 256 in
        (try
           while true do
             Buffer.add_string buffer (input_line ic);
             Buffer.add_char buffer '\n'
           done
         with End_of_file -> ());
        Buffer.contents buffer)
  in
  let status =
    match Unix.close_process_in ic with
    | Unix.WEXITED code -> Exited code
    | Unix.WSIGNALED signal -> Signaled signal
    | Unix.WSTOPPED signal -> Stopped signal
  in
  { status; stdout = output; stderr = "" }

let default_runner = { command_available = executable_available; run = default_run }

let runtime_gap requirement remediation =
  { Runtime_state.requirement; remediation }

let store_gap config =
  runtime_gap "tracker.minibeads.store"
    (Printf.sprintf
       "Create the minibeads local issue store at %s or update tracker.root in .symphony/settings.json."
       config.Config.minibeads_root)

let command_gap command =
  runtime_gap "tracker.minibeads.command"
    (Printf.sprintf
       "Install minibeads or update tracker.command in .symphony/settings.json so Symphony can run %S."
       command)

let status_text = function
  | Exited code -> Printf.sprintf "exit %d" code
  | Signaled signal -> Printf.sprintf "signal %d" signal
  | Stopped signal -> Printf.sprintf "stopped %d" signal

let sanitize_diagnostic text =
  let buffer = Buffer.create (String.length text) in
  let pending_space = ref false in
  let flush_space () =
    if !pending_space && Buffer.length buffer > 0 then Buffer.add_char buffer ' ';
    pending_space := false
  in
  String.iter
    (fun ch ->
      let code = Char.code ch in
      if code <= 32 || code = 127 then pending_space := true
      else (
        flush_space ();
        Buffer.add_char buffer ch))
    text;
  let sanitized = Buffer.contents buffer |> Util.trim in
  let sanitized = if sanitized = "" then "no output" else sanitized in
  if String.length sanitized <= 240 then sanitized else String.sub sanitized 0 240 ^ "..."

let command_failure_gap command result =
  let output =
    [ result.stdout; result.stderr ]
    |> List.map Util.trim
    |> List.filter (fun text -> text <> "")
    |> String.concat "\n"
    |> sanitize_diagnostic
  in
  runtime_gap "tracker.minibeads.command"
    (Printf.sprintf
       "minibeads readiness command %S failed with %s: %s. Fix the command or local minibeads installation before dispatch."
       command (status_text result.status) output)

let store_exists root =
  try Sys.file_exists root && Sys.is_directory root with Sys_error _ -> false

let readiness_gaps ?(runner = default_runner) (config : Config.t) =
  let command = Util.trim config.tracker.minibeads_command in
  let gaps =
    match command_executable command with
    | None -> [ command_gap command ]
    | Some executable when not (runner.command_available executable) -> [ command_gap command ]
    | Some _ -> []
  in
  let gaps =
    if store_exists config.tracker.minibeads_root then gaps
    else gaps @ [ store_gap config.tracker ]
  in
  match gaps with
  | _ :: _ -> gaps
  | [] -> (
      match runner.run ~cwd:config.repository_root ~command with
      | result -> (
          match result.status with Exited 0 -> [] | _ -> [ command_failure_gap command result ])
      | exception exn ->
          [
            runtime_gap "tracker.minibeads.command"
              (Printf.sprintf
                 "minibeads readiness command %S failed before completion: %s. Fix the command or local minibeads installation before dispatch."
                 command (sanitize_diagnostic (Printexc.to_string exn)));
          ])
