type tokens = { input_tokens : int; output_tokens : int; total_tokens : int }

type running = {
  issue : Issue.t;
  session_id : string option;
  turn_count : int;
  last_event : string option;
  last_message : string option;
  started_at : string;
  last_event_at : string option;
  tokens : tokens;
}

type retrying = { issue_id : string; issue_identifier : string; attempt : int; due_at : string; error : string option }
type issue_error = { issue_id : string; issue_identifier : string; error : string }
type readiness_gap = { requirement : string; remediation : string }

type t = {
  issues : Issue.t list;
  running : running list;
  retrying : retrying list;
  issue_errors : issue_error list;
  readiness_gaps : readiness_gap list;
  codex_totals : tokens;
  seconds_running : float;
  rate_limits : Yojson.Safe.t option;
  last_error : string option;
}

let empty ?(readiness_gaps = []) ?last_error () =
  {
    running = [];
    issues = [];
    retrying = [];
    issue_errors = [];
    readiness_gaps;
    codex_totals = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
    seconds_running = 0.;
    rate_limits = None;
    last_error;
  }

let tokens_to_yojson tokens =
  `Assoc
    [
      ("input_tokens", `Int tokens.input_tokens);
      ("output_tokens", `Int tokens.output_tokens);
      ("total_tokens", `Int tokens.total_tokens);
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
    ]

let retrying_to_yojson (row : retrying) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("attempt", `Int row.attempt);
      ("due_at", `String row.due_at);
      ("error", (match row.error with Some s -> `String s | None -> `Null));
    ]

let issue_error_to_yojson (row : issue_error) =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("error", `String row.error);
    ]

let readiness_gap_to_yojson row =
  `Assoc [ ("requirement", `String row.requirement); ("remediation", `String row.remediation) ]

let to_yojson state =
  `Assoc
    [
      ("generated_at", `String (Util.now_iso8601 ()));
      ("counts", `Assoc [ ("running", `Int (List.length state.running)); ("retrying", `Int (List.length state.retrying)) ]);
      ("issues", `List (List.map issue_to_yojson state.issues));
      ("running", `List (List.map running_to_yojson state.running));
      ("retrying", `List (List.map retrying_to_yojson state.retrying));
      ("issue_errors", `List (List.map issue_error_to_yojson state.issue_errors));
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
      ("last_error", (match state.last_error with Some s -> `String s | None -> `Null));
    ]
