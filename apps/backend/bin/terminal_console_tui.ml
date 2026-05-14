open Tui

module Projection = Terminal_console_model

type web_handoff = { command : string; url : string }
type local_surface = { label : string; root : string }

type runtime = {
  initial_state : Runtime_state.t;
  initial_logs : string list;
  subscribe : (Runtime_state.t -> unit) -> unit;
  safe_aid : Projection.safe_aid -> unit;
  web_handoff : web_handoff;
  local_surfaces : local_surface list;
}

type active_tab = Queue | Logs | Tasks | Readiness | Attention

type row_selection = {
  active : int;
  readiness : int;
  queue : int;
  attention : int;
  safe_aid : int;
}

type interaction = {
  active_tab : active_tab;
  selected_rows : row_selection;
  filter_text : string;
  filter_active : bool;
  help_visible : bool;
  logs_scroll : int;
  expanded_queue_id : string option;
}

type model = {
  snapshot : Projection.t;
  status_label : string;
  status_message : string option;
  logs : string list;
  terminal_size : terminal_size option;
  interaction : interaction;
}

and terminal_size = { columns : int; rows : int }

type panel = { title : string; lines : string list }

type rendered_snapshot = {
  heading : string;
  status_label : string;
  tabs : string;
  subheading : string;
  panels : panel list;
  footer : string;
}

type ui_key =
  | Character of char
  | Enter_key
  | Backspace_key
  | Escape_key
  | Up_key
  | Down_key
  | Left_key
  | Right_key
  | Tab_key
  | Space_key
  | Page_up_key
  | Page_down_key

type transition = {
  model : model;
  safe_aids : Projection.safe_aid list;
  quit : bool;
}

type msg = Snapshot_received of Runtime_state.t | Key_press of ui_key | Resize of terminal_size

let compile_anchor = "terminal-console-tui"
let minimum_terminal_size = { columns = 80; rows = 24 }
let default_web_handoff ?(host = "127.0.0.1") ?(port = 8080) () =
  { command = Printf.sprintf "symphony --web --port %d" port; url = Printf.sprintf "http://%s:%d/" host port }

let local_surface ~label ~root = { label = Projection.sanitize label; root }

let default_row_selection = { active = 0; readiness = 0; queue = 0; attention = 0; safe_aid = 0 }

let default_interaction =
  {
    active_tab = Queue;
    selected_rows = default_row_selection;
    filter_text = "";
    filter_active = false;
    help_visible = false;
    logs_scroll = 0;
    expanded_queue_id = None;
  }

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

let status_badge_label = function
  | "idle" -> "STOPPED"
  | "readiness_blocked" -> "BLOCKED"
  | mode ->
      let mode = Projection.sanitize mode |> String.uppercase_ascii in
      if mode = "" then "UNKNOWN" else mode

let status_badge_tone = function
  | "idle" -> Components.Neutral
  | "ready" | "running" -> Components.Success
  | "retrying" | "attention" | "readiness_blocked" -> Components.Warning
  | _ -> Components.Info

let sanitize_logs logs =
  logs
  |> List.map Projection.sanitize
  |> List.filter (fun line -> line <> "")

let max_log_lines = 500

let keep_recent_logs logs =
  let count = List.length logs in
  if count <= max_log_lines then logs
  else
    let rec drop n lines = if n <= 0 then lines else match lines with [] -> [] | _ :: rest -> drop (n - 1) rest in
    drop (count - max_log_lines) logs

let rec drop_count count lines =
  if count <= 0 then lines else match lines with [] -> [] | _ :: rest -> drop_count (count - 1) rest

let rec take_count count lines =
  if count <= 0 then []
  else match lines with [] -> [] | line :: rest -> line :: take_count (count - 1) rest

let append_log_line model line =
  let new_logs = sanitize_logs [ line ] in
  let previous_count = List.length model.logs in
  let logs = keep_recent_logs (model.logs @ new_logs) in
  let dropped = max 0 ((previous_count + List.length new_logs) - List.length logs) in
  let logs_scroll =
    if model.interaction.logs_scroll = 0 then 0
    else max 0 (model.interaction.logs_scroll + List.length new_logs - dropped)
  in
  { model with logs; interaction = { model.interaction with logs_scroll } }

let initial_model ?terminal_size ?(logs = []) state =
  let snapshot = Projection.of_runtime_state state in
  {
    snapshot;
    status_label = status_label snapshot.mode;
    status_message = None;
    logs = keep_recent_logs (sanitize_logs logs);
    terminal_size;
    interaction = default_interaction;
  }

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

let tab_title = function
  | Queue -> "Queue"
  | Logs -> "Logs"
  | Tasks -> "Tasks"
  | Readiness -> "Readiness"
  | Attention -> "Needs attention"

let focused_tab_title = tab_title

let tab_order = [ Queue; Logs; Tasks; Readiness; Attention ]

let tab_index tab =
  let rec loop index = function
    | [] -> 0
    | current :: rest -> if current = tab then index else loop (index + 1) rest
  in
  loop 0 tab_order

let tab_at index =
  let count = List.length tab_order in
  let normalized = (index mod count + count) mod count in
  List.nth tab_order normalized

let move_tab delta interaction =
  let active_tab = tab_at (tab_index interaction.active_tab + delta) in
  { interaction with active_tab; filter_active = false }

let contains_substring text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  if needle_len = 0 then true
  else
    let rec loop index =
      index + needle_len <= text_len
      && (String.sub text index needle_len = needle || loop (index + 1))
    in
    loop 0

let filter_query interaction = interaction.filter_text |> Projection.sanitize |> String.lowercase_ascii |> Util.trim

let row_search_text (row : Projection.task_row) =
  [
    Some row.id;
    Some row.title;
    Some row.state;
    row.detail;
    row.error;
    Option.bind row.goal_usage (fun usage -> usage.text);
    Option.map (fun (status : Projection.context_status) -> status.text) row.context_status;
  ]
  |> List.filter_map Fun.id |> String.concat " " |> String.lowercase_ascii

let task_row_matches interaction row =
  let query = filter_query interaction in
  query = "" || contains_substring (row_search_text row) query

let visible_task_rows interaction rows = rows |> List.filter (task_row_matches interaction) |> ordered_rows
let visible_active_rows snapshot interaction = visible_task_rows interaction snapshot.Projection.active
let visible_queue_rows snapshot interaction = visible_task_rows interaction snapshot.Projection.queue
let visible_attention_rows snapshot interaction =
  visible_active_rows snapshot interaction |> List.filter (is_state "attention")

let readiness_search_text (row : Projection.readiness_row) =
  String.lowercase_ascii (row.requirement ^ " " ^ row.remediation)

let readiness_matches interaction row =
  let query = filter_query interaction in
  query = "" || contains_substring (readiness_search_text row) query

let visible_readiness_rows snapshot interaction = List.filter (readiness_matches interaction) snapshot.Projection.readiness

let safe_aid_label = function
  | Projection.Refresh_view -> "Refresh view"
  | Show_web_handoff -> "Show Web Dashboard handoff"
  | Show_path path -> "Show path " ^ Projection.sanitize path

let safe_aid_search_text aid = safe_aid_label aid |> String.lowercase_ascii

let safe_aid_matches interaction aid =
  let query = filter_query interaction in
  query = "" || contains_substring (safe_aid_search_text aid) query

let visible_safe_aids snapshot interaction = List.filter (safe_aid_matches interaction) snapshot.Projection.safe_aids

let clamp_index count index = if count <= 0 then 0 else max 0 (min (count - 1) index)

let list_nth_opt list index =
  let rec loop current = function
    | [] -> None
    | value :: _ when current = index -> Some value
    | _ :: rest -> loop (current + 1) rest
  in
  if index < 0 then None else loop 0 list

let clamp_interaction snapshot interaction =
  let active = clamp_index (List.length (visible_active_rows snapshot interaction)) interaction.selected_rows.active in
  let readiness = clamp_index (List.length (visible_readiness_rows snapshot interaction)) interaction.selected_rows.readiness in
  let queue_rows = visible_queue_rows snapshot interaction in
  let queue = clamp_index (List.length queue_rows) interaction.selected_rows.queue in
  let attention = clamp_index (List.length (visible_attention_rows snapshot interaction)) interaction.selected_rows.attention in
  let safe_aid = clamp_index (List.length (visible_safe_aids snapshot interaction)) interaction.selected_rows.safe_aid in
  let expanded_queue_id =
    match interaction.expanded_queue_id with
    | Some id when List.exists (fun (row : Projection.task_row) -> row.id = id) queue_rows -> Some id
    | _ -> None
  in
  {
    interaction with
    selected_rows = { active; readiness; queue; attention; safe_aid };
    logs_scroll = max 0 interaction.logs_scroll;
    expanded_queue_id;
  }

let row_count_for_tab snapshot interaction = function
  | Queue -> List.length (visible_queue_rows snapshot interaction)
  | Logs -> 0
  | Tasks -> List.length (visible_active_rows snapshot interaction)
  | Readiness -> List.length (visible_readiness_rows snapshot interaction)
  | Attention -> List.length (visible_attention_rows snapshot interaction)

let selected_row_for_tab interaction = function
  | Queue -> interaction.selected_rows.queue
  | Logs -> 0
  | Tasks -> interaction.selected_rows.active
  | Readiness -> interaction.selected_rows.readiness
  | Attention -> interaction.selected_rows.attention

let set_selected_row_for_tab interaction tab selected =
  let selected_rows =
    match tab with
    | Queue -> { interaction.selected_rows with queue = selected }
    | Logs -> interaction.selected_rows
    | Tasks -> { interaction.selected_rows with active = selected }
    | Readiness -> { interaction.selected_rows with readiness = selected }
    | Attention -> { interaction.selected_rows with attention = selected }
  in
  { interaction with selected_rows }

let move_row delta snapshot interaction =
  let tab = interaction.active_tab in
  let count = row_count_for_tab snapshot interaction tab in
  let current = selected_row_for_tab interaction tab in
  let selected = clamp_index count (current + delta) in
  set_selected_row_for_tab interaction tab selected

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

let summary_value snapshot prefix =
  match summary_line snapshot prefix with
  | None -> None
  | Some line ->
      let prefix_len = String.length prefix in
      Some (String.sub line prefix_len (String.length line - prefix_len) |> Util.trim)

let project_title snapshot =
  match summary_value snapshot "Workspace Repository:" with
  | Some title when title <> "" -> title
  | _ -> "Symphony"

let total_tokens_line snapshot =
  option_value ~default:"Total tokens: unavailable" (summary_line snapshot "Total tokens:")

let count_active state rows = rows |> List.filter (is_state state) |> List.length

let next_queue_row snapshot = List.find_opt (is_state "pending") snapshot.Projection.queue

let task_row_line ?(prefix = "") (row : Projection.task_row) =
  let base = Printf.sprintf "%s%s %s %s" prefix (state_token row.state) row.id row.title in
  match row.detail with None -> base | Some detail -> base ^ " - " ^ shorten detail

let row_marker selected index = if selected = index then "> " else "  "

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

let filter_line interaction =
  let query = filter_query interaction in
  if query = "" then [] else [ "Filter: " ^ query ]

let task_separator_line width = "  " ^ String.make (min 72 (max 12 (width - 2))) '-'

let rec intersperse separator = function
  | [] -> []
  | [ line ] -> [ line ]
  | line :: rest -> line :: separator :: intersperse separator rest

let tasks_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let active_rows = visible_active_rows snapshot interaction in
  let active_lines =
    match active_rows with
    | [] when filter_query interaction <> "" -> [ "No active rows match the current filter." ]
    | [] -> [ idle_home_line snapshot.mode ]
    | rows ->
        rows
        |> List.mapi (fun index row -> task_row_line ~prefix:(row_marker interaction.selected_rows.active index) row)
        |> intersperse (task_separator_line width)
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
    @ filter_line interaction @ active_lines @ next_lines @ error_lines
  in
  { title = "Tasks"; lines = wrap_lines ~width lines }

let readiness_lines ~width ~selected readiness =
  readiness
  |> List.mapi (fun index (row : Projection.readiness_row) ->
         wrap_lines ~width
           [
             Printf.sprintf "%sREADINESS GAP %d requirement: %s" (row_marker selected index) (index + 1)
               row.requirement;
             "Remediation: " ^ row.remediation;
           ])
  |> List.concat

let attention_lines ~width ~selected active =
  active
  |> List.mapi (fun index row ->
         let lines =
           task_row_line ~prefix:(row_marker selected index) row
           ::
           (match row.error with Some error -> [ "Current error: " ^ shorten error ] | None -> [])
         in
         wrap_lines ~width lines)
  |> List.concat

let readiness_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let readiness = readiness_lines ~width ~selected:interaction.selected_rows.readiness (visible_readiness_rows snapshot interaction) in
  let lines =
    match readiness with
    | [] when filter_query interaction <> "" -> [ "No Readiness Gaps match the current filter." ]
    | [] -> [ "No Readiness Gaps." ]
    | readiness -> readiness
  in
  { title = "Readiness"; lines }

let attention_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let attention =
    attention_lines ~width ~selected:interaction.selected_rows.attention
      (visible_attention_rows snapshot interaction)
  in
  let lines =
    match attention with
    | [] when filter_query interaction <> "" -> [ "No task attention rows match the current filter." ]
    | [] -> [ "No task attention conditions." ]
    | attention -> attention
  in
  { title = "Needs attention"; lines }

let split_detail detail =
  detail |> String.split_on_char '|' |> List.map Util.trim |> List.filter (fun item -> item <> "")

let detail_items row = match row.Projection.detail with None -> [] | Some detail -> split_detail detail

let detail_group prefixes items =
  List.filter (fun item -> List.exists (fun prefix -> starts_with item prefix) prefixes) items

let optional_join label items = match items with [] -> [] | items -> [ label ^ String.concat " | " items ]

let matching_active_task snapshot (row : Projection.task_row) =
  List.find_opt (fun (active : Projection.task_row) -> active.id = row.id) snapshot.Projection.active

let queue_expansion_lines snapshot (row : Projection.task_row) =
  let task_line = Printf.sprintf "    Task: %s %s" row.id row.title in
  match matching_active_task snapshot row with
  | Some active ->
      let items = detail_items active in
      let stage_items = detail_group [ "stage agent "; "stage states "; "last event "; "last message " ] items in
      let stage_line =
        match stage_items with
        | [] -> "    Stage: " ^ state_token active.state
        | stage_items -> "    Stage: " ^ String.concat " | " stage_items
      in
      [ task_line; stage_line ]
  | None -> [ task_line; "    Stage: " ^ state_token row.state ]

let queue_row_lines snapshot interaction index row =
  let line = queue_row_line row |> fun line -> row_marker interaction.selected_rows.queue index ^ line in
  match interaction.expanded_queue_id with
  | Some id when id = row.Projection.id -> line :: queue_expansion_lines snapshot row
  | _ -> [ line ]

let queue_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match visible_queue_rows snapshot interaction with
    | [] when filter_query interaction <> "" -> [ "No Ordered Queue rows match the current filter." ]
    | [] -> [ "No Ordered Queue state present." ]
    | queue ->
        let next =
          match next_queue_row snapshot with Some row -> [ "Next work: " ^ queue_row_line ~next:true row ] | None -> []
        in
        next @ (List.mapi (queue_row_lines snapshot interaction) queue |> List.concat)
  in
  { title = "Queue"; lines = wrap_lines ~width lines }

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

let selected_task ?(interaction = default_interaction) (snapshot : Projection.t) =
  let rows, selected =
    match interaction.active_tab with
    | Attention -> (visible_attention_rows snapshot interaction, interaction.selected_rows.attention)
    | _ -> (visible_active_rows snapshot interaction, interaction.selected_rows.active)
  in
  list_nth_opt rows selected

let task_detail_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match selected_task ~interaction snapshot with
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

let help_commands =
  [
    ("q", "quit Terminal Console");
    ("Tab / h/l / Left/Right", "switch tabs");
    ("Up/Down / j/k", "move selectable rows");
    ("Space", "expand selected Queue task stage");
    ("/", "search visible rows");
    ("r", "refresh latest in-memory Runtime State snapshot");
    ("w", "show Web Dashboard handoff");
    ("o", "inspect selected local path");
    ("Esc / ?", "close this modal");
  ]

let help_lines = List.map (fun (key, label) -> key ^ " " ^ label) help_commands

let safe_aids_panel ?(interaction = default_interaction) (snapshot : Projection.t) =
  let aids =
    visible_safe_aids snapshot interaction
    |> List.mapi (fun index aid -> row_marker interaction.selected_rows.safe_aid index ^ safe_aid_label aid)
  in
  let lines = aids in
  { title = "Safe Aids"; lines }

let ends_with ~suffix text =
  let suffix_len = String.length suffix in
  let text_len = String.length text in
  suffix_len <= text_len && String.sub text (text_len - suffix_len) suffix_len = suffix

let is_path_token token =
  let is_url = starts_with token "http://" || starts_with token "https://" in
  (not is_url)
  && (starts_with token "/" || starts_with token "./" || starts_with token "../"
     || starts_with token ".symphony/" || starts_with token "apps/" || starts_with token "docs/"
     || String.contains token '/' || ends_with ~suffix:"/..." token)

let split_trailing_log_punctuation token =
  let len = String.length token in
  if len = 0 then (token, "")
  else
    match token.[len - 1] with
    | ',' | ';' -> (String.sub token 0 (len - 1), String.make 1 token.[len - 1])
    | _ -> (token, "")

let join_path_components components = String.concat "/" components

let rec suffix_from_component marker = function
  | component :: _ as suffix when component = marker -> Some suffix
  | _ :: rest -> suffix_from_component marker rest
  | [] -> None

let last_path_components count components =
  let rec drop count items =
    if count <= 0 then items
    else match items with [] -> [] | _ :: rest -> drop (count - 1) rest
  in
  let extra = List.length components - count in
  drop extra components

let compact_absolute_path components =
  let rec from_runtime_dir = function
    | root :: ((".symphony" | ".compozy") as runtime_dir) :: rest ->
        Some (root :: runtime_dir :: rest)
    | _ :: rest -> from_runtime_dir rest
    | [] -> None
  in
  match from_runtime_dir components with
  | Some suffix -> join_path_components suffix
  | None -> (
      let cwd_root = Filename.basename (Sys.getcwd ()) in
      match suffix_from_component cwd_root components with
      | Some suffix -> join_path_components suffix
      | None -> (
          match last_path_components 3 components with
          | [] -> "/"
          | suffix -> join_path_components suffix))

let compact_relative_path components =
  match components with
  | _ :: _ -> join_path_components components
  | [] -> "."

let compact_path_token token =
  let body, punctuation = split_trailing_log_punctuation token in
  if not (is_path_token body) then token
  else
    let components = body |> String.split_on_char '/' |> List.filter (fun part -> part <> "") in
    let compact =
      if starts_with body "/" then compact_absolute_path components else compact_relative_path components
    in
    compact ^ punctuation

let compact_log_token token =
  match String.index_opt token '=' with
  | Some index when index > 0 ->
      let key = String.sub token 0 index in
      let value = String.sub token (index + 1) (String.length token - index - 1) in
      key ^ "=" ^ if is_path_token value then compact_path_token value else value
  | _ -> if is_path_token token then compact_path_token token else token

let compact_log_line line =
  line |> String.split_on_char ' '
  |> List.filter (fun token -> token <> "")
  |> List.map compact_log_token |> String.concat " "

let logs_window_size = function None -> None | Some size -> Some (max 1 (size.rows - 10))

let logs_panel ?terminal_size ?(interaction = default_interaction) logs =
  let width = content_width terminal_size in
  let lines =
    match sanitize_logs logs with
    | [] -> [ "No background logs captured yet." ]
    | logs ->
        let logs = List.rev logs |> List.map compact_log_line in
        let offset = min (max 0 interaction.logs_scroll) (max 0 (List.length logs - 1)) in
        let logs = drop_count offset logs in
        let logs =
          match logs_window_size terminal_size with None -> logs | Some limit -> take_count limit logs
        in
        logs
  in
  { title = "Logs"; lines = wrap_lines ~width lines }

let contextual_footer ?(interaction = default_interaction) handoff_available =
  if interaction.filter_active then
    Printf.sprintf "search: %s | type to filter, Backspace edit, Enter apply, Esc cancel"
      (if interaction.filter_text = "" then "<empty>" else interaction.filter_text)
 else
    let handoff = if handoff_available then "[w]web" else "[w]unavailable" in
    let movement =
      match interaction.active_tab with
      | Logs -> "[j/k]scroll"
      | Queue -> "[j/k]rows [Space]expand"
      | _ -> "[j/k]rows"
    in
    String.concat " | "
      [
        "[q]quit";
        "[Tab]tabs";
        "[h/l]tabs";
        movement;
        "[/]search";
        "[r]refresh";
        handoff;
        "[o]path";
        "[?]help";
      ]

let render_snapshot ?terminal_size ?(interaction = default_interaction) ?(logs = []) (snapshot : Projection.t) =
  let interaction = clamp_interaction snapshot interaction in
  let tabs = tab_order |> List.map tab_title |> String.concat " | " in
  let status = status_badge_label snapshot.mode in
  match terminal_size with
  | Some size when terminal_too_small size ->
      {
        heading = project_title snapshot;
        status_label = status;
        tabs;
        subheading = "Resize required";
        panels = [ { title = "Minimum Size"; lines = minimum_size_lines size } ];
        footer = "q quit | resize terminal";
      }
  | _ ->
      {
        heading = project_title snapshot;
        status_label = status;
        tabs;
        subheading = Printf.sprintf "generated %s" snapshot.generated_at;
        panels =
          [
            queue_panel ?terminal_size ~interaction snapshot;
            logs_panel ?terminal_size ~interaction logs;
            tasks_panel ?terminal_size ~interaction snapshot;
            readiness_panel ?terminal_size ~interaction snapshot;
            attention_panel ?terminal_size ~interaction snapshot;
          ];
        footer = contextual_footer ~interaction true;
      }

let rendered_lines rendered =
  rendered.heading :: rendered.status_label :: rendered.tabs :: rendered.subheading
  :: (List.concat_map (fun panel -> panel.title :: panel.lines) rendered.panels @ [ rendered.footer ])

let panel_lines rendered title =
  match List.find_opt (fun panel -> panel.title = title) rendered.panels with
  | Some panel -> panel.lines
  | None -> []

let transition ?(safe_aids = []) ?(quit = false) model = { model; safe_aids; quit }

let selection_status snapshot interaction =
  let count = row_count_for_tab snapshot interaction interaction.active_tab in
  let title = focused_tab_title interaction.active_tab in
  if count = 0 then title ^ ": no selectable rows"
  else Printf.sprintf "%s row %d of %d" title (selected_row_for_tab interaction interaction.active_tab + 1) count

let update_interaction ?status_message model interaction =
  let interaction = clamp_interaction model.snapshot interaction in
  { model with interaction; status_message }

let set_filter_text model text =
  let filter_text = Projection.sanitize text in
  let interaction = { model.interaction with filter_text } in
  let model =
    update_interaction
      ~status_message:
        (if filter_text = "" then "Search filter cleared" else "Search filter: " ^ filter_text)
      model interaction
  in
  transition model

let append_filter_char model c =
  set_filter_text model (model.interaction.filter_text ^ String.make 1 c)

let remove_filter_char model =
  let text = model.interaction.filter_text in
  let next = if text = "" then "" else String.sub text 0 (String.length text - 1) in
  set_filter_text model next

let web_handoff_message handoff = "Web Dashboard: " ^ handoff.command ^ " | " ^ handoff.url

let normalize_root root = try Some (Unix.realpath root) with _ -> None

let path_inside ~root path =
  path = root
  ||
  let prefix = if String.length root > 0 && root.[String.length root - 1] = '/' then root else root ^ "/" in
  starts_with path prefix

let validate_local_path ~local_surfaces path =
  let path = Projection.sanitize path in
  if path = "" then Error "No local path selected for inspection."
  else
    let surfaces =
      local_surfaces
      |> List.filter_map (fun surface ->
             match normalize_root surface.root with
             | Some root -> Some { surface with root }
             | None -> None)
    in
    match surfaces with
    | [] -> Error "No Workspace Repository local inspection surfaces are configured."
    | surfaces ->
        let candidates =
          if Filename.is_relative path then List.map (fun surface -> (surface, Filename.concat surface.root path)) surfaces
          else List.map (fun surface -> (surface, path)) surfaces
        in
        let rec loop outside_seen = function
          | [] ->
              if outside_seen then Error ("Local path is outside allowed Workspace Repository surfaces: " ^ path)
              else Error ("Local path is unavailable for read-only inspection: " ^ path)
          | (surface, candidate) :: rest -> (
              match Unix.realpath candidate with
              | resolved when path_inside ~root:surface.root resolved -> Ok resolved
              | _ -> loop true rest
              | exception _ -> loop outside_seen rest)
        in
        loop false candidates

let selected_safe_aid model =
  visible_safe_aids model.snapshot model.interaction |> fun aids ->
  list_nth_opt aids model.interaction.selected_rows.safe_aid

let selected_local_path model =
  match selected_safe_aid model with
  | Some (Projection.Show_path path) -> Some path
  | _ -> (
      match selected_task ~interaction:model.interaction model.snapshot with
      | Some { Projection.context_status = Some { diagnostics_path = Some path; _ }; _ } -> Some path
      | _ ->
          model.snapshot.Projection.safe_aids
          |> List.find_map (function Projection.Show_path path -> Some path | _ -> None))

let inspect_selected_path ~local_surfaces model =
  match selected_local_path model with
  | None -> transition { model with status_message = Some "No local path is available for the current selection." }
  | Some path -> (
      match validate_local_path ~local_surfaces path with
      | Error message -> transition { model with status_message = Some message }
      | Ok path ->
          transition
            { model with status_message = Some ("Inspect path read-only: " ^ path) }
            ~safe_aids:[ Projection.Show_path path ])

let logs_scroll_step model =
  match logs_window_size model.terminal_size with Some step -> step | None -> 10

let move_log_scroll delta model =
  let log_count = List.length (sanitize_logs model.logs) in
  let max_scroll = max 0 (log_count - 1) in
  let logs_scroll = max 0 (min max_scroll (model.interaction.logs_scroll + delta)) in
  let interaction = { model.interaction with logs_scroll } in
  let status_message =
    if log_count = 0 then "Logs: no captured lines"
    else Printf.sprintf "Logs line %d of %d" (logs_scroll + 1) log_count
  in
  transition (update_interaction ~status_message model interaction)

let selected_queue_row model =
  visible_queue_rows model.snapshot model.interaction
  |> fun rows -> list_nth_opt rows model.interaction.selected_rows.queue

let toggle_queue_expansion model =
  match selected_queue_row model with
  | None -> transition { model with status_message = Some "Queue: no row selected" }
  | Some row ->
      let expanded_queue_id =
        match model.interaction.expanded_queue_id with Some id when id = row.id -> None | _ -> Some row.id
      in
      let status_message =
        match expanded_queue_id with
        | Some _ -> Printf.sprintf "Queue details: %s %s" row.id row.title
        | None -> "Queue details hidden"
      in
      let interaction = { model.interaction with expanded_queue_id } in
      transition (update_interaction ~status_message model interaction)

let apply_key ?(web_handoff = default_web_handoff ()) ?(local_surfaces = []) key model =
  if model.interaction.filter_active then
    match key with
    | Escape_key ->
        let interaction = { model.interaction with filter_active = false; filter_text = "" } in
        transition (update_interaction ~status_message:"Search cancelled" model interaction)
    | Enter_key ->
        let interaction = { model.interaction with filter_active = false } in
        transition (update_interaction ~status_message:"Search applied" model interaction)
    | Backspace_key -> remove_filter_char model
    | Space_key -> append_filter_char model ' '
    | Character c -> append_filter_char model c
    | _ -> transition model
  else if model.interaction.help_visible then
    match key with
    | Character 'q' -> transition ~quit:true model
    | Character '?' | Escape_key ->
        let interaction = { model.interaction with help_visible = false } in
        transition (update_interaction ~status_message:"Commands hidden" model interaction)
    | _ -> transition model
  else
    match key with
    | Character 'q' -> transition ~quit:true model
    | Escape_key -> transition ~quit:true model
    | Character '?' ->
        let interaction = { model.interaction with help_visible = true } in
        transition (update_interaction ~status_message:"Commands shown" model interaction)
    | Character '/' ->
        let interaction = { model.interaction with filter_active = true } in
        transition (update_interaction ~status_message:"Search visible rows" model interaction)
    | Character 'r' ->
        transition
          { model with status_message = Some "Refreshed latest in-memory Runtime State snapshot" }
          ~safe_aids:[ Projection.Refresh_view ]
    | Character 'w' ->
        transition { model with status_message = Some (web_handoff_message web_handoff) }
          ~safe_aids:[ Projection.Show_web_handoff ]
    | Character 'o' -> inspect_selected_path ~local_surfaces model
    | Character 'h' | Left_key ->
        let interaction = move_tab (-1) model.interaction in
        transition
          (update_interaction ~status_message:("Tab: " ^ focused_tab_title interaction.active_tab) model interaction)
    | Character 'l' | Right_key | Tab_key ->
        let interaction = move_tab 1 model.interaction in
        transition
          (update_interaction ~status_message:("Tab: " ^ focused_tab_title interaction.active_tab) model interaction)
    | Character 'j' | Down_key ->
        if model.interaction.active_tab = Logs then move_log_scroll 1 model
        else
          let interaction = move_row 1 model.snapshot model.interaction in
          transition (update_interaction ~status_message:(selection_status model.snapshot interaction) model interaction)
    | Character 'k' | Up_key ->
        if model.interaction.active_tab = Logs then move_log_scroll (-1) model
        else
          let interaction = move_row (-1) model.snapshot model.interaction in
          transition (update_interaction ~status_message:(selection_status model.snapshot interaction) model interaction)
    | Page_down_key ->
        if model.interaction.active_tab = Logs then move_log_scroll (logs_scroll_step model) model else transition model
    | Page_up_key ->
        if model.interaction.active_tab = Logs then move_log_scroll (-(logs_scroll_step model)) model else transition model
    | Space_key | Character ' ' ->
        if model.interaction.active_tab = Queue then toggle_queue_expansion model else transition model
    | Character _ | Enter_key | Backspace_key -> transition model

let render_model model =
  let rendered =
    render_snapshot ?terminal_size:model.terminal_size ~interaction:model.interaction ~logs:model.logs model.snapshot
  in
  let footer =
    match model.status_message with None -> rendered.footer | Some message -> message ^ " | " ^ rendered.footer
  in
  { rendered with footer }

let nonempty_lines fallback = function [] -> [ fallback ] | lines -> lines

let span ?(attrs = []) slot text =
  Span.make ~style:Style.(make ~fg:(Theme.dark slot) ~attrs ()) text

let theme_slot_of_tone = function
  | Components.Neutral -> Theme.Fg_muted
  | Components.Accent -> Theme.Accent_primary
  | Components.Info -> Theme.Status_info
  | Components.Success -> Theme.Status_success
  | Components.Warning -> Theme.Status_warning
  | Components.Error -> Theme.Status_error

let toned_span ?(attrs = [ Attr.Bold ]) tone text = span ~attrs (theme_slot_of_tone tone) text

let tab_tone = function
  | Queue -> Components.Accent
  | Logs -> Components.Info
  | Tasks -> Components.Success
  | Readiness -> Components.Warning
  | Attention -> Components.Error

let log_default text = span Theme.Fg_default text
let log_muted ?(attrs = [ Attr.Dim ]) text = span ~attrs Theme.Fg_muted text
let log_emphasis text = span ~attrs:[ Attr.Bold ] Theme.Fg_emphasis text
let log_info text = span ~attrs:[ Attr.Bold ] Theme.Status_info text
let log_success text = span ~attrs:[ Attr.Bold ] Theme.Status_success text
let log_warning text = span ~attrs:[ Attr.Bold ] Theme.Status_warning text
let log_error text = span ~attrs:[ Attr.Bold ] Theme.Status_error text
let log_accent text = span ~attrs:[ Attr.Bold ] Theme.Accent_primary text
let log_secondary text = span ~attrs:[ Attr.Bold ] Theme.Accent_secondary text

let lowercase_token token =
  token
  |> String.lowercase_ascii
  |> String.map (function ',' | ';' -> ' ' | c -> c)
  |> Util.trim

let tone_of_keyword = function
  | "running" | "ready" | "completed" | "ok" | "success" | "succeeded" | "active"
  | "merged" ->
      Some Components.Success
  | "retrying" | "pending" | "warning" | "skipped" | "draft" | "not-ready"
  | "not_ready" | "kept" ->
      Some Components.Warning
  | "attention" | "blocked" | "failed" | "failure" | "error" | "readiness_blocked" ->
      Some Components.Error
  | "checking" | "generated" | "created" | "present" | "in_progress" | "in_execution"
  | "in_review" | "in_planning" | "handoff_completed" | "handoff_attempting"
  | "handoff_failed" ->
      Some Components.Info
  | _ -> None

let split_first_word text =
  match String.index_opt text ' ' with
  | Some index ->
      let first = String.sub text 0 index in
      let rest = String.sub text (index + 1) (String.length text - index - 1) in
      Some (first, rest)
  | None when text <> "" -> Some (text, "")
  | None -> None

let is_timestamp_token token =
  let token = lowercase_token token in
  let len = String.length token in
  len >= 5
  && String.contains token ':'
  && String.for_all (function '0' .. '9' | ':' -> true | _ -> false) token

let is_issue_token token =
  let token = Projection.sanitize token in
  token <> ""
  &&
  match token.[0] with
  | '#' -> true
  | _ -> starts_with token "ISSUE-" || starts_with token "MB-"

let is_number_like token =
  let token = lowercase_token token in
  token <> ""
  &&
  String.for_all
    (function
      | '0' .. '9' | '.' | '%' | '/' -> true
      | _ -> false)
    token

let value_span value =
  let display = if is_path_token value then compact_path_token value else value in
  match lowercase_token value with
  | "completed" | "created" | "ready" | "running" | "success" | "ok" -> log_success display
  | "failed" | "failure" | "error" | "blocked" -> log_error display
  | "retrying" | "checking" | "attention" | "skipped" | "kept" -> log_warning display
  | "terminal_console" | "compozy_tasks" | "github" | "minibeads" -> log_secondary display
  | _ when is_path_token value -> log_muted display
  | _ -> log_default display

let key_value_spans token =
  match String.index_opt token '=' with
  | Some index when index > 0 ->
      let key = String.sub token 0 index in
      let value = String.sub token (index + 1) (String.length token - index - 1) in
      Some [ log_muted ~attrs:[] key; log_muted ~attrs:[] "="; value_span value ]
  | _ -> None

let token_spans token =
  match key_value_spans token with
  | Some spans -> spans
  | None -> (
      match lowercase_token token with
      | token when token = "" -> [ log_default token ]
      | "bootstrap" | "startup" | "poll" | "event" -> [ log_accent token ]
      | "created" | "ready" | "running" | "completed" | "success" | "ok" -> [ log_success token ]
      | "present" | "checking" -> [ log_info token ]
      | "kept" | "retrying" | "skipped" | "attention" | "blocked" -> [ log_warning token ]
      | "failed" | "error" | "reason" -> [ log_error token ]
      | "tracker" | "mode" | "runtime_home" | "workspace_root" | "project_number" -> [ log_secondary token ]
      | _ when is_timestamp_token token -> [ log_info token ]
      | _ when is_path_token token -> [ log_muted (compact_path_token token) ]
      | _ -> [ log_default token ])

let log_line_spans line =
  line |> String.split_on_char ' '
  |> List.filter (fun token -> token <> "")
  |> List.mapi (fun index token ->
         let prefix = if index = 0 then [] else [ log_muted ~attrs:[] " " ] in
         prefix @ token_spans token)
  |> List.concat

let content_label_tone label =
  let label = String.lowercase_ascii label in
  if contains_substring label "error" || contains_substring label "attention" then Components.Error
  else if contains_substring label "readiness" || contains_substring label "remediation" then Components.Warning
  else if contains_substring label "status" || contains_substring label "active" then Components.Success
  else if contains_substring label "updated" || contains_substring label "progress" then Components.Info
  else Components.Accent

let content_prefix_spans line =
  if starts_with line "> " then ([ toned_span Components.Accent ">"; log_muted ~attrs:[] " " ], String.sub line 2 (String.length line - 2))
  else
    let rec take_spaces index =
      if index < String.length line && line.[index] = ' ' then take_spaces (index + 1) else index
    in
    let prefix_len = take_spaces 0 in
    if prefix_len = 0 then ([], line)
    else ([ log_muted ~attrs:[] (String.sub line 0 prefix_len) ], String.sub line prefix_len (String.length line - prefix_len))

let clause_prefixes =
  [
    ("issue state ", Components.Info);
    ("stage agent ", Components.Accent);
    ("stage states ", Components.Success);
    ("last event ", Components.Info);
    ("last message ", Components.Info);
    ("harness ", Components.Accent);
    ("harness kind ", Components.Accent);
    ("branch ", Components.Info);
    ("attempt ", Components.Warning);
    ("due ", Components.Info);
    ("status ", Components.Info);
    ("time ", Components.Info);
    ("tokens ", Components.Accent);
    ("reason ", Components.Warning);
    ("lifecycle ", Components.Success);
    ("dispatch state ", Components.Info);
    ("pr readiness ", Components.Warning);
    ("handoff ", Components.Accent);
    ("current step ", Components.Info);
    ("run id ", Components.Info);
    ("task ", Components.Accent);
    ("stage ", Components.Accent);
  ]

let rec value_token_spans token =
  let normalized = lowercase_token token in
  match tone_of_keyword normalized with
  | Some tone -> [ toned_span tone token ]
  | None when normalized = "|" || normalized = "-" -> [ log_muted ~attrs:[] token ]
  | None when is_issue_token token -> [ log_secondary token ]
  | None when starts_with token "symphony/" || starts_with token "codex/" -> [ log_secondary token ]
  | None when is_timestamp_token token || (String.contains token 'T' && String.contains token ':') ->
      [ log_info token ]
  | None when is_number_like token -> [ log_emphasis token ]
  | None when is_path_token token -> [ log_muted (compact_path_token token) ]
  | None when String.length token > 1 && token = String.uppercase_ascii token -> [ log_emphasis token ]
  | None -> [ log_default token ]

and tokenized_value_spans text =
  text |> String.split_on_char ' '
  |> List.filter (fun token -> token <> "")
  |> List.mapi (fun index token ->
         let prefix = if index = 0 then [] else [ log_muted ~attrs:[] " " ] in
         prefix @ value_token_spans token)
  |> List.concat

and clause_spans clause =
  let lowered = String.lowercase_ascii clause in
  match List.find_opt (fun (prefix, _) -> starts_with lowered prefix) clause_prefixes with
  | Some (prefix, tone) ->
      let prefix_len = String.length prefix in
      let label = String.sub clause 0 prefix_len |> Util.trim in
      let value = String.sub clause prefix_len (String.length clause - prefix_len) |> Util.trim in
      [ toned_span tone label; log_muted ~attrs:[] " " ] @ tokenized_value_spans value
  | None -> (
      match split_first_word clause with
      | Some (first, rest) -> (
          match tone_of_keyword (lowercase_token first) with
          | Some tone ->
              [ toned_span tone first ]
              @ if rest = "" then [] else [ log_muted ~attrs:[] " " ] @ tokenized_value_spans rest
          | None -> tokenized_value_spans clause)
      | None -> [])

let value_spans text =
  text |> String.split_on_char '|'
  |> List.map Util.trim
  |> List.filter (fun clause -> clause <> "")
  |> List.mapi (fun index clause ->
         let prefix = if index = 0 then [] else [ log_muted ~attrs:[] " | " ] in
         prefix @ clause_spans clause)
  |> List.concat

let content_line_spans line =
  let prefix_spans, body = content_prefix_spans line in
  let body = Projection.sanitize body in
  let body_spans =
    if body = "" then []
    else if String.for_all (fun c -> c = '-') body then [ log_muted body ]
    else
      match String.index_opt body ':' with
      | Some index when index > 0 ->
          let label = String.sub body 0 index |> Util.trim in
          let value = String.sub body (index + 1) (String.length body - index - 1) |> Util.trim in
          [ toned_span (content_label_tone label) (label ^ ":") ]
          @ if value = "" then []
            else [ log_muted ~attrs:[] " " ] @ value_spans value
      | _ -> (
          match split_first_word body with
          | Some ("No", rest) -> [ log_muted ("No" ^ if rest = "" then "" else " " ^ rest) ]
          | Some ("Resize", rest) -> [ log_muted ("Resize" ^ if rest = "" then "" else " " ^ rest) ]
          | _ -> value_spans body)
  in
  prefix_spans @ body_spans

let line_nodes ?(spaced = false) lines =
  lines |> nonempty_lines "None"
  |> List.map (fun line ->
         Components.text
           ~style:
             Style.(
               make ~fg:(Theme.dark Theme.Fg_default) ~height:(Cells 1)
                 ~margin:(spacing ~bottom:(if spaced then 1 else 0) ()) ())
           line)

let content_line_nodes lines =
  lines |> nonempty_lines "None"
  |> List.map (fun line ->
         Components.rich_text
           ~style:
             Style.(
               make ~height:(Cells 1) ~fg:(Theme.dark Theme.Fg_default)
                 ~margin:(spacing ~bottom:1 ()) ())
           (content_line_spans line))

let log_line_nodes lines =
  lines |> nonempty_lines "No background logs captured yet."
  |> List.map (fun line ->
         Components.rich_text
           ~style:Style.(make ~height:(Cells 1) ~fg:(Theme.dark Theme.Fg_default) ())
           (log_line_spans line))

let command_help_row (key, label) =
  Components.rich_text
    ~style:Style.(make ~height:(Cells 1) ())
    [
      span ~attrs:[ Attr.Bold ] Theme.Accent_primary key;
      span ~attrs:[] Theme.Fg_muted "  ";
      span ~attrs:[] Theme.Fg_default label;
    ]

let help_modal_node () =
  Components.modal ~id:"terminal-console-command-modal" ~tone:Components.Info
    ~style:Style.(make ~width:(Cells 72) ~height:(Cells 14) ())
    "Commands"
    [
      Components.column
        ~style:Style.(make ~flex_grow:1. ())
        (List.map command_help_row help_commands);
    ]

let find_panel rendered title = List.find_opt (fun panel -> panel.title = title) rendered.panels

let active_panel rendered interaction =
  match find_panel rendered (tab_title interaction.active_tab) with
  | Some panel -> panel
  | None -> { title = tab_title interaction.active_tab; lines = [ "No content available." ] }

let footer_segment_spans text =
  let text = Util.trim text in
  match String.index_opt text ']' with
  | Some index when starts_with text "[" ->
      let key = String.sub text 1 (index - 1) in
      let label = String.sub text (index + 1) (String.length text - index - 1) in
      [ toned_span Components.Accent ("[" ^ key ^ "]"); span Theme.Fg_muted label ]
  | _ -> content_line_spans text

let footer_spans text =
  text |> String.split_on_char '|'
  |> List.mapi (fun index segment ->
         let prefix = if index = 0 then [] else [ span Theme.Fg_muted " | " ] in
         prefix @ footer_segment_spans segment)
  |> List.concat

let footer_node rendered =
  Components.rich_text
    ~style:
      Style.(
        make ~height:(Cells 1) ~width:(Percent 1.) ~bg:(Theme.dark Theme.Bg_surface)
          ~fg:(Theme.dark Theme.Fg_default) ())
    (footer_spans rendered.footer)

let tab_node active tab =
  let tone = tab_tone tab in
  let attrs = if active then [ Attr.Bold; Attr.Underline ] else [ Attr.Dim ] in
  Components.rich_text
    ~style:Style.(make ~height:(Cells 1) ())
    [
      toned_span ~attrs tone (tab_title tab);
    ]

let view model =
  let rendered = render_model model in
  let panel = active_panel rendered model.interaction in
  let active_tab = model.interaction.active_tab in
  let children =
    [
      Components.header ~subtitle:rendered.subheading
        ~badges:
          [ (tab_tone active_tab, tab_title active_tab); (status_badge_tone model.snapshot.mode, rendered.status_label) ]
        rendered.heading;
      Components.row
        ~style:
          Style.(
            make ~height:(Cells 1) ~align_items:Align_center
              ~padding:(spacing_xy ~x:2 ~y:0) ~bg:(Theme.dark Theme.Bg_surface) ())
        [
          Components.row ~gap:2
            (List.map (fun tab -> tab_node (tab = active_tab) tab) tab_order);
        ];
      Components.panel panel.title ~tone:(tab_tone active_tab)
        ~style:
          Style.(
            make ~flex_grow:1. ~flex_shrink:1. ~min_height:(Cells 0)
              ~bg:(Theme.dark Theme.Bg_surface) ())
        [
          Components.scroll_box
            ~style:
              Style.(
                make ~flex_grow:1. ~flex_shrink:1. ~min_height:(Cells 0)
                  ~flex_direction:Column ~bg:(Theme.dark Theme.Bg_surface) ())
            (if model.interaction.active_tab = Logs then log_line_nodes panel.lines
             else content_line_nodes panel.lines);
        ];
      footer_node rendered;
    ]
  in
  let children = if model.interaction.help_visible then children @ [ help_modal_node () ] else children in
  Components.box
    ~style:
      Style.(
        make ~width:(Percent 1.) ~height:(Percent 1.) ~flex_direction:Column
          ~padding:(spacing_xy ~x:1 ~y:0) ~gap:1 ~bg:(Theme.dark Theme.Bg_base)
          ~fg:(Theme.dark Theme.Fg_default) ())
    children

let init runtime () = (initial_model ~logs:runtime.initial_logs runtime.initial_state, ())

let update runtime msg model =
  match msg with
  | Snapshot_received state ->
      let snapshot = Projection.of_runtime_state state in
      let interaction = clamp_interaction snapshot model.interaction in
      ( { model with
          snapshot;
          status_label = status_label snapshot.mode;
          status_message = None;
          interaction;
        },
        false )
  | Key_press key ->
      let transition =
        apply_key ~web_handoff:runtime.web_handoff ~local_surfaces:runtime.local_surfaces key model
      in
      List.iter runtime.safe_aid transition.safe_aids;
      (transition.model, transition.quit)
  | Resize { columns; rows } -> ({ model with terminal_size = Some { columns; rows } }, false)

let ui_key_of_tui_key (key : Key.event) =
  match key.name with
  | "return" -> Some Enter_key
  | "backspace" | "delete" -> Some Backspace_key
  | "escape" -> Some Escape_key
  | "up" -> Some Up_key
  | "down" -> Some Down_key
  | "left" -> Some Left_key
  | "right" -> Some Right_key
  | "tab" -> Some Tab_key
  | "space" -> Some Space_key
  | "pageup" -> Some Page_up_key
  | "pagedown" -> Some Page_down_key
  | name when (not key.ctrl) && (not key.alt) && String.length name = 1 -> Some (Character name.[0])
  | _ -> None

type live_state = {
  mutex : Mutex.t;
  mutable model : model;
  mutable quit : bool;
}

let create_live_state model = { mutex = Mutex.create (); model; quit = false }

let with_live_state live f =
  Mutex.lock live.mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock live.mutex) (fun () -> f live)

let update_live runtime live msg =
  with_live_state live (fun live ->
      let model, quit = update runtime msg live.model in
      live.model <- model;
      live.quit <- live.quit || quit)

let append_log_live live line =
  with_live_state live (fun live -> live.model <- append_log_line live.model line)

let close_noerr fd = try Unix.close fd with _ -> ()

let emit_log_line append line =
  let line = Projection.sanitize line in
  if line <> "" then append line

let read_fd_lines fd append =
  let bytes = Bytes.create 4096 in
  let pending = Buffer.create 4096 in
  let flush_pending () =
    if Buffer.length pending > 0 then (
      emit_log_line append (Buffer.contents pending);
      Buffer.clear pending)
  in
  let rec read_loop () =
    match Unix.read fd bytes 0 (Bytes.length bytes) with
    | 0 -> flush_pending ()
    | count ->
        for index = 0 to count - 1 do
          match Bytes.get bytes index with
          | '\n' ->
              emit_log_line append (Buffer.contents pending);
              Buffer.clear pending
          | '\r' ->
              if Buffer.length pending > 0 then Buffer.add_char pending ' '
          | c -> Buffer.add_char pending c
        done;
        read_loop ()
    | exception Unix.Unix_error ((Unix.EBADF | Unix.EINVAL), _, _) -> flush_pending ()
    | exception _ -> flush_pending ()
  in
  Fun.protect ~finally:(fun () -> close_noerr fd) read_loop

let with_stderr_capture append f =
  let original = Unix.dup Unix.stderr in
  let read_fd, write_fd = Unix.pipe () in
  let _reader =
    Thread.create
      (fun () -> read_fd_lines read_fd append)
      ()
  in
  let capture_active = ref false in
  Fun.protect
    ~finally:(fun () ->
      if !capture_active then (try Unix.dup2 original Unix.stderr with _ -> ());
      close_noerr original;
      close_noerr write_fd;
      close_noerr read_fd)
    (fun () ->
      Unix.dup2 write_fd Unix.stderr;
      capture_active := true;
      close_noerr write_fd;
      f ())

let current_terminal_size () =
  let viewport = Terminal.viewport () in
  { columns = viewport.Viewport.width; rows = viewport.height }

let render_once runtime live renderer =
  let size = current_terminal_size () in
  update_live runtime live (Resize size);
  let model = with_live_state live (fun live -> live.model) in
  Renderer.resize renderer ~width:size.columns ~height:size.rows;
  Renderer.set_root renderer (view model);
  Renderer.render renderer

let print_non_interactive model =
  render_model model |> rendered_lines |> List.iter print_endline

let run runtime =
  let initial_model, _ = init runtime () in
  if not (Terminal.is_interactive ()) then print_non_interactive initial_model
  else
    let live = create_live_state initial_model in
    let renderer = Renderer.create (view initial_model) in
    let fd = Unix.descr_of_in_channel stdin in
    Fun.protect
      ~finally:Terminal.leave_alternate
      (fun () ->
        Terminal.enter_alternate ();
        with_stderr_capture
          (fun line -> append_log_live live line)
          (fun () ->
            ignore
              (Thread.create
                 (fun () -> runtime.subscribe (fun state -> update_live runtime live (Snapshot_received state)))
                 ());
            Terminal.with_raw fd (fun () ->
                while not (with_live_state live (fun live -> live.quit)) do
                  render_once runtime live renderer;
                  match Unix.select [ fd ] [] [] 0.1 with
                  | [], _, _ -> ()
                  | _ -> (
                      match Key.read fd with
                      | Some key when key.ctrl && key.name = "c" ->
                          with_live_state live (fun live -> live.quit <- true)
                      | Some key ->
                          Option.iter (fun ui_key -> update_live runtime live (Key_press ui_key))
                            (ui_key_of_tui_key key)
                      | None -> ())
                done)))
