type tokens = { input_tokens : int; output_tokens : int; total_tokens : int }
type goal_usage = { status : string option; time_used_seconds : float option; tokens_used : int option }
type context_status = { state : string; summary : string; diagnostics_path : string option }

type running = {
  issue : Issue.t;
  stage_agent : string option;
  harness_name : string option;
  harness_kind : string option;
  stage_states : string list;
  session_id : string option;
  turn_count : int;
  last_event : string option;
  last_message : string option;
  started_at : string;
  last_event_at : string option;
  tokens : tokens;
  goal_usage : goal_usage option;
}

type retrying = {
  issue_id : string;
  issue_identifier : string;
  attempt : int;
  due_at : string;
  error : string option;
  goal_usage : goal_usage option;
}
type issue_error = { issue_id : string; issue_identifier : string; error : string; goal_usage : goal_usage option }
type readiness_gap = { requirement : string; remediation : string }
type ordered_queue_entry = {
  issue_identifier : string;
  title : string option;
  state : string;
  skip_reason : string option;
}
type ordered_queue = { entries : ordered_queue_entry list }
type compozy_progress = {
  run_id : string;
  slug : string;
  current_step : string option;
  completed : int;
  failed : int;
  skipped : int;
  total : int;
}
type startup_reconciliation = {
  issue_id : string option;
  issue_identifier : string option;
  task_branch : string option;
  workspace_path : string option;
  category : string;
  message : string;
}
type task_branch_integration = {
  issue_id : string;
  issue_identifier : string;
  task_branch : string;
  workspace_path : string option;
  result : string;
  direct_fast_forward : bool;
  task_branch_updated_from_loop_start : bool;
  attention : string option;
  message : string;
}
type pull_request_handoff = {
  enabled : bool;
  mode : string;
  issue_identifier : string option;
  head_branch : string option;
  base_branch : string option;
  status : string;
  url : string option;
  error : string option;
}

type context_diagnostic = {
  issue_id : string;
  issue_identifier : string;
  stage_agent : string option;
  diagnostic_id : string;
  diagnostic_path : string;
  command_name : string option;
  cwd_kind : string option;
  timed_out : bool option;
  exit_code : int option;
  stdout_bytes : int option;
  stderr_bytes : int option;
  stdout_truncated : bool option;
}

type t = {
  workspace_repository_name : string option;
  tracker_kind : string;
  issues : Issue.t list;
  running : running list;
  retrying : retrying list;
  issue_errors : issue_error list;
  status_order : string list;
  readiness_gaps : readiness_gap list;
  context_statuses : (string * context_status) list;
  usage_totals : tokens;
  seconds_running : float;
  rate_limits : Yojson.Safe.t option;
  pull_request : pull_request_handoff option;
  pull_requests : pull_request_handoff list;
  ordered_queue : ordered_queue option;
  compozy_progress : compozy_progress option;
  startup_reconciliation : startup_reconciliation list;
  task_branch_integrations : task_branch_integration list;
  context_diagnostics : context_diagnostic list;
  last_error : string option;
}

let empty ?workspace_repository_name ?(tracker_kind = "github") ?(readiness_gaps = []) ?(status_order = []) ?ordered_queue
    ?compozy_progress ?last_error () =
  {
    workspace_repository_name;
    tracker_kind;
    running = [];
    issues = [];
    retrying = [];
    issue_errors = [];
    status_order;
    readiness_gaps;
    context_statuses = [];
    usage_totals = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
    seconds_running = 0.;
    rate_limits = None;
    pull_request = None;
    pull_requests = [];
    ordered_queue;
    compozy_progress;
    startup_reconciliation = [];
    task_branch_integrations = [];
    context_diagnostics = [];
    last_error;
  }

let tokens_to_yojson tokens =
  `Assoc
    [
      ("input_tokens", `Int tokens.input_tokens);
      ("output_tokens", `Int tokens.output_tokens);
      ("total_tokens", `Int tokens.total_tokens);
    ]

let goal_usage_to_yojson (usage : goal_usage) =
  `Assoc
    [
      ("status", (match usage.status with Some value -> `String value | None -> `Null));
      ("time_used_seconds", (match usage.time_used_seconds with Some value -> `Float value | None -> `Null));
      ("tokens_used", (match usage.tokens_used with Some value -> `Int value | None -> `Null));
    ]

let make_context_status ?diagnostics_path ~state ~summary () = { state; summary; diagnostics_path }

let skipped_context_status =
  make_context_status ~state:"skipped" ~summary:"Context behavior disabled or not applicable." ()

let set_context_status issue_id context_status state =
  {
    state with
    context_statuses =
      (issue_id, context_status) :: List.filter (fun (existing_issue_id, _) -> existing_issue_id <> issue_id) state.context_statuses;
  }

let clear_context_status issue_id state =
  { state with context_statuses = List.filter (fun (existing_issue_id, _) -> existing_issue_id <> issue_id) state.context_statuses }

let context_status_for_issue state issue_id =
  match List.assoc_opt issue_id state.context_statuses with Some context_status -> context_status | None -> skipped_context_status

let context_status_to_yojson (status : context_status) =
  `Assoc
    [
      ("state", `String status.state);
      ("summary", `String status.summary);
      ("diagnostics_path", (match status.diagnostics_path with Some path -> `String path | None -> `Null));
    ]

let issue_to_yojson issue =
  `Assoc
    [
      ("issue_id", `String issue.Issue.id);
      ("issue_identifier", `String issue.identifier);
      ("title", `String issue.title);
      ("description", (match issue.description with Some s -> `String s | None -> `Null));
      ("comments", `List (List.map Issue.comment_to_yojson issue.comments));
      ("url", (match issue.url with Some s -> `String s | None -> `Null));
      ("state", `String issue.state);
      ("created_at", (match issue.created_at with Some s -> `String s | None -> `Null));
      ("updated_at", (match issue.updated_at with Some s -> `String s | None -> `Null));
    ]

let running_to_yojson state row =
  `Assoc
    [
      ("issue_id", `String row.issue.id);
      ("issue_identifier", `String row.issue.identifier);
      ("title", `String row.issue.title);
      ("description", (match row.issue.description with Some s -> `String s | None -> `Null));
      ("comments", `List (List.map Issue.comment_to_yojson row.issue.comments));
      ("url", (match row.issue.url with Some s -> `String s | None -> `Null));
      ("state", `String row.issue.state);
      ("stage_agent", (match row.stage_agent with Some s -> `String s | None -> `Null));
      ("harness_name", (match row.harness_name with Some s -> `String s | None -> `Null));
      ("harness_kind", (match row.harness_kind with Some s -> `String s | None -> `Null));
      ("stage_states", `List (List.map (fun state -> `String state) row.stage_states));
      ("session_id", (match row.session_id with Some s -> `String s | None -> `Null));
      ("turn_count", `Int row.turn_count);
      ("last_event", (match row.last_event with Some s -> `String s | None -> `Null));
      ("last_message", (match row.last_message with Some s -> `String s | None -> `Null));
      ("started_at", `String row.started_at);
      ("last_event_at", (match row.last_event_at with Some s -> `String s | None -> `Null));
      ("tokens", tokens_to_yojson row.tokens);
      ("goal_usage", (match row.goal_usage with Some usage -> goal_usage_to_yojson usage | None -> `Null));
      ("context_status", context_status_for_issue state row.issue.id |> context_status_to_yojson);
    ]

let retrying_to_yojson state (row : retrying) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("attempt", `Int row.attempt);
      ("due_at", `String row.due_at);
      ("error", (match row.error with Some s -> `String s | None -> `Null));
      ("goal_usage", (match row.goal_usage with Some usage -> goal_usage_to_yojson usage | None -> `Null));
      ("context_status", context_status_for_issue state row.issue_id |> context_status_to_yojson);
    ]

let issue_error_to_yojson (row : issue_error) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("error", `String row.error);
      ("goal_usage", (match row.goal_usage with Some usage -> goal_usage_to_yojson usage | None -> `Null));
    ]

let readiness_gap_to_yojson row =
  `Assoc [ ("requirement", `String row.requirement); ("remediation", `String row.remediation) ]

let ordered_queue_entry_to_yojson (row : ordered_queue_entry) =
  `Assoc
    [
      ("issue_identifier", `String row.issue_identifier);
      ("title", (match row.title with Some s -> `String s | None -> `Null));
      ("state", `String row.state);
      ("skip_reason", (match row.skip_reason with Some s -> `String s | None -> `Null));
    ]

let ordered_queue_to_yojson (row : ordered_queue) =
  `Assoc [ ("entries", `List (List.map ordered_queue_entry_to_yojson row.entries)) ]

let compozy_progress_of_prd_run (run : Compozy_tasks_tracker.prd_run) =
  let counts = run.counts in
  {
    run_id = run.id;
    slug = run.slug;
    current_step = Option.map (fun (step : Compozy_tasks_tracker.task_step) -> step.file) run.current_step;
    completed = counts.completed;
    failed = counts.failed;
    skipped = counts.skipped;
    total = counts.total;
  }

let compozy_progress_to_yojson (row : compozy_progress) =
  `Assoc
    [
      ("run_id", `String row.run_id);
      ("slug", `String row.slug);
      ("current_step", (match row.current_step with Some step -> `String step | None -> `Null));
      ("completed", `Int row.completed);
      ("failed", `Int row.failed);
      ("skipped", `Int row.skipped);
      ("total", `Int row.total);
    ]

let startup_reconciliation_to_yojson (row : startup_reconciliation) =
  `Assoc
    [
      ("issue_id", (match row.issue_id with Some s -> `String s | None -> `Null));
      ("issue_identifier", (match row.issue_identifier with Some s -> `String s | None -> `Null));
      ("task_branch", (match row.task_branch with Some s -> `String s | None -> `Null));
      ("workspace_path", (match row.workspace_path with Some s -> `String s | None -> `Null));
      ("category", `String row.category);
      ("message", `String row.message);
    ]

let task_branch_integration_to_yojson (row : task_branch_integration) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("task_branch", `String row.task_branch);
      ("workspace_path", (match row.workspace_path with Some s -> `String s | None -> `Null));
      ("result", `String row.result);
      ("direct_fast_forward", `Bool row.direct_fast_forward);
      ("task_branch_updated_from_loop_start", `Bool row.task_branch_updated_from_loop_start);
      ("attention", (match row.attention with Some s -> `String s | None -> `Null));
      ("message", `String row.message);
    ]

let json_member name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let json_string_member name json =
  match json_member name json with Some (`String value) when Util.trim value <> "" -> Some value | _ -> None

let json_int_member name json =
  match json_member name json with Some (`Int value) -> Some value | _ -> None

let ordered_queue_entry_of_yojson json =
  match json_string_member "issue_identifier" json with
  | None -> None
  | Some issue_identifier ->
      Some
        {
          issue_identifier;
          title = json_string_member "title" json;
          state = Option.value (json_string_member "state" json) ~default:"pending";
          skip_reason = json_string_member "skip_reason" json;
        }

let ordered_queue_of_yojson json =
  match json_member "entries" json with
  | Some (`List entries) -> Some { entries = List.filter_map ordered_queue_entry_of_yojson entries }
  | _ -> None

let compozy_progress_of_yojson json =
  match (json_string_member "run_id" json, json_string_member "slug" json) with
  | Some run_id, Some slug ->
      Some
        {
          run_id;
          slug;
          current_step = json_string_member "current_step" json;
          completed = Option.value (json_int_member "completed" json) ~default:0;
          failed = Option.value (json_int_member "failed" json) ~default:0;
          skipped = Option.value (json_int_member "skipped" json) ~default:0;
          total = Option.value (json_int_member "total" json) ~default:0;
        }
  | _ -> None

let compozy_progress_from_snapshot_yojson json =
  match json_member "compozy_progress" json with Some (`Assoc _ as progress) -> compozy_progress_of_yojson progress | _ -> None

let tracker_kind_from_snapshot_yojson json =
  Option.value (json_string_member "tracker_kind" json) ~default:"github"

let pull_request_handoff_to_yojson row =
  `Assoc
    [
      ("enabled", `Bool row.enabled);
      ("mode", `String row.mode);
      ("issue_identifier", (match row.issue_identifier with Some s -> `String s | None -> `Null));
      ("head_branch", (match row.head_branch with Some s -> `String s | None -> `Null));
      ("base_branch", (match row.base_branch with Some s -> `String s | None -> `Null));
      ("status", `String row.status);
      ("url", (match row.url with Some s -> `String s | None -> `Null));
      ("error", (match row.error with Some s -> `String s | None -> `Null));
    ]

let context_diagnostic_to_yojson row =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("stage_agent", (match row.stage_agent with Some s -> `String s | None -> `Null));
      ("diagnostic_id", `String row.diagnostic_id);
      ("diagnostic_path", `String row.diagnostic_path);
      ("command_name", (match row.command_name with Some s -> `String s | None -> `Null));
      ("cwd_kind", (match row.cwd_kind with Some s -> `String s | None -> `Null));
      ("timed_out", (match row.timed_out with Some s -> `Bool s | None -> `Null));
      ("exit_code", (match row.exit_code with Some s -> `Int s | None -> `Null));
      ("stdout_bytes", (match row.stdout_bytes with Some s -> `Int s | None -> `Null));
      ("stderr_bytes", (match row.stderr_bytes with Some s -> `Int s | None -> `Null));
      ("stdout_truncated", (match row.stdout_truncated with Some s -> `Bool s | None -> `Null));
    ]

let to_yojson state =
  `Assoc
    [
      ("generated_at", `String (Util.now_iso8601 ()));
      ("workspace_repository_name", (match state.workspace_repository_name with Some s -> `String s | None -> `Null));
      ("tracker_kind", `String state.tracker_kind);
      ("counts", `Assoc [ ("running", `Int (List.length state.running)); ("retrying", `Int (List.length state.retrying)) ]);
      ("issues", `List (List.map issue_to_yojson state.issues));
      ("running", `List (List.map (running_to_yojson state) state.running));
      ("retrying", `List (List.map (retrying_to_yojson state) state.retrying));
      ("issue_errors", `List (List.map issue_error_to_yojson state.issue_errors));
      ("status_order", `List (List.map (fun status -> `String status) state.status_order));
      ("readiness_gaps", `List (List.map readiness_gap_to_yojson state.readiness_gaps));
      ( "usage_totals",
        `Assoc
          [
            ("input_tokens", `Int state.usage_totals.input_tokens);
            ("output_tokens", `Int state.usage_totals.output_tokens);
            ("total_tokens", `Int state.usage_totals.total_tokens);
            ("seconds_running", `Float state.seconds_running);
          ] );
      ("rate_limits", Option.value state.rate_limits ~default:`Null);
      ("pull_request", (match state.pull_request with Some row -> pull_request_handoff_to_yojson row | None -> `Null));
      ("pull_requests", `List (List.map pull_request_handoff_to_yojson state.pull_requests));
      ("ordered_queue", (match state.ordered_queue with Some row -> ordered_queue_to_yojson row | None -> `Null));
      ("compozy_progress", (match state.compozy_progress with Some row -> compozy_progress_to_yojson row | None -> `Null));
      ("startup_reconciliation", `List (List.map startup_reconciliation_to_yojson state.startup_reconciliation));
      ("task_branch_integrations", `List (List.map task_branch_integration_to_yojson state.task_branch_integrations));
      ("context_diagnostics", `List (List.map context_diagnostic_to_yojson state.context_diagnostics));
      ("last_error", (match state.last_error with Some s -> `String s | None -> `Null));
    ]
