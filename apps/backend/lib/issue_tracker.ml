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

let make (config : Config.t) =
  match config.tracker.kind with
  | "github" -> github config
  | kind -> invalid_arg (Printf.sprintf "Issue tracker adapter is not implemented for tracker.kind=%S" kind)
