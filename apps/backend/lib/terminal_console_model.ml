type safe_aid = Refresh_view | Show_web_handoff | Show_path of string

type goal_usage = {
  status : string option;
  time_used_seconds : float option;
  tokens_used : int option;
  text : string option;
}

type context_status = {
  state : string;
  summary : string;
  diagnostics_path : string option;
  text : string;
}

type goal_loop = {
  goal : string;
  state : string;
  stage_agent : string option;
  harness_name : string option;
  harness_kind : string option;
  attempt_count : int;
  budget : string option;
  latest_evidence : string option;
  stop_outcome : string option;
  stop_reason : string option;
  next_action : string option;
  diagnostics_path : string option;
  updated_at : string;
  text : string;
}

type task_row = {
  id : string;
  title : string;
  state : string;
  detail : string option;
  error : string option;
  goal_usage : goal_usage option;
  goal_loop : goal_loop option;
  context_status : context_status option;
}

type readiness_row = { requirement : string; remediation : string }

type compozy_progress = {
  run_id : string;
  slug : string;
  current_step : string option;
  next_step : string option;
  completed : int;
  failed : int;
  skipped : int;
  total : int;
  summary : string;
}

type t = {
  generated_at : string;
  mode : string;
  summary : string list;
  active : task_row list;
  readiness : readiness_row list;
  queue : task_row list;
  compozy : compozy_progress option;
  compozy_progresses : compozy_progress list;
  safe_aids : safe_aid list;
  last_error : string option;
}

let is_csi_final c =
  let code = Char.code c in
  code >= 0x40 && code <= 0x7e

let strip_terminal_sequences text =
  let len = String.length text in
  let buffer = Buffer.create len in
  let rec skip_csi index =
    if index >= len then len else if is_csi_final text.[index] then index + 1 else skip_csi (index + 1)
  in
  let rec skip_osc index =
    if index >= len then len
    else
      match text.[index] with
      | '\007' -> index + 1
      | '\027' when index + 1 < len && text.[index + 1] = '\\' -> index + 2
      | _ -> skip_osc (index + 1)
  in
  let rec loop index =
    if index < len then
      match text.[index] with
      | '\027' when index + 1 < len && text.[index + 1] = '[' -> loop (skip_csi (index + 2))
      | '\027' when index + 1 < len && text.[index + 1] = ']' -> loop (skip_osc (index + 2))
      | '\027' -> loop (min len (index + 2))
      | '\n' | '\r' | '\t' ->
          Buffer.add_char buffer ' ';
          loop (index + 1)
      | c when Char.code c < 0x20 || Char.code c = 0x7f -> loop (index + 1)
      | c ->
          Buffer.add_char buffer c;
          loop (index + 1)
  in
  loop 0;
  Buffer.contents buffer

let starts_with text index prefix =
  let prefix_len = String.length prefix in
  index + prefix_len <= String.length text && String.sub text index prefix_len = prefix

let secret_value_boundary = function ' ' | '\n' | '\r' | '\t' | ';' -> true | _ -> false

let redact_secret_assignments text =
  let secret_names = [ "GITHUB_TOKEN"; "GH_TOKEN" ] in
  let len = String.length text in
  let buffer = Buffer.create len in
  let secret_at index =
    match List.find_opt (fun name -> starts_with text index name) secret_names with
    | Some name ->
        let next = index + String.length name in
        if next < len && text.[next] = '=' then Some (name, next) else None
    | None -> None
  in
  let rec skip_value index =
    if index >= len then index else if secret_value_boundary text.[index] then index else skip_value (index + 1)
  in
  let rec loop index =
    if index < len then
      match secret_at index with
      | Some (name, eq_index) ->
          Buffer.add_string buffer name;
          Buffer.add_string buffer "=[redacted]";
          loop (skip_value (eq_index + 1))
      | None ->
          Buffer.add_char buffer text.[index];
          loop (index + 1)
  in
  loop 0;
  Buffer.contents buffer

let sanitize text = text |> strip_terminal_sequences |> redact_secret_assignments |> Util.trim

let sanitize_option = function
  | None -> None
  | Some text ->
      let sanitized = sanitize text in
      if sanitized = "" then None else Some sanitized

let goal_usage_text (usage : Runtime_state.goal_usage) =
  let parts =
    []
    |> (fun parts ->
         match sanitize_option usage.status with Some status -> ("status " ^ status) :: parts | None -> parts)
    |> (fun parts ->
         match usage.time_used_seconds with
         | Some seconds -> Printf.sprintf "time %.0fs" seconds :: parts
         | None -> parts)
    |> fun parts ->
    match usage.tokens_used with Some tokens -> Printf.sprintf "tokens %d" tokens :: parts | None -> parts
  in
  match List.rev parts with [] -> None | parts -> Some (String.concat " | " parts)

let goal_usage (usage : Runtime_state.goal_usage option) =
  Option.map
    (fun (usage : Runtime_state.goal_usage) ->
      {
        status = sanitize_option usage.status;
        time_used_seconds = usage.time_used_seconds;
        tokens_used = usage.tokens_used;
        text = goal_usage_text usage;
      })
    usage

let context_status (status : Runtime_state.context_status) =
  let state = sanitize status.state in
  let summary = sanitize status.summary in
  let text = if summary = "" then state else state ^ ": " ^ summary in
  { state; summary; diagnostics_path = sanitize_option status.diagnostics_path; text }

let maybe_context_status state issue_id =
  Option.map context_status (List.assoc_opt issue_id state.Runtime_state.context_statuses)

let issue_title state issue_id fallback =
  match List.find_opt (fun (issue : Issue.t) -> issue.id = issue_id) state.Runtime_state.issues with
  | Some issue -> issue.title
  | None -> fallback

let issue_branch state issue_id =
  match List.find_opt (fun (issue : Issue.t) -> issue.id = issue_id) state.Runtime_state.issues with
  | Some issue -> sanitize_option issue.branch_name
  | None -> None

let append_option label value parts =
  match sanitize_option value with Some value -> (label ^ value) :: parts | None -> parts

let detail_text parts =
  match List.rev (List.filter (fun value -> value <> "") parts) with [] -> None | parts -> Some (String.concat " | " parts)

let goal_loop_budget_text (budget : Runtime_state.goal_loop_budget) =
  let parts =
    []
    |> (fun parts ->
         match budget.max_turns with Some turns -> Printf.sprintf "maxTurns %d" turns :: parts | None -> parts)
    |> (fun parts ->
         match budget.max_runtime_ms with
         | Some runtime -> Printf.sprintf "maxRuntimeMs %d" runtime :: parts
         | None -> parts)
    |> fun parts ->
    match budget.max_tokens with Some tokens -> Printf.sprintf "maxTokens %d" tokens :: parts | None -> parts
  in
  match List.rev parts with [] -> None | parts -> Some (String.concat " | " parts)

let project_goal_loop (loop : Runtime_state.goal_loop) =
  let goal = sanitize loop.goal in
  let state = sanitize loop.state in
  let stage_agent = sanitize_option loop.stage_agent in
  let harness_name = sanitize_option loop.harness_name in
  let harness_kind = sanitize_option loop.harness_kind in
  let latest_evidence = sanitize_option loop.latest_evidence in
  let stop_outcome = sanitize_option loop.stop_outcome in
  let stop_reason = sanitize_option loop.stop_reason in
  let next_action = sanitize_option loop.next_action in
  let diagnostics_path = sanitize_option loop.diagnostics_path in
  let updated_at = sanitize loop.updated_at in
  let budget = goal_loop_budget_text loop.budget in
  let text =
    [
      Some ("state " ^ state);
      Some (Printf.sprintf "attempt %d" loop.attempt_count);
      Option.map (fun outcome -> "outcome " ^ outcome) stop_outcome;
      Option.map (fun evidence -> "evidence " ^ evidence) latest_evidence;
      Option.map (fun action -> "next action " ^ action) next_action;
    ]
    |> List.filter_map Fun.id |> String.concat " | "
  in
  {
    goal;
    state;
    stage_agent;
    harness_name;
    harness_kind;
    attempt_count = loop.attempt_count;
    budget;
    latest_evidence;
    stop_outcome;
    stop_reason;
    next_action;
    diagnostics_path;
    updated_at;
    text;
  }

let maybe_goal_loop state issue_id =
  Option.map project_goal_loop (Runtime_state.goal_loop_for_issue state issue_id)

let running_row state (row : Runtime_state.running) =
  let context = Runtime_state.context_status_for_issue state row.issue.id |> context_status in
  let detail =
    []
    |> append_option "issue state " (Some row.issue.state)
    |> append_option "stage agent " row.stage_agent
    |> append_option "harness " row.harness_name
    |> append_option "harness kind " row.harness_kind
    |> append_option "branch " row.issue.branch_name
    |> append_option "last event " row.last_event
    |> append_option "last message " row.last_message
    |> fun parts ->
    if row.stage_states = [] then parts
    else ("stage states " ^ (row.stage_states |> List.map sanitize |> String.concat ", ")) :: parts
  in
  {
    id = sanitize row.issue.identifier;
    title = sanitize row.issue.title;
    state = "running";
    detail = detail_text detail;
    error = None;
    goal_usage = goal_usage row.goal_usage;
    goal_loop = maybe_goal_loop state row.issue.id;
    context_status = Some context;
  }

let retrying_row state (row : Runtime_state.retrying) =
  let title = issue_title state row.issue_id row.issue_identifier in
  let branch = issue_branch state row.issue_id in
  let detail =
    [ Printf.sprintf "attempt %d" row.attempt; "due " ^ sanitize row.due_at ]
    |> append_option "branch " branch
  in
  {
    id = sanitize row.issue_identifier;
    title = sanitize title;
    state = "retrying";
    detail = detail_text detail;
    error = sanitize_option row.error;
    goal_usage = goal_usage row.goal_usage;
    goal_loop = maybe_goal_loop state row.issue_id;
    context_status = Some (Runtime_state.context_status_for_issue state row.issue_id |> context_status);
  }

let attention_row state (row : Runtime_state.issue_error) =
  {
    id = sanitize row.issue_identifier;
    title = sanitize (issue_title state row.issue_id row.issue_identifier);
    state = "attention";
    detail = Some "Task Needs Attention";
    error = Some (sanitize row.error);
    goal_usage = goal_usage row.goal_usage;
    goal_loop = maybe_goal_loop state row.issue_id;
    context_status = maybe_context_status state row.issue_id;
  }

let goal_loop_needs_attention_state state =
  match String.lowercase_ascii state with "needs_attention" | "budget_exhausted" -> true | _ -> false

let goal_loop_row state (loop : Runtime_state.goal_loop) =
  let projected = project_goal_loop loop in
  let detail =
    []
    |> append_option "goal " (Some projected.goal)
    |> append_option "updated " (Some projected.updated_at)
  in
  {
    id = sanitize loop.issue_identifier;
    title = sanitize (issue_title state loop.issue_id loop.goal);
    state = projected.state;
    detail = detail_text detail;
    error = if goal_loop_needs_attention_state projected.state then projected.stop_reason else None;
    goal_usage = None;
    goal_loop = Some projected;
    context_status = maybe_context_status state loop.issue_id;
  }

let readiness_row (gap : Runtime_state.readiness_gap) =
  { requirement = sanitize gap.requirement; remediation = sanitize gap.remediation }

let queue_row (entry : Runtime_state.ordered_queue_entry) =
  let reason = sanitize_option entry.skip_reason in
  let detail =
    match (String.lowercase_ascii entry.state, reason) with
    | _, None -> None
    | "failed", Some reason -> Some ("failure reason " ^ reason)
    | "attention", Some reason -> Some ("attention reason " ^ reason)
    | "skipped", Some reason -> Some ("skip reason " ^ reason)
    | _, Some reason -> Some ("reason " ^ reason)
  in
  {
    id = sanitize entry.issue_identifier;
    title = sanitize (Option.value entry.title ~default:entry.issue_identifier);
    state = sanitize entry.state;
    detail;
    error = reason;
    goal_usage = None;
    goal_loop = None;
    context_status = None;
  }

let compozy_progress (progress : Runtime_state.compozy_progress) =
  let current_step = sanitize_option progress.current_step in
  let step = Option.value current_step ~default:"No active step" in
  let slug = sanitize progress.slug in
  {
    run_id = sanitize progress.run_id;
    slug;
    current_step;
    next_step = sanitize_option progress.next_step;
    completed = progress.completed;
    failed = progress.failed;
    skipped = progress.skipped;
    total = progress.total;
    summary =
      let next = match sanitize_option progress.next_step with Some next -> " -> " ^ next | None -> "" in
      Printf.sprintf "%s: %s%s (%d completed, %d failed, %d skipped, %d total)" slug step next
        progress.completed progress.failed progress.skipped progress.total;
  }

let first_pending_queue_entry state =
  match state.Runtime_state.ordered_queue with
  | None -> None
  | Some queue ->
      List.find_opt
        (fun (entry : Runtime_state.ordered_queue_entry) -> String.lowercase_ascii entry.state = "pending")
        queue.entries

let queue_has_pending state = Option.is_some (first_pending_queue_entry state)

let queue_has_attention state =
  match state.Runtime_state.ordered_queue with
  | None -> false
  | Some queue ->
      List.exists
        (fun (entry : Runtime_state.ordered_queue_entry) ->
          match String.lowercase_ascii entry.state with "attention" | "failed" -> true | _ -> false)
        queue.entries

let goal_loops_have_attention state =
  List.exists
    (fun (loop : Runtime_state.goal_loop) -> goal_loop_needs_attention_state loop.state)
    state.Runtime_state.goal_loops

let goal_loops_have_state expected state =
  List.exists
    (fun (loop : Runtime_state.goal_loop) -> String.lowercase_ascii loop.state = expected)
    state.Runtime_state.goal_loops

let display_mode state =
  if state.Runtime_state.issue_errors <> [] || goal_loops_have_attention state then "attention"
  else if queue_has_attention state then "attention"
  else if state.retrying <> [] then "retrying"
  else if goal_loops_have_state "retrying" state then "retrying"
  else if state.running <> [] then "running"
  else if goal_loops_have_state "running" state then "running"
  else if state.readiness_gaps <> [] then "readiness_blocked"
  else if queue_has_pending state then "ready"
  else "idle"

let summary state mode (compozy : compozy_progress option) =
  let lines =
    [
      "Mode: " ^ mode;
      "Tracker: " ^ sanitize state.Runtime_state.tracker_kind;
      Printf.sprintf "Running: %d" (List.length state.running);
      Printf.sprintf "Retrying: %d" (List.length state.retrying);
      Printf.sprintf "Total tokens: %d" state.usage_totals.total_tokens;
    ]
  in
  let lines =
    match sanitize_option state.workspace_repository_name with
    | Some name -> ("Workspace Repository: " ^ name) :: lines
    | None -> lines
  in
  let lines =
    if state.readiness_gaps = [] then lines
    else lines @ [ Printf.sprintf "Readiness Gaps: %d" (List.length state.readiness_gaps) ]
  in
  let lines =
    match first_pending_queue_entry state with
    | Some entry ->
        let title = sanitize (Option.value entry.title ~default:"") in
        let line =
          if title = "" then "Next work: " ^ sanitize entry.issue_identifier
          else Printf.sprintf "Next work: %s %s" (sanitize entry.issue_identifier) title
        in
        lines @ [ line ]
    | None -> lines
  in
  let lines = match compozy with Some progress -> lines @ [ "Compozy PRD Run: " ^ progress.summary ] | None -> lines in
  match sanitize_option state.last_error with Some error -> lines @ [ "Last error: " ^ error ] | None -> lines

let add_unique value values = if List.exists (String.equal value) values then values else value :: values

let safe_path_aids state =
  let add_path path paths =
    match sanitize_option path with Some path -> add_unique path paths | None -> paths
  in
  let paths =
    List.fold_left
      (fun paths (_issue_id, (status : Runtime_state.context_status)) -> add_path status.diagnostics_path paths)
      [] state.Runtime_state.context_statuses
  in
  let paths =
    List.fold_left
      (fun paths (diagnostic : Runtime_state.context_diagnostic) ->
        add_path (Some diagnostic.diagnostic_path) paths)
      paths state.context_diagnostics
  in
  let paths =
    List.fold_left
      (fun paths (loop : Runtime_state.goal_loop) -> add_path loop.diagnostics_path paths)
      paths state.goal_loops
  in
  let paths =
    List.fold_left
      (fun paths (row : Runtime_state.startup_reconciliation) -> add_path row.workspace_path paths)
      paths state.startup_reconciliation
  in
  let paths =
    List.fold_left
      (fun paths (row : Runtime_state.task_branch_integration) -> add_path row.workspace_path paths)
      paths state.task_branch_integrations
  in
  paths |> List.rev |> List.map (fun path -> Show_path path)

let safe_aids state = [ Refresh_view; Show_web_handoff ] @ safe_path_aids state

let of_runtime_state state =
  let mode = display_mode state in
  let matched_goal_loop_issue_ids =
    List.map (fun (row : Runtime_state.running) -> row.issue.id) state.Runtime_state.running
    @ List.map (fun (row : Runtime_state.retrying) -> row.issue_id) state.retrying
    @ List.map (fun (row : Runtime_state.issue_error) -> row.issue_id) state.issue_errors
  in
  let unmatched_goal_loop_rows =
    state.Runtime_state.goal_loops
    |> List.filter (fun (loop : Runtime_state.goal_loop) ->
           not (List.exists (String.equal loop.issue_id) matched_goal_loop_issue_ids))
    |> List.map (goal_loop_row state)
  in
  let active =
    List.map (running_row state) state.Runtime_state.running
    @ List.map (retrying_row state) state.retrying
    @ List.map (attention_row state) state.issue_errors
    @ unmatched_goal_loop_rows
  in
  let readiness = List.map readiness_row state.readiness_gaps in
  let queue =
    match state.ordered_queue with Some queue -> List.map queue_row queue.entries | None -> []
  in
  let compozy = Option.map compozy_progress state.compozy_progress in
  let compozy_progresses =
    match List.map compozy_progress state.compozy_progresses with
    | [] -> Option.to_list compozy
    | progresses -> progresses
  in
  {
    generated_at = Util.now_iso8601 ();
    mode;
    summary = summary state mode compozy;
    active;
    readiness;
    queue;
    compozy;
    compozy_progresses;
    safe_aids = safe_aids state;
    last_error = sanitize_option state.last_error;
  }
