open Mosaic

module Projection = Terminal_console_model

type runtime = {
  initial_state : Runtime_state.t;
  subscribe : (Runtime_state.t -> unit) -> unit;
  safe_aid : Projection.safe_aid -> unit;
}

type model = {
  snapshot : Projection.t;
  status_label : string;
  status_message : string option;
}

type msg = Snapshot_received of Runtime_state.t | Redraw | Quit

let compile_anchor = "terminal-console-mosaic"

let status_label = function
  | "idle" -> "Idle"
  | "ready" -> "Ready"
  | "running" -> "Running"
  | "retrying" -> "Retrying"
  | "attention" -> "Needs attention"
  | "readiness_blocked" -> "Readiness blocked"
  | mode ->
      let sanitized = Projection.sanitize mode in
      if sanitized = "" then "Unknown" else "Unknown: " ^ sanitized

let initial_model state =
  let snapshot = Projection.of_runtime_state state in
  { snapshot; status_label = status_label snapshot.mode; status_message = None }

let active_row_label (row : Projection.task_row) =
  let base = Printf.sprintf "%s [%s] %s" row.id row.state row.title in
  match row.detail with None -> base | Some detail -> base ^ " - " ^ detail

let readiness_label (row : Projection.readiness_row) = row.requirement ^ ": " ^ row.remediation

let safe_aid_label = function
  | Projection.Refresh_view -> "Refresh view"
  | Show_web_handoff -> "Show Web Dashboard handoff"
  | Show_path path -> "Show path " ^ Projection.sanitize path

let nonempty_lines fallback = function [] -> [ fallback ] | lines -> lines

let text_lines lines = List.map (fun line -> text ~truncate:true line) lines

let section title lines =
  box ~flex_direction:Column ~border:true ~title ~padding:(padding 1)
    (lines |> nonempty_lines "None" |> text_lines)

let view model =
  let snapshot = model.snapshot in
  let active = List.map active_row_label snapshot.active in
  let readiness = List.map readiness_label snapshot.readiness in
  let queue = List.map active_row_label snapshot.queue in
  let aids = List.map safe_aid_label snapshot.safe_aids in
  let footer =
    match model.status_message with None -> "q quit, r redraw" | Some message -> message ^ " | q quit, r redraw"
  in
  box ~flex_direction:Column ~size:{ width = pct 100; height = pct 100 } ~padding:(padding 1) ~gap:(gap 1)
    [
      text ~style:(Ansi.Style.make ~bold:true ()) "Terminal Console";
      text (Printf.sprintf "%s | generated %s" model.status_label snapshot.generated_at);
      section "Summary" snapshot.summary;
      section "Active" active;
      section "Readiness" readiness;
      section "Ordered Queue" queue;
      section "Safe Aids" aids;
      text footer;
    ]

let init runtime () =
  let model = initial_model runtime.initial_state in
  let subscribe =
    Cmd.perform (fun dispatch -> runtime.subscribe (fun state -> dispatch (Snapshot_received state)))
  in
  (model, subscribe)

let update _runtime msg model =
  match msg with
  | Snapshot_received state -> (initial_model state, Cmd.none)
  | Redraw -> ({ model with status_message = Some "Redrew latest projected snapshot" }, Cmd.none)
  | Quit -> (model, Cmd.quit)

let subscriptions _model =
  Sub.on_key_all (fun ev ->
      match (Event.Key.data ev).key with
      | Char c when Uchar.equal c (Uchar.of_char 'q') -> Some Quit
      | Char c when Uchar.equal c (Uchar.of_char 'r') -> Some Redraw
      | Escape -> Some Quit
      | _ -> None)

let app runtime =
  {
    init = init runtime;
    update = update runtime;
    view;
    subscriptions;
  }

let run runtime = Mosaic.run (app runtime)
