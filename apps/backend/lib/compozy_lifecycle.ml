type lifecycle_state =
  | Pending
  | In_planning
  | In_execution
  | In_review
  | Blocked
  | Completed
  | Failed
  | Skipped
  | Pr_handoff
  | Not_pr_ready

type pr_readiness =
  | Disabled
  | Not_ready
  | Ready
  | Handoff_attempting
  | Handoff_completed
  | Handoff_failed

type t = {
  version : int;
  run_id : string;
  slug : string;
  lifecycle_state : lifecycle_state;
  dispatch_state : string;
  stage_agent : string option;
  pr_readiness : pr_readiness;
  reason : string option;
  updated_at : string;
}

let current_version = 1

let lifecycle_state_to_string = function
  | Pending -> "pending"
  | In_planning -> "in_planning"
  | In_execution -> "in_execution"
  | In_review -> "in_review"
  | Blocked -> "blocked"
  | Completed -> "completed"
  | Failed -> "failed"
  | Skipped -> "skipped"
  | Pr_handoff -> "pr_handoff"
  | Not_pr_ready -> "not_pr_ready"

let lifecycle_state_of_string value =
  match String.lowercase_ascii (Util.trim value) with
  | "pending" -> Ok Pending
  | "in_planning" -> Ok In_planning
  | "in_execution" -> Ok In_execution
  | "in_review" -> Ok In_review
  | "blocked" -> Ok Blocked
  | "completed" -> Ok Completed
  | "failed" -> Ok Failed
  | "skipped" -> Ok Skipped
  | "pr_handoff" -> Ok Pr_handoff
  | "not_pr_ready" -> Ok Not_pr_ready
  | other -> Error ("unknown Compozy lifecycle_state: " ^ other)

let pr_readiness_to_string = function
  | Disabled -> "disabled"
  | Not_ready -> "not_ready"
  | Ready -> "ready"
  | Handoff_attempting -> "handoff_attempting"
  | Handoff_completed -> "handoff_completed"
  | Handoff_failed -> "handoff_failed"

let pr_readiness_of_string value =
  match String.lowercase_ascii (Util.trim value) with
  | "disabled" -> Ok Disabled
  | "not_ready" -> Ok Not_ready
  | "ready" -> Ok Ready
  | "handoff_attempting" -> Ok Handoff_attempting
  | "handoff_completed" -> Ok Handoff_completed
  | "handoff_failed" -> Ok Handoff_failed
  | other -> Error ("unknown Compozy pr_readiness: " ^ other)

let ok_or_error f =
  try Ok (f ())
  with
  | Sys_error msg -> Error msg
  | Yojson.Json_error msg -> Error msg
  | Unix.Unix_error (error, fn, arg) -> Error (Printf.sprintf "%s(%s): %s" fn arg (Unix.error_message error))

let option_string_to_yojson = function Some value -> `String value | None -> `Null

let to_yojson lifecycle =
  `Assoc
    [
      ("version", `Int lifecycle.version);
      ("run_id", `String lifecycle.run_id);
      ("slug", `String lifecycle.slug);
      ("lifecycle_state", `String (lifecycle_state_to_string lifecycle.lifecycle_state));
      ("dispatch_state", `String lifecycle.dispatch_state);
      ("stage_agent", option_string_to_yojson lifecycle.stage_agent);
      ("pr_readiness", `String (pr_readiness_to_string lifecycle.pr_readiness));
      ("reason", option_string_to_yojson lifecycle.reason);
      ("updated_at", `String lifecycle.updated_at);
    ]

let json_member name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let required_string field json =
  match json_member field json with
  | Some (`String value) when Util.trim value <> "" -> Ok value
  | Some `Null -> Error (Printf.sprintf "missing required Compozy lifecycle field %s" field)
  | Some _ -> Error (Printf.sprintf "invalid Compozy lifecycle field %s: expected string" field)
  | None -> Error (Printf.sprintf "missing required Compozy lifecycle field %s" field)

let optional_string field json =
  match json_member field json with
  | Some (`String value) when Util.trim value <> "" -> Some value
  | _ -> None

let required_int field json =
  match json_member field json with
  | Some (`Int value) -> Ok value
  | Some _ -> Error (Printf.sprintf "invalid Compozy lifecycle field %s: expected integer" field)
  | None -> Error (Printf.sprintf "missing required Compozy lifecycle field %s" field)

let ( let* ) result f = match result with Ok value -> f value | Error _ as error -> error

let of_yojson json =
  match json with
  | `Assoc _ ->
      let* version = required_int "version" json in
      if version <> current_version then
        Error (Printf.sprintf "unsupported Compozy lifecycle version %d" version)
      else
        let* run_id = required_string "run_id" json in
        let* slug = required_string "slug" json in
        let* lifecycle_state_text = required_string "lifecycle_state" json in
        let* lifecycle_state = lifecycle_state_of_string lifecycle_state_text in
        let* dispatch_state = required_string "dispatch_state" json in
        let* pr_readiness_text = required_string "pr_readiness" json in
        let* pr_readiness = pr_readiness_of_string pr_readiness_text in
        let* updated_at = required_string "updated_at" json in
        Ok
          {
            version;
            run_id;
            slug;
            lifecycle_state;
            dispatch_state;
            stage_agent = optional_string "stage_agent" json;
            pr_readiness;
            reason = optional_string "reason" json;
            updated_at;
          }
  | _ -> Error "invalid Compozy lifecycle JSON: expected object"

let runtime_state_dir config =
  Filename.concat (Filename.concat config.Config.repository_root Runtime_home.runtime_dir_name) "state"

let lifecycle_dir config = Filename.concat (runtime_state_dir config) "compozy-lifecycle"

let path_for_run config (run : Compozy_tasks_tracker.prd_run) =
  Filename.concat (lifecycle_dir config) (run.slug ^ ".json")

let save config lifecycle =
  let dir = lifecycle_dir config in
  let path = Filename.concat dir (lifecycle.slug ^ ".json") in
  ok_or_error (fun () ->
      Util.mkdir_p dir;
      Util.write_file path (Yojson.Safe.pretty_to_string (to_yojson lifecycle) ^ "\n"))
  |> Result.map_error (fun msg -> Printf.sprintf "could not write Compozy lifecycle %s: %s" path msg)

let load config run =
  let path = path_for_run config run in
  if not (Sys.file_exists path) then Ok None
  else
    match ok_or_error (fun () -> Yojson.Safe.from_file path) with
    | Error msg -> Error (Printf.sprintf "could not read Compozy lifecycle %s: %s" path msg)
    | Ok json -> (
        match of_yojson json with
        | Ok lifecycle -> Ok (Some lifecycle)
        | Error error -> Error (Printf.sprintf "could not parse Compozy lifecycle %s: %s" path error))

let nonempty_opt value =
  match Option.map Util.trim value with Some value when value <> "" -> Some value | _ -> None

let failed_reason (run : Compozy_tasks_tracker.prd_run) =
  match List.find_opt (fun (step : Compozy_tasks_tracker.task_step) -> String.lowercase_ascii step.status = "failed") run.steps with
  | Some step -> Printf.sprintf "Compozy Task Step %s failed." step.file
  | None -> "A Compozy Task Step failed."

let skipped_reason (run : Compozy_tasks_tracker.prd_run) =
  match List.find_opt (fun (step : Compozy_tasks_tracker.task_step) -> String.lowercase_ascii step.status = "skipped") run.steps with
  | Some step -> Printf.sprintf "Compozy Task Step %s was skipped." step.file
  | None -> "A Compozy Task Step was skipped."

let not_runnable_reason (run : Compozy_tasks_tracker.prd_run) =
  match nonempty_opt run.not_runnable_reason with
  | Some reason -> reason
  | None -> "No runnable Compozy Task Step is available."

let completed_readiness config =
  if not config.Config.pull_request.enabled then
    (Disabled, Some "Pull Request Policy disables automatic Batch Pull Requests.")
  else if String.lowercase_ascii (Util.trim config.pull_request.mode) = "batch" then (Ready, None)
  else (Not_ready, Some "Pull Request Policy is not configured for Batch Pull Requests.")

let active_current_step = function
  | Some (step : Compozy_tasks_tracker.task_step) -> (
      match String.lowercase_ascii step.status with "pending" | "in_progress" -> true | _ -> false)
  | None -> false

let derive config (run : Compozy_tasks_tracker.prd_run) =
  let counts = run.counts in
  let lifecycle_state, pr_readiness, reason =
    if active_current_step run.current_step then (In_execution, Not_ready, None)
    else if counts.total > 0 && counts.total = counts.completed then
      let pr_readiness, reason = completed_readiness config in
      (Completed, pr_readiness, reason)
    else if counts.failed > 0 then (Failed, Not_ready, Some (failed_reason run))
    else if counts.skipped > 0 then (Skipped, Not_ready, Some (skipped_reason run))
    else if counts.total = 0 then (Blocked, Not_ready, Some (not_runnable_reason run))
    else (Not_pr_ready, Not_ready, Some (not_runnable_reason run))
  in
  {
    version = current_version;
    run_id = run.id;
    slug = run.slug;
    lifecycle_state;
    dispatch_state = run.state;
    stage_agent = None;
    pr_readiness;
    reason;
    updated_at = Util.now_iso8601 ();
  }

let backfill config run =
  let lifecycle = derive config run in
  match save config lifecycle with Ok () -> Ok lifecycle | Error _ as error -> error

let terminal_non_ready_from_steps config run =
  let derived = derive config run in
  match derived.lifecycle_state with Failed | Skipped | Blocked | Not_pr_ready -> Some derived | _ -> None

let terminal_metadata_matches derived lifecycle =
  lifecycle.lifecycle_state = derived.lifecycle_state && lifecycle.pr_readiness = derived.pr_readiness

let reconcile config run lifecycle =
  match terminal_non_ready_from_steps config run with
  | Some derived when not (terminal_metadata_matches derived lifecycle) ->
      let reconciled =
        {
          derived with
          stage_agent = lifecycle.stage_agent;
          updated_at = Util.now_iso8601 ();
        }
      in
      (match save config reconciled with Ok () -> Ok reconciled | Error _ as error -> error)
  | _ -> Ok lifecycle

let for_runtime config _state run =
  match load config run with
  | Error _ as error -> error
  | Ok None -> backfill config run
  | Ok (Some lifecycle) -> reconcile config run lifecycle

let load_or_backfill config run =
  match load config run with
  | Error _ as error -> error
  | Ok (Some lifecycle) -> Ok lifecycle
  | Ok None -> backfill config run

let lifecycle_for_stage ?stage_agent ~dispatch_state () =
  match Option.map (fun value -> String.lowercase_ascii (Util.trim value)) stage_agent with
  | Some "planner" -> In_planning
  | Some "reviewer" -> In_review
  | Some "engineer" -> In_execution
  | _ -> (
      match String.lowercase_ascii (Util.trim dispatch_state) with
      | "backlog" -> In_planning
      | "in review" | "in_review" -> In_review
      | _ -> In_execution)

let mark_stage_started config run ~stage_agent ~dispatch_state =
  let stage_agent = nonempty_opt stage_agent in
  match load_or_backfill config run with
  | Error _ as error -> error
  | Ok lifecycle ->
      let updated =
        {
          lifecycle with
          lifecycle_state = lifecycle_for_stage ?stage_agent ~dispatch_state ();
          dispatch_state;
          stage_agent;
          pr_readiness = Not_ready;
          reason = None;
          updated_at = Util.now_iso8601 ();
        }
      in
      (match save config updated with Ok () -> Ok updated | Error _ as error -> error)

let mark_not_pr_ready config run ~reason =
  match load_or_backfill config run with
  | Error _ as error -> error
  | Ok lifecycle ->
      let reason =
        match Util.trim reason with "" -> "Compozy PRD Run is not PR-ready." | reason -> reason
      in
      let updated =
        {
          lifecycle with
          lifecycle_state = Not_pr_ready;
          pr_readiness = Not_ready;
          reason = Some reason;
          updated_at = Util.now_iso8601 ();
        }
      in
      (match save config updated with Ok () -> Ok updated | Error _ as error -> error)

let contains_substring text substring =
  let text_len = String.length text in
  let substring_len = String.length substring in
  let rec loop index =
    if substring_len = 0 then true
    else if index + substring_len > text_len then false
    else if String.sub text index substring_len = substring then true
    else loop (index + 1)
  in
  loop 0

let pr_handoff_readiness status =
  let status = String.lowercase_ascii (Util.trim status) in
  if contains_substring status "fail" || contains_substring status "error" then Handoff_failed
  else if contains_substring status "complete" || contains_substring status "success" || contains_substring status "reused" then
    Handoff_completed
  else Handoff_attempting

let mark_pr_handoff config run ~status ~reason =
  match load_or_backfill config run with
  | Error _ as error -> error
  | Ok lifecycle ->
      let updated =
        {
          lifecycle with
          lifecycle_state = Pr_handoff;
          pr_readiness = pr_handoff_readiness status;
          reason = nonempty_opt reason;
          updated_at = Util.now_iso8601 ();
        }
      in
      (match save config updated with Ok () -> Ok updated | Error _ as error -> error)
