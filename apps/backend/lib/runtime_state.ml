type tokens = { input_tokens : int; output_tokens : int; total_tokens : int }
type goal_usage = { status : string option; time_used_seconds : float option; tokens_used : int option }

type running = {
  issue : Issue.t;
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
type pull_request_handoff = {
  enabled : bool;
  head_branch : string option;
  base_branch : string option;
  status : string;
  url : string option;
  error : string option;
}

type t = {
  issues : Issue.t list;
  running : running list;
  retrying : retrying list;
  issue_errors : issue_error list;
  status_order : string list;
  readiness_gaps : readiness_gap list;
  codex_totals : tokens;
  seconds_running : float;
  rate_limits : Yojson.Safe.t option;
  pull_request : pull_request_handoff option;
  ordered_queue : ordered_queue option;
  last_error : string option;
}

let empty ?(readiness_gaps = []) ?(status_order = []) ?ordered_queue ?last_error () =
  {
    running = [];
    issues = [];
    retrying = [];
    issue_errors = [];
    status_order;
    readiness_gaps;
    codex_totals = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
    seconds_running = 0.;
    rate_limits = None;
    pull_request = None;
    ordered_queue;
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

let issue_to_yojson issue =
  `Assoc
    [
      ("issue_id", `String issue.Issue.id);
      ("issue_identifier", `String issue.identifier);
      ("title", `String issue.title);
      ("description", (match issue.description with Some s -> `String s | None -> `Null));
      ("url", (match issue.url with Some s -> `String s | None -> `Null));
      ("state", `String issue.state);
      ("created_at", (match issue.created_at with Some s -> `String s | None -> `Null));
      ("updated_at", (match issue.updated_at with Some s -> `String s | None -> `Null));
    ]

let running_to_yojson row =
  `Assoc
    [
      ("issue_id", `String row.issue.id);
      ("issue_identifier", `String row.issue.identifier);
      ("title", `String row.issue.title);
      ("description", (match row.issue.description with Some s -> `String s | None -> `Null));
      ("url", (match row.issue.url with Some s -> `String s | None -> `Null));
      ("state", `String row.issue.state);
      ("session_id", (match row.session_id with Some s -> `String s | None -> `Null));
      ("turn_count", `Int row.turn_count);
      ("last_event", (match row.last_event with Some s -> `String s | None -> `Null));
      ("last_message", (match row.last_message with Some s -> `String s | None -> `Null));
      ("started_at", `String row.started_at);
      ("last_event_at", (match row.last_event_at with Some s -> `String s | None -> `Null));
      ("tokens", tokens_to_yojson row.tokens);
      ("goal_usage", (match row.goal_usage with Some usage -> goal_usage_to_yojson usage | None -> `Null));
    ]

let retrying_to_yojson (row : retrying) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("attempt", `Int row.attempt);
      ("due_at", `String row.due_at);
      ("error", (match row.error with Some s -> `String s | None -> `Null));
      ("goal_usage", (match row.goal_usage with Some usage -> goal_usage_to_yojson usage | None -> `Null));
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

let ordered_queue_entry_to_yojson row =
  `Assoc
    [
      ("issue_identifier", `String row.issue_identifier);
      ("title", (match row.title with Some s -> `String s | None -> `Null));
      ("state", `String row.state);
      ("skip_reason", (match row.skip_reason with Some s -> `String s | None -> `Null));
    ]

let ordered_queue_to_yojson row =
  `Assoc [ ("entries", `List (List.map ordered_queue_entry_to_yojson row.entries)) ]

let json_member name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let json_string_member name json =
  match json_member name json with Some (`String value) when Util.trim value <> "" -> Some value | _ -> None

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

let pull_request_handoff_to_yojson row =
  `Assoc
    [
      ("enabled", `Bool row.enabled);
      ("head_branch", (match row.head_branch with Some s -> `String s | None -> `Null));
      ("base_branch", (match row.base_branch with Some s -> `String s | None -> `Null));
      ("status", `String row.status);
      ("url", (match row.url with Some s -> `String s | None -> `Null));
      ("error", (match row.error with Some s -> `String s | None -> `Null));
    ]

let to_yojson state =
  `Assoc
    [
      ("generated_at", `String (Util.now_iso8601 ()));
      ("counts", `Assoc [ ("running", `Int (List.length state.running)); ("retrying", `Int (List.length state.retrying)) ]);
      ("issues", `List (List.map issue_to_yojson state.issues));
      ("running", `List (List.map running_to_yojson state.running));
      ("retrying", `List (List.map retrying_to_yojson state.retrying));
      ("issue_errors", `List (List.map issue_error_to_yojson state.issue_errors));
      ("status_order", `List (List.map (fun status -> `String status) state.status_order));
      ("readiness_gaps", `List (List.map readiness_gap_to_yojson state.readiness_gaps));
      ( "codex_totals",
        `Assoc
          [
            ("input_tokens", `Int state.codex_totals.input_tokens);
            ("output_tokens", `Int state.codex_totals.output_tokens);
            ("total_tokens", `Int state.codex_totals.total_tokens);
            ("seconds_running", `Float state.seconds_running);
          ] );
      ("rate_limits", Option.value state.rate_limits ~default:`Null);
      ("pull_request", (match state.pull_request with Some row -> pull_request_handoff_to_yojson row | None -> `Null));
      ("ordered_queue", (match state.ordered_queue with Some row -> ordered_queue_to_yojson row | None -> `Null));
      ("last_error", (match state.last_error with Some s -> `String s | None -> `Null));
    ]
