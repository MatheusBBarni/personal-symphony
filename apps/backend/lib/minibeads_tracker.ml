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
  let shell_command = Printf.sprintf "cd %s && %s 2>&1" (Util.shell_quote cwd) command in
  let channel = Unix.open_process_in shell_command in
  let stdout =
    let buffer = Buffer.create 256 in
    (try
       while true do
         Buffer.add_string buffer (input_line channel);
         Buffer.add_char buffer '\n'
       done
     with End_of_file -> ());
    Buffer.contents buffer
  in
  let status =
    match Unix.close_process_in channel with
    | Unix.WEXITED code -> Exited code
    | Unix.WSIGNALED signal -> Signaled signal
    | Unix.WSTOPPED signal -> Stopped signal
  in
  { status; stdout; stderr = "" }

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

let command_line command args =
  let args = List.map Util.shell_quote args |> String.concat " " in
  if args = "" then command else command ^ " " ^ args

let base_args config =
  [
    "--mb-beads-dir";
    config.Config.minibeads_root;
    "--mb-no-cmd-logging";
  ]

let json_command config subcommand args =
  command_line config.Config.minibeads_command (base_args config @ [ "--json"; subcommand ] @ args)

let update_command config identifier status =
  command_line config.Config.minibeads_command
    (base_args config @ [ "update"; identifier; "--status"; status ])

let readiness_command command = command_line command [ "--version" ]

let command_output result =
  [ result.stdout; result.stderr ]
  |> List.map Util.trim
  |> List.filter (fun text -> text <> "")
  |> String.concat "\n"
  |> sanitize_diagnostic

let command_failed operation command result =
  Printf.sprintf "minibeads %s command %S failed with %s: %s" operation command
    (status_text result.status) (command_output result)

let issue_diagnostic message = "minibeads issue output error: " ^ message

let json_member name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let json_string_member name json =
  match json_member name json with
  | Some (`String value) when Util.trim value <> "" -> Some value
  | _ -> None

let json_int_member name json =
  match json_member name json with
  | Some (`Int value) -> Some value
  | Some (`Intlit value) -> int_of_string_opt value
  | _ -> None

let json_list_member name json =
  match json_member name json with Some (`List values) -> values | _ -> []

let string_list_member name json =
  json_list_member name json
  |> List.filter_map (function `String value when Util.trim value <> "" -> Some value | _ -> None)

let supported_statuses = [ "open"; "in_progress"; "blocked"; "closed" ]

let contains_substring text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  if needle_len = 0 then true
  else if needle_len > text_len then false
  else
    let rec loop index =
      index + needle_len <= text_len
      && (String.sub text index needle_len = needle || loop (index + 1))
    in
    loop 0

let normalize_status_text text =
  let buffer = Buffer.create (String.length text) in
  String.iter
    (fun ch ->
      match ch with
      | 'A' .. 'Z' -> Buffer.add_char buffer (Char.lowercase_ascii ch)
      | 'a' .. 'z' | '0' .. '9' -> Buffer.add_char buffer ch
      | '-' | ' ' -> Buffer.add_char buffer '_'
      | '_' -> Buffer.add_char buffer ch
      | _ -> ())
    (Util.trim text);
  Buffer.contents buffer

let minibeads_status_of_runtime_status status =
  match normalize_status_text status with
  | "open" | "todo" | "to_do" | "backlog" -> Ok "open"
  | "in_progress" | "doing" -> Ok "in_progress"
  | "blocked" | "human_attention" | "merge_attention" -> Ok "blocked"
  | "closed" | "done" | "cancelled" | "canceled" | "duplicate" -> Ok "closed"
  | normalized when List.mem normalized supported_statuses -> Ok normalized
  | _ -> Error (Printf.sprintf "unsupported minibeads status %S" status)

let canonical_identifier identifier =
  let identifier = Util.trim identifier |> String.lowercase_ascii in
  match Util.drop_prefix ~prefix:"mb-" identifier with
  | Some number -> (
      match int_of_string_opt number with Some parsed when parsed > 0 -> Some ("mb-" ^ string_of_int parsed) | _ -> None)
  | None -> None

let dependency_type json =
  match json_string_member "type" json with
  | Some value -> Some value
  | None -> json_string_member "dep_type" json

let blocker_from_dependency json =
  match json_string_member "id" json with
  | None -> None
  | Some identifier -> (
      match dependency_type json with
      | Some dep_type when normalize_status_text dep_type <> "blocks" -> None
      | Some _ | None ->
          let canonical = canonical_identifier identifier |> Option.value ~default:(Util.trim identifier) in
          Some
            {
              Issue.id = Some canonical;
              identifier = Some canonical;
              state =
                (match json_string_member "state" json with
                | Some _ as state -> state
                | None -> json_string_member "status" json);
            })

let blockers_from_map json =
  match json_member "depends_on" json with
  | Some (`Assoc dependencies) ->
      dependencies
      |> List.filter_map (fun (identifier, value) ->
             let dep_type =
               match value with
               | `String dep_type -> dep_type
               | `Assoc _ as dep -> Option.value (dependency_type dep) ~default:"blocks"
               | _ -> "blocks"
             in
             if normalize_status_text dep_type = "blocks" then
               let canonical = canonical_identifier identifier |> Option.value ~default:(Util.trim identifier) in
               Some { Issue.id = Some canonical; identifier = Some canonical; state = None }
             else None)
  | _ -> []

let blockers_from_issue_json json =
  let from_arrays =
    [ "dependencies"; "blocked_by" ]
    |> List.concat_map (fun name -> json_list_member name json)
    |> List.filter_map blocker_from_dependency
  in
  from_arrays @ blockers_from_map json

let parse_issue_json json =
  match json with
  | `Assoc _ ->
      (match Option.bind (json_string_member "id" json) canonical_identifier with
      | None -> Error "missing or invalid minibeads id"
      | Some identifier -> (
          match json_string_member "title" json with
          | None -> Error (Printf.sprintf "%s is missing title" identifier)
          | Some title -> (
              match json_string_member "status" json with
              | None -> Error (Printf.sprintf "%s is missing status" identifier)
              | Some status ->
                  let status = normalize_status_text status in
                  Ok
                    {
                      (Issue.empty ~id:identifier ~identifier ~title ~state:status) with
                      description = json_string_member "description" json;
                      comments = [];
                      priority = json_int_member "priority" json;
                      labels = string_list_member "labels" json;
                      blocked_by = blockers_from_issue_json json;
                      created_at = json_string_member "created_at" json;
                      updated_at = json_string_member "updated_at" json;
                    })))
  | _ -> Error "issue entry is not an object"

let issue_json_values json =
  match json with
  | `List values -> Ok values
  | `Assoc _ -> (
      match json_member "issues" json with
      | Some (`List values) -> Ok values
      | Some (`Assoc _ as issue) -> Ok [ issue ]
      | Some _ -> Error "issues field is not a list"
      | None -> (
          match json_member "issue" json with
          | Some (`Assoc _ as issue) -> Ok [ issue ]
          | Some (`List values) -> Ok values
          | Some _ -> Error "issue field is not an object"
          | None -> Ok [ json ]))
  | _ -> Error "JSON root is not an issue object or issue list"

let duplicate_identifier issues =
  let sorted = List.sort String.compare (List.map (fun (issue : Issue.t) -> issue.identifier) issues) in
  let rec loop = function
    | first :: second :: _ when first = second -> Some first
    | _ :: rest -> loop rest
    | [] -> None
  in
  loop sorted

let parse_issues_output operation output =
  match Yojson.Safe.from_string output with
  | exception Yojson.Json_error message -> Error (issue_diagnostic (operation ^ " returned invalid JSON: " ^ message))
  | json -> (
      match issue_json_values json with
      | Error message -> Error (issue_diagnostic (operation ^ " returned malformed JSON: " ^ message))
      | Ok values -> (
          let rec parse acc = function
            | [] -> Ok (List.rev acc)
            | value :: rest -> (
                match parse_issue_json value with
                | Error message -> Error (issue_diagnostic message)
                | Ok issue -> parse (issue :: acc) rest)
          in
          match parse [] values with
          | Error _ as error -> error
          | Ok issues -> (
              match duplicate_identifier issues with
              | Some identifier ->
                  Error
                    (issue_diagnostic
                       (Printf.sprintf "duplicate minibeads issue identifier %s in %s output" identifier operation))
              | None -> Ok issues)))

let issue_map issues =
  List.map (fun (issue : Issue.t) -> (issue.identifier, issue)) issues

let find_issue identifier issues = List.assoc_opt identifier (issue_map issues)

let is_terminal_status config status =
  let status = normalize_status_text status in
  List.exists
    (fun terminal ->
      match minibeads_status_of_runtime_status terminal with
      | Ok mapped -> mapped = status
      | Error _ -> Config.string_equal_ci (normalize_status_text terminal) status)
    (config.Config.terminal_states @ [ "closed" ])

let is_active_status config status =
  let status = normalize_status_text status in
  List.exists
    (fun active ->
      match minibeads_status_of_runtime_status active with
      | Ok mapped -> mapped = status
      | Error _ -> Config.string_equal_ci (normalize_status_text active) status)
    config.Config.active_states

let blocking_dependency config (blocker : Issue.blocker) =
  match blocker.state with
  | Some state -> not (is_terminal_status config state)
  | None -> true

let dispatchable_issue config issue =
  List.mem issue.Issue.state supported_statuses
  && is_active_status config issue.Issue.state
  && not (List.exists (blocking_dependency config) issue.blocked_by)

let fetch_issues ?(operation = "list") runner (config : Config.t) subcommand args =
  let command = json_command config.tracker subcommand args in
  match runner.run ~cwd:config.repository_root ~command with
  | result -> (
      match result.status with
      | Exited 0 -> parse_issues_output operation result.stdout
      | _ -> Error (command_failed operation command result))
  | exception exn ->
      Error
        (Printf.sprintf "minibeads %s command failed before completion: %s" operation
           (sanitize_diagnostic (Printexc.to_string exn)))

let fetch_issue runner (config : Config.t) identifier =
  match fetch_issues ~operation:"show" runner config "show" [ identifier ] with
  | Error _ as error -> error
  | Ok issues -> (
      match find_issue identifier issues with
      | Some issue -> Ok (Some issue)
      | None -> Ok None)

let populate_blockers runner (config : Config.t) issues =
  let known = issue_map issues in
  let blocker_state identifier =
    match List.assoc_opt identifier known with
    | Some issue -> Ok (Some issue.Issue.state)
    | None -> (
        match fetch_issue runner config identifier with
        | Error _ as error -> error
        | Ok (Some issue) -> Ok (Some issue.state)
        | Ok None -> Ok None)
  in
  let update_blocker (blocker : Issue.blocker) =
    match (blocker.Issue.identifier, blocker.state) with
    | Some identifier, None -> (
        match blocker_state identifier with
        | Error _ as error -> error
        | Ok state -> Ok { blocker with state })
    | _ -> Ok blocker
  in
  let rec update_blockers acc = function
    | [] -> Ok (List.rev acc)
    | blocker :: rest -> (
        match update_blocker blocker with Error _ as error -> error | Ok blocker -> update_blockers (blocker :: acc) rest)
  in
  let rec update_issues acc = function
    | [] -> Ok (List.rev acc)
    | issue :: rest -> (
        match update_blockers [] issue.Issue.blocked_by with
        | Error _ as error -> error
        | Ok blocked_by -> update_issues ({ issue with blocked_by } :: acc) rest)
  in
  update_issues [] issues

let fetch_candidates ?(runner = default_runner) (config : Config.t) =
  match fetch_issues runner config "list" [] with
  | Error _ as error -> error
  | Ok issues -> (
      match populate_blockers runner config issues with
      | Error _ as error -> error
      | Ok issues -> Ok (List.filter (dispatchable_issue config.tracker) issues))

let fetch_by_identifiers ?(runner = default_runner) (config : Config.t) identifiers =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | identifier :: rest -> (
        match fetch_issue runner config identifier with
        | Error _ as error -> error
        | Ok None -> loop (None :: acc) rest
        | Ok (Some issue) -> (
            match populate_blockers runner config [ issue ] with
            | Error _ as error -> error
            | Ok [ issue ] -> loop (Some issue :: acc) rest
            | Ok _ -> Error "minibeads lookup returned an unexpected issue count"))
  in
  loop [] identifiers

let update_status ?(runner = default_runner) (config : Config.t) (issue : Issue.t) status =
  match minibeads_status_of_runtime_status status with
  | Error _ as error -> error
  | Ok target_status ->
      let current_status = normalize_status_text issue.state in
      if current_status = target_status then Ok ()
      else
        let command = update_command config.tracker issue.identifier target_status in
        match runner.run ~cwd:config.repository_root ~command with
        | { status = Exited 0; _ } -> Ok ()
        | result ->
            let output = command_output result |> String.lowercase_ascii in
            if contains_substring output "already" || contains_substring output "no change" then
              Ok ()
            else Error (command_failed "status update" command result)
        | exception exn ->
            Error
              (Printf.sprintf "minibeads status update command failed before completion: %s"
                 (sanitize_diagnostic (Printexc.to_string exn)))

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
      let command = readiness_command command in
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
