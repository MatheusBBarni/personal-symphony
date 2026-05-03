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

type t = {
  running : running list;
  retrying : retrying list;
  codex_totals : tokens;
  seconds_running : float;
  rate_limits : Yojson.Safe.t option;
  last_error : string option;
}

let empty ?last_error () =
  {
    running = [];
    retrying = [];
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

let running_to_yojson row =
  `Assoc
    [
      ("issue_id", `String row.issue.id);
      ("issue_identifier", `String row.issue.identifier);
      ("state", `String row.issue.state);
      ("session_id", (match row.session_id with Some s -> `String s | None -> `Null));
      ("turn_count", `Int row.turn_count);
      ("last_event", (match row.last_event with Some s -> `String s | None -> `Null));
      ("last_message", (match row.last_message with Some s -> `String s | None -> `Null));
      ("started_at", `String row.started_at);
      ("last_event_at", (match row.last_event_at with Some s -> `String s | None -> `Null));
      ("tokens", tokens_to_yojson row.tokens);
    ]

let retrying_to_yojson row =
  `Assoc
    [
      ("issue_id", `String row.issue_id);
      ("issue_identifier", `String row.issue_identifier);
      ("attempt", `Int row.attempt);
      ("due_at", `String row.due_at);
      ("error", (match row.error with Some s -> `String s | None -> `Null));
    ]

let to_yojson state =
  `Assoc
    [
      ("generated_at", `String (Util.now_iso8601 ()));
      ("counts", `Assoc [ ("running", `Int (List.length state.running)); ("retrying", `Int (List.length state.retrying)) ]);
      ("running", `List (List.map running_to_yojson state.running));
      ("retrying", `List (List.map retrying_to_yojson state.retrying));
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
