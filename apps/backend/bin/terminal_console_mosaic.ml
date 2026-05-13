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
  terminal_size : terminal_size option;
}

and terminal_size = { columns : int; rows : int }

type panel = { title : string; lines : string list }

type rendered_snapshot = {
  heading : string;
  subheading : string;
  panels : panel list;
  footer : string;
}

type msg = Snapshot_received of Runtime_state.t | Redraw | Resize of terminal_size | Quit

let compile_anchor = "terminal-console-mosaic"
let minimum_terminal_size = { columns = 80; rows = 24 }

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

let initial_model ?terminal_size state =
  let snapshot = Projection.of_runtime_state state in
  { snapshot; status_label = status_label snapshot.mode; status_message = None; terminal_size }

let starts_with text prefix =
  let prefix_len = String.length prefix in
  prefix_len <= String.length text && String.sub text 0 prefix_len = prefix

let option_value ~default = function Some value -> value | None -> default

let is_state state (row : Projection.task_row) = String.lowercase_ascii row.state = state

let state_rank state =
  match String.lowercase_ascii state with
  | "attention" -> 0
  | "retrying" -> 1
  | "running" -> 2
  | "pending" -> 3
  | "completed" -> 4
  | "skipped" -> 5
  | _ -> 6

let ordered_rows rows =
  List.stable_sort
    (fun (left : Projection.task_row) (right : Projection.task_row) -> compare (state_rank left.state) (state_rank right.state))
    rows

let state_token state =
  match String.lowercase_ascii state with
  | "idle" -> "IDLE"
  | "ready" -> "READY"
  | "running" -> "RUNNING"
  | "retrying" -> "RETRYING"
  | "attention" -> "ATTENTION"
  | "readiness_blocked" -> "READINESS BLOCKED"
  | "pending" -> "PENDING"
  | "completed" -> "COMPLETED"
  | "skipped" -> "SKIPPED"
  | state ->
      let sanitized = Projection.sanitize state in
      if sanitized = "" then "UNKNOWN" else String.uppercase_ascii sanitized

let shorten ?(max = 160) text =
  let text = Projection.sanitize text in
  if String.length text <= max then text
  else if max <= 3 then String.sub text 0 max
  else String.sub text 0 (max - 3) ^ "..."

let words text = text |> String.split_on_char ' ' |> List.filter (fun word -> word <> "")

let rec chunks width word =
  if String.length word <= width then [ word ]
  else String.sub word 0 width :: chunks width (String.sub word width (String.length word - width))

let wrap_line ~width text =
  let width = max 12 width in
  let words = words text |> List.concat_map (chunks width) in
  let rec loop current current_len acc = function
    | [] -> (
        match current with "" -> List.rev acc | _ -> List.rev (current :: acc))
    | word :: rest ->
        let word_len = String.length word in
        if current = "" then loop word word_len acc rest
        else if current_len + 1 + word_len <= width then
          loop (current ^ " " ^ word) (current_len + 1 + word_len) acc rest
        else loop word word_len (current :: acc) rest
  in
  match words with [] -> [ "" ] | words -> loop "" 0 [] words

let wrap_lines ~width lines = List.concat_map (wrap_line ~width) lines

let content_width = function
  | None -> 100
  | Some size -> max 32 (size.columns - 6)

let terminal_too_small size =
  size.columns < minimum_terminal_size.columns || size.rows < minimum_terminal_size.rows

let minimum_size_lines size =
  [
    Printf.sprintf "Terminal Console needs at least %d columns x %d rows." minimum_terminal_size.columns
      minimum_terminal_size.rows;
    Printf.sprintf "Current size: %d columns x %d rows." size.columns size.rows;
    "Resize the terminal to continue.";
  ]

let summary_line snapshot prefix = List.find_opt (fun line -> starts_with line prefix) snapshot.Projection.summary

let total_tokens_line snapshot =
  option_value ~default:"Total tokens: unavailable" (summary_line snapshot "Total tokens:")

let count_active state rows = rows |> List.filter (is_state state) |> List.length

let next_queue_row snapshot = List.find_opt (is_state "pending") snapshot.Projection.queue

let task_row_line ?(prefix = "") (row : Projection.task_row) =
  let base = Printf.sprintf "%s%s %s %s" prefix (state_token row.state) row.id row.title in
  match row.detail with None -> base | Some detail -> base ^ " - " ^ shorten detail

let queue_row_line ?(next = false) (row : Projection.task_row) =
  let base =
    Printf.sprintf "%s%s %s %s" (if next then "NEXT " else "") (state_token row.state) row.id row.title
  in
  match row.error with
  | Some reason when String.lowercase_ascii row.state = "skipped" -> base ^ " - skip reason: " ^ shorten reason
  | _ -> (
      match row.detail with None -> base | Some detail -> base ^ " - " ^ shorten detail)

let idle_home_line mode =
  match mode with
  | "readiness_blocked" -> "READINESS BLOCKED Dispatch is blocked by Readiness Gaps."
  | "ready" -> "READY Waiting for next Ordered Queue dispatch."
  | _ -> "IDLE No active work."

let home_panel ?terminal_size (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let active_rows = ordered_rows snapshot.Projection.active in
  let active_lines =
    match active_rows with [] -> [ idle_home_line snapshot.mode ] | rows -> List.map task_row_line rows
  in
  let next_lines =
    match next_queue_row snapshot with Some row -> [ "Next work: " ^ queue_row_line ~next:true row ] | None -> []
  in
  let error_lines =
    match snapshot.last_error with Some error -> [ "Last state error: " ^ shorten error ] | None -> []
  in
  let lines =
    [
      "Status: " ^ status_label snapshot.mode;
      "Updated: " ^ snapshot.generated_at;
      Printf.sprintf "Active: RUNNING %d | RETRYING %d | ATTENTION %d"
        (count_active "running" snapshot.active)
        (count_active "retrying" snapshot.active)
        (count_active "attention" snapshot.active);
      total_tokens_line snapshot;
    ]
    @ active_lines @ next_lines @ error_lines
  in
  { title = "Active Work"; lines = wrap_lines ~width lines }

let readiness_lines ~width readiness =
  readiness
  |> List.mapi (fun index (row : Projection.readiness_row) ->
         wrap_lines ~width
           [
             Printf.sprintf "READINESS GAP %d requirement: %s" (index + 1) row.requirement;
             "Remediation: " ^ row.remediation;
           ])
  |> List.concat

let attention_lines ~width active =
  active
  |> List.filter (is_state "attention")
  |> ordered_rows
  |> List.map (fun row ->
         let lines =
           task_row_line row
           ::
           (match row.error with Some error -> [ "Current error: " ^ shorten error ] | None -> [])
         in
         wrap_lines ~width lines)
  |> List.concat

let readiness_attention_panel ?terminal_size (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let readiness = readiness_lines ~width snapshot.Projection.readiness in
  let attention = attention_lines ~width snapshot.active in
  let lines =
    match (readiness, attention) with
    | [], [] -> [ "No Readiness Gaps or task attention conditions." ]
    | readiness, [] -> readiness
    | [], attention -> attention
    | readiness, attention -> readiness @ [ "" ] @ attention
  in
  { title = "Readiness and Attention"; lines }

let ordered_queue_panel ?terminal_size (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match snapshot.Projection.queue with
    | [] -> [ "No Ordered Queue state present." ]
    | queue ->
        let next =
          match next_queue_row snapshot with Some row -> [ "Next work: " ^ queue_row_line ~next:true row ] | None -> []
        in
        next @ List.map queue_row_line queue
  in
  { title = "Ordered Queue"; lines = wrap_lines ~width lines }

let compozy_panel ?terminal_size (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match snapshot.Projection.compozy with
    | None -> [ "No Compozy PRD Run progress present." ]
    | Some progress ->
        [
          "Compozy PRD Run: " ^ progress.slug;
          "Run ID: " ^ progress.run_id;
          "Current step: " ^ option_value ~default:"No active step" progress.current_step;
          Printf.sprintf "Progress: completed %d | failed %d | skipped %d | total %d" progress.completed
            progress.failed progress.skipped progress.total;
        ]
  in
  { title = "Compozy PRD Run"; lines = wrap_lines ~width lines }

let split_detail detail =
  detail |> String.split_on_char '|' |> List.map Util.trim |> List.filter (fun item -> item <> "")

let detail_items row = match row.Projection.detail with None -> [] | Some detail -> split_detail detail

let detail_group prefixes items =
  List.filter (fun item -> List.exists (fun prefix -> starts_with item prefix) prefixes) items

let optional_join label items = match items with [] -> [] | items -> [ label ^ String.concat " | " items ]

let goal_usage_line (usage : Projection.goal_usage) =
  match usage.text with
  | Some text -> Some ("Goal Usage: " ^ text)
  | None ->
      let parts =
        []
        |> (fun parts -> match usage.status with Some status -> ("status " ^ status) :: parts | None -> parts)
        |> (fun parts ->
             match usage.time_used_seconds with
             | Some seconds -> Printf.sprintf "time %.0fs" seconds :: parts
             | None -> parts)
        |> fun parts -> match usage.tokens_used with Some tokens -> Printf.sprintf "tokens %d" tokens :: parts | None -> parts
      in
      if parts = [] then None else Some ("Goal Usage: " ^ String.concat " | " (List.rev parts))

let selected_task (snapshot : Projection.t) =
  ordered_rows snapshot.Projection.active |> function [] -> None | row :: _ -> Some row

let task_detail_panel ?terminal_size (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match selected_task snapshot with
    | None -> [ "No active, retrying, or attention work selected." ]
    | Some row ->
        let items = detail_items row in
        let issue_metadata = detail_group [ "issue state "; "branch " ] items in
        let stage_state = detail_group [ "stage agent "; "stage states "; "last event "; "last message " ] items in
        let harness_identity = detail_group [ "harness "; "harness kind " ] items in
        [
          Printf.sprintf "Task: %s %s" row.id row.title;
          "State: " ^ state_token row.state;
        ]
        @ optional_join "Issue metadata: " issue_metadata
        @ optional_join "Stage state: " stage_state
        @ optional_join "Harness identity: " harness_identity
        @ (match row.goal_usage with Some usage -> Option.to_list (goal_usage_line usage) | None -> [])
        @ (match row.context_status with Some context -> [ "Context Status: " ^ context.text ] | None -> [])
        @ (match row.error with Some error -> [ "Current error: " ^ shorten error ] | None -> [])
  in
  { title = "Task Detail"; lines = wrap_lines ~width lines }

let safe_aid_label = function
  | Projection.Refresh_view -> "Refresh view"
  | Show_web_handoff -> "Show Web Dashboard handoff"
  | Show_path path -> "Show path " ^ Projection.sanitize path

let safe_aids_panel (snapshot : Projection.t) =
  { title = "Safe Aids"; lines = List.map safe_aid_label snapshot.Projection.safe_aids }

let render_snapshot ?terminal_size (snapshot : Projection.t) =
  match terminal_size with
  | Some size when terminal_too_small size ->
      {
        heading = "Terminal Console";
        subheading = "Resize required";
        panels = [ { title = "Minimum Size"; lines = minimum_size_lines size } ];
        footer = "q quit";
      }
  | _ ->
      {
        heading = "Terminal Console";
        subheading = Printf.sprintf "%s | generated %s" (status_label snapshot.mode) snapshot.generated_at;
        panels =
          [
            home_panel ?terminal_size snapshot;
            readiness_attention_panel ?terminal_size snapshot;
            ordered_queue_panel ?terminal_size snapshot;
            compozy_panel ?terminal_size snapshot;
            task_detail_panel ?terminal_size snapshot;
            safe_aids_panel snapshot;
          ];
        footer = "q quit, r redraw";
      }

let rendered_lines rendered =
  rendered.heading :: rendered.subheading
  :: (List.concat_map (fun panel -> panel.title :: panel.lines) rendered.panels @ [ rendered.footer ])

let panel_lines rendered title =
  match List.find_opt (fun panel -> panel.title = title) rendered.panels with
  | Some panel -> panel.lines
  | None -> []

let render_model model =
  let rendered = render_snapshot ?terminal_size:model.terminal_size model.snapshot in
  let footer =
    match model.status_message with None -> rendered.footer | Some message -> message ^ " | " ^ rendered.footer
  in
  { rendered with footer }

let nonempty_lines fallback = function [] -> [ fallback ] | lines -> lines

let text_lines lines = List.map (fun line -> text ~wrap:`Word line) lines

let section ?flex_grow title lines =
  box ?flex_grow ~flex_direction:Column ~border:true ~border_style:Border.ascii ~title ~padding:(padding 1)
    (lines |> nonempty_lines "None" |> text_lines)

let find_panel rendered title = List.find_opt (fun panel -> panel.title = title) rendered.panels

let section_for_panel ?flex_grow rendered title =
  match find_panel rendered title with
  | Some panel -> section ?flex_grow panel.title panel.lines
  | None -> empty

let narrow_layout = function None -> false | Some size -> size.columns < 100

let view model =
  let rendered = render_model model in
  let panel_views =
    if narrow_layout model.terminal_size then List.map (fun panel -> section panel.title panel.lines) rendered.panels
    else
      [
        section_for_panel rendered "Active Work";
        box ~flex_direction:Row ~gap:(gap 1)
          [
            section_for_panel ~flex_grow:1. rendered "Readiness and Attention";
            section_for_panel ~flex_grow:1. rendered "Ordered Queue";
            section_for_panel ~flex_grow:1. rendered "Compozy PRD Run";
          ];
        section_for_panel rendered "Task Detail";
        section_for_panel rendered "Safe Aids";
      ]
  in
  box ~flex_direction:Column ~size:{ width = pct 100; height = pct 100 } ~padding:(padding 1) ~gap:(gap 1)
    ([ text ~style:(Ansi.Style.make ~bold:true ()) rendered.heading; text rendered.subheading ]
    @ panel_views @ [ text rendered.footer ])

let init runtime () =
  let model = initial_model runtime.initial_state in
  let subscribe =
    Cmd.perform (fun dispatch -> runtime.subscribe (fun state -> dispatch (Snapshot_received state)))
  in
  (model, subscribe)

let update _runtime msg model =
  match msg with
  | Snapshot_received state -> ({ (initial_model state) with terminal_size = model.terminal_size }, Cmd.none)
  | Redraw -> ({ model with status_message = Some "Redrew latest projected snapshot" }, Cmd.none)
  | Resize { columns; rows } -> ({ model with terminal_size = Some { columns; rows } }, Cmd.none)
  | Quit -> (model, Cmd.quit)

let subscriptions _model =
  Sub.batch
    [
      Sub.on_key_all (fun ev ->
          match (Event.Key.data ev).key with
          | Char c when Uchar.equal c (Uchar.of_char 'q') -> Some Quit
          | Char c when Uchar.equal c (Uchar.of_char 'r') -> Some Redraw
          | Escape -> Some Quit
          | _ -> None);
      Sub.on_resize (fun ~width ~height -> Resize { columns = width; rows = height });
    ]

let app runtime =
  {
    init = init runtime;
    update = update runtime;
    view;
    subscriptions;
  }

let run runtime = Mosaic.run (app runtime)
