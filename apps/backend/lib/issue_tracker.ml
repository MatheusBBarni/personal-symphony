type poll_error = Rate_limited of string * int | Failed of string

type lookup_diagnostic =
  | Missing_issue
  | Missing_project_membership of int
  | Closed_issue

type lookup_result = {
  identifier : string;
  issue : Issue.t option;
  diagnostics : lookup_diagnostic list;
}

type t = {
  kind : string;
  fetch_candidates : unit -> (Issue.t list, poll_error) result;
  fetch_by_identifiers : string list -> (Issue.t option list, string) result;
  fetch_by_identifiers_detailed : string list -> (lookup_result list, string) result;
  update_status : Issue.t -> string -> (unit, string) result;
  readiness_gaps : unit -> Runtime_state.readiness_gap list;
  normalize_identifier : string -> (string, string) result;
  is_active : string -> bool;
  is_terminal : string -> bool;
}

let digits_only text =
  text <> ""
  && String.for_all
       (function
         | '0' .. '9' -> true
         | _ -> false)
       text

let github_issue_number identifier =
  let trimmed = Util.trim identifier in
  let body =
    match Util.drop_prefix ~prefix:"#" trimmed with
    | Some suffix -> suffix
    | None -> trimmed
  in
  if digits_only body then
    match int_of_string_opt body with
    | Some number when number > 0 -> Ok number
    | _ -> Error (Printf.sprintf "invalid GitHub issue identifier %S" identifier)
  else Error (Printf.sprintf "invalid GitHub issue identifier %S; expected an issue identifier like 20 or #20" identifier)

let github_identifier number = "#" ^ string_of_int number

let github_normalize_identifier raw = github_issue_number raw |> Result.map github_identifier

let github_issue_numbers identifiers =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | identifier :: rest -> (
        match github_issue_number identifier with
        | Error _ as error -> error
        | Ok number -> loop (number :: acc) rest)
  in
  loop [] identifiers

let runtime_gap_of_config_gap (gap : Config.readiness_gap) =
  { Runtime_state.requirement = gap.requirement; remediation = gap.remediation }

let github_poll_result f =
  try Ok (f ()) with
  | Github_tracker.Tracker_rate_limited (message, retry_after_ms) -> Error (Rate_limited (message, retry_after_ms))
  | Github_tracker.Tracker_error message -> Error (Failed message)
  | exn -> Error (Failed (Printexc.to_string exn))

let github_lookup_result ~(config : Config.tracker) identifier = function
  | None -> { identifier; issue = None; diagnostics = [ Missing_issue ] }
  | Some { Github_tracker.issue; project_status = None; closed } ->
      let diagnostics =
        Missing_project_membership config.project_number :: if closed then [ Closed_issue ] else []
      in
      { identifier; issue = Some issue; diagnostics }
  | Some { Github_tracker.issue; project_status = Some _; closed } ->
      let diagnostics = if closed then [ Closed_issue ] else [] in
      { identifier; issue = Some issue; diagnostics }

let github ?(fetch_candidates = Github_tracker.fetch_candidate_issues)
    ?(fetch_by_numbers = Github_tracker.fetch_project_issues_by_numbers)
    ?(update_status = Github_tracker.update_issue_status) ?(readiness_gaps = Github_tracker.remote_readiness_gaps)
    (config : Config.t) =
  let tracker = Github_tracker.make config.tracker in
  let fetch_candidates () = github_poll_result (fun () -> fetch_candidates tracker) in
  let fetch_by_identifiers_detailed identifiers =
    match github_issue_numbers identifiers with
    | Error _ as error -> error
    | Ok numbers -> (
        try
          let rows = fetch_by_numbers tracker numbers in
          Ok
            (List.map2
               (fun number _raw_identifier ->
                 let canonical = github_identifier number in
                 let row = List.assoc_opt number rows |> Option.join in
                 github_lookup_result ~config:config.tracker canonical row)
               numbers identifiers)
        with
        | Github_tracker.Tracker_error message -> Error message
        | Github_tracker.Tracker_rate_limited (message, _) -> Error message
        | exn -> Error (Printexc.to_string exn))
  in
  let fetch_by_identifiers identifiers =
    fetch_by_identifiers_detailed identifiers
    |> Result.map
         (List.map (fun result ->
              match result.diagnostics with
              | [] -> result.issue
              | [ Closed_issue ] -> result.issue
              | _ -> None))
  in
  {
    kind = "github";
    fetch_candidates;
    fetch_by_identifiers;
    fetch_by_identifiers_detailed;
    update_status = (fun issue status -> update_status tracker issue status);
    readiness_gaps = (fun () -> readiness_gaps config |> List.map runtime_gap_of_config_gap);
    normalize_identifier = github_normalize_identifier;
    is_active = (fun status -> Github_tracker.status_is_active ~active_states:config.tracker.active_states status);
    is_terminal = (fun status -> Github_tracker.status_is_terminal ~config:config.tracker status);
  }

let minibeads ?(runner = Minibeads_tracker.default_runner) (config : Config.t) =
  let normalize_one raw =
    let identifier = Util.trim raw |> String.lowercase_ascii in
    match Util.drop_prefix ~prefix:"mb-" identifier with
    | Some number when digits_only number -> (
        match int_of_string_opt number with
        | Some parsed when parsed > 0 -> Ok ("mb-" ^ string_of_int parsed)
        | _ -> Error (Printf.sprintf "invalid minibeads issue identifier %S" raw))
    | _ ->
        Error
          (Printf.sprintf
             "invalid minibeads issue identifier %S; expected an issue identifier like mb-20"
             raw)
  in
  let fetch_by_identifiers identifiers =
    let rec normalize acc = function
      | [] -> Ok (List.rev acc)
      | identifier :: rest -> (
          match normalize_one identifier with
          | Error _ as error -> error
          | Ok identifier -> normalize (identifier :: acc) rest)
    in
    match normalize [] identifiers with
    | Error _ as error -> error
    | Ok identifiers -> Minibeads_tracker.fetch_by_identifiers ~runner config identifiers
  in
  let fetch_by_identifiers_detailed identifiers =
    match fetch_by_identifiers identifiers with
    | Error _ as error -> error
    | Ok issues ->
        Ok
          (List.map2
             (fun raw issue ->
               let identifier =
                 match issue with
                 | Some issue -> issue.Issue.identifier
                 | None -> (
                     match normalize_one raw with
                     | Ok identifier -> identifier
                     | Error _ -> raw)
               in
               { identifier; issue; diagnostics = (if Option.is_none issue then [ Missing_issue ] else []) })
             identifiers issues)
  in
  {
    kind = "minibeads";
    fetch_candidates =
      (fun () ->
        match Minibeads_tracker.fetch_candidates ~runner config with
        | Ok _ as ok -> ok
        | Error message -> Error (Failed message));
    fetch_by_identifiers;
    fetch_by_identifiers_detailed;
    update_status = Minibeads_tracker.update_status ~runner config;
    readiness_gaps = (fun () -> Minibeads_tracker.readiness_gaps ~runner config);
    normalize_identifier =
      (fun raw ->
        let identifier = Util.trim raw |> String.lowercase_ascii in
        match Util.drop_prefix ~prefix:"mb-" identifier with
        | Some number when digits_only number -> (
            match int_of_string_opt number with
            | Some parsed when parsed > 0 -> Ok ("mb-" ^ string_of_int parsed)
            | _ -> Error (Printf.sprintf "invalid minibeads issue identifier %S" raw))
        | _ ->
            Error
              (Printf.sprintf
                 "invalid minibeads issue identifier %S; expected an issue identifier like mb-20"
                 raw));
    is_active = Minibeads_tracker.is_active_status config.tracker;
    is_terminal = Minibeads_tracker.is_terminal_status config.tracker;
  }

let compozy_identifier raw =
  let identifier = Util.trim raw in
  match Util.drop_prefix ~prefix:"compozy:" identifier with
  | Some slug when Util.trim slug <> "" && not (String.contains slug '/') -> Ok ("compozy:" ^ Util.trim slug)
  | _ ->
      Error
        (Printf.sprintf
           "invalid Compozy PRD-run identifier %S; expected an identifier like compozy:task-name"
           raw)

let string_equal_ci left right = String.lowercase_ascii left = String.lowercase_ascii right

let status_in values status = List.exists (string_equal_ci status) values

let compozy_status_is_active config status =
  status_in [ "pending"; "in_progress" ] status || status_in config.Config.tracker.active_states status

let compozy_status_is_terminal config status =
  status_in [ "completed"; "failed"; "skipped" ] status || status_in config.Config.tracker.terminal_states status

let compozy_status_selects_stage config status =
  config.Config.stage_agents.enabled
  && List.exists
       (fun (stage : Config.stage_agent) -> List.exists (string_equal_ci status) stage.states)
       config.stage_agents.stages

let compozy_run_is_candidate config (run : Compozy_tasks_tracker.prd_run) (lifecycle : Compozy_lifecycle.t) =
  Compozy_tasks_tracker.runnable_prd_run run
  || (Compozy_tasks_tracker.completed_prd_run run && compozy_status_selects_stage config lifecycle.dispatch_state)

let compozy_issue_of_prd_run run (lifecycle : Compozy_lifecycle.t) =
  let issue = Compozy_tasks_tracker.issue_of_prd_run run in
  { issue with Issue.state = lifecycle.dispatch_state }

let compozy_load_lifecycle config run =
  let lifecycle =
    match Compozy_lifecycle.load_or_backfill_reconciled config run with
    | Ok lifecycle -> Some lifecycle
    | Error _ -> (
        (* Lifecycle metadata is Runtime Home cache derived from Compozy Task Steps. If one
           JSON file is corrupt or partially written, repair that run from task files instead
           of failing every tracker poll. *)
        match Compozy_lifecycle.backfill config run with Ok lifecycle -> Some lifecycle | Error _ -> None)
  in
  Option.map (fun lifecycle -> (run, lifecycle)) lifecycle

let compozy_lookup_result runs raw =
  let identifier = match compozy_identifier raw with Ok identifier -> identifier | Error _ -> raw in
  match List.find_opt (fun ((run : Compozy_tasks_tracker.prd_run), _) -> run.id = identifier) runs with
  | Some (run, lifecycle) -> { identifier; issue = Some (compozy_issue_of_prd_run run lifecycle); diagnostics = [] }
  | None -> { identifier; issue = None; diagnostics = [ Missing_issue ] }

let compozy config =
  let fetch_runs () =
    match Compozy_tasks_tracker.discover_prd_runs ~compozy_root:config.Config.tracker.compozy_root with
    | Ok runs ->
        let rec load acc = function
          | [] -> Ok (List.rev acc)
          | run :: rest -> (
              match compozy_load_lifecycle config run with
              | Some run -> load (run :: acc) rest
              | None -> load acc rest)
        in
        load [] runs
    | Error message -> Error message
  in
  let fetch_candidates () =
    match fetch_runs () with
    | Error message -> Error (Failed message)
    | Ok runs ->
        Ok
          (runs
          |> List.filter (fun (run, lifecycle) -> compozy_run_is_candidate config run lifecycle)
          |> List.map (fun (run, lifecycle) -> compozy_issue_of_prd_run run lifecycle))
  in
  let fetch_by_identifiers_detailed identifiers =
    let rec normalize acc = function
      | [] -> Ok (List.rev acc)
      | identifier :: rest -> (
          match compozy_identifier identifier with
          | Error _ as error -> error
          | Ok identifier -> normalize (identifier :: acc) rest)
    in
    match normalize [] identifiers with
    | Error _ as error -> error
    | Ok identifiers -> (
        match fetch_runs () with
        | Error _ as error -> error
        | Ok runs -> Ok (List.map (compozy_lookup_result runs) identifiers))
  in
  let fetch_by_identifiers identifiers =
    fetch_by_identifiers_detailed identifiers
    |> Result.map
         (List.map (fun result ->
              match result.diagnostics with [] -> result.issue | _ -> None))
  in
  let update_status issue status =
    let raw_identifier =
      match Util.trim issue.Issue.identifier with "" -> issue.Issue.id | identifier -> identifier
    in
    match compozy_identifier raw_identifier with
    | Error _ as error -> error
    | Ok identifier -> (
        match fetch_runs () with
        | Error _ as error -> error
        | Ok runs -> (
            match List.find_opt (fun ((run : Compozy_tasks_tracker.prd_run), _) -> run.id = identifier) runs with
            | None -> Error (Printf.sprintf "Compozy PRD run not found for %s" identifier)
            | Some (run, _) ->
                Compozy_lifecycle.update_dispatch_state config run ~dispatch_state:status
                |> Result.map (fun _ -> ())))
  in
  {
    kind = "compozy_tasks";
    fetch_candidates;
    fetch_by_identifiers;
    fetch_by_identifiers_detailed;
    update_status;
    readiness_gaps =
      (fun () ->
        Compozy_tasks_tracker.readiness_gaps config
        |> List.map (fun (gap : Compozy_tasks_tracker.readiness_gap) ->
               { Runtime_state.requirement = gap.requirement; remediation = gap.remediation }));
    normalize_identifier = compozy_identifier;
    is_active = compozy_status_is_active config;
    is_terminal = compozy_status_is_terminal config;
  }

let make (config : Config.t) =
  match config.tracker.kind with
  | "github" -> github config
  | "minibeads" -> minibeads config
  | "compozy_tasks" -> compozy config
  | kind -> invalid_arg (Printf.sprintf "Issue tracker adapter is not implemented for tracker.kind=%S" kind)
