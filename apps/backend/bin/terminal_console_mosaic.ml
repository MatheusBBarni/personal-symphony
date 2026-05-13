open Mosaic

module Projection = Terminal_console_model

type web_handoff = { command : string; url : string }
type local_surface = { label : string; root : string }

type runtime = {
  initial_state : Runtime_state.t;
  subscribe : (Runtime_state.t -> unit) -> unit;
  safe_aid : Projection.safe_aid -> unit;
  web_handoff : web_handoff;
  local_surfaces : local_surface list;
}

type focused_panel = Active_work | Readiness_attention | Ordered_queue | Compozy_run | Task_detail | Safe_aids

type row_selection = {
  active : int;
  readiness : int;
  queue : int;
  safe_aid : int;
}

type interaction = {
  focused_panel : focused_panel;
  selected_rows : row_selection;
  filter_text : string;
  filter_active : bool;
  help_visible : bool;
}

type model = {
  snapshot : Projection.t;
  status_label : string;
  status_message : string option;
  terminal_size : terminal_size option;
  interaction : interaction;
}

and terminal_size = { columns : int; rows : int }

type panel = { title : string; lines : string list }

type rendered_snapshot = {
  heading : string;
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

type transition = {
  model : model;
  safe_aids : Projection.safe_aid list;
  quit : bool;
}

type msg = Snapshot_received of Runtime_state.t | Key_press of ui_key | Resize of terminal_size

let compile_anchor = "terminal-console-mosaic"
let minimum_terminal_size = { columns = 80; rows = 24 }
let default_web_handoff ?(port = 8080) () =
  { command = Printf.sprintf "symphony --web --port %d" port; url = Printf.sprintf "http://127.0.0.1:%d/" port }

let local_surface ~label ~root = { label = Projection.sanitize label; root }

let default_row_selection = { active = 0; readiness = 0; queue = 0; safe_aid = 0 }

let default_interaction =
  {
    focused_panel = Active_work;
    selected_rows = default_row_selection;
    filter_text = "";
    filter_active = false;
    help_visible = false;
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

let initial_model ?terminal_size state =
  let snapshot = Projection.of_runtime_state state in
  {
    snapshot;
    status_label = status_label snapshot.mode;
    status_message = None;
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

let focused_panel_title = function
  | Active_work -> "Active Work"
  | Readiness_attention -> "Readiness and Attention"
  | Ordered_queue -> "Ordered Queue"
  | Compozy_run -> "Compozy PRD Run"
  | Task_detail -> "Task Detail"
  | Safe_aids -> "Safe Aids"

let panel_order = [ Active_work; Readiness_attention; Ordered_queue; Compozy_run; Task_detail; Safe_aids ]

let panel_index panel =
  let rec loop index = function
    | [] -> 0
    | current :: rest -> if current = panel then index else loop (index + 1) rest
  in
  loop 0 panel_order

let panel_at index =
  let count = List.length panel_order in
  let normalized = (index mod count + count) mod count in
  List.nth panel_order normalized

let move_panel delta interaction =
  let focused_panel = panel_at (panel_index interaction.focused_panel + delta) in
  { interaction with focused_panel; filter_active = false }

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

let clamp_interaction snapshot interaction =
  let active = clamp_index (List.length (visible_active_rows snapshot interaction)) interaction.selected_rows.active in
  let readiness = clamp_index (List.length (visible_readiness_rows snapshot interaction)) interaction.selected_rows.readiness in
  let queue = clamp_index (List.length (visible_queue_rows snapshot interaction)) interaction.selected_rows.queue in
  let safe_aid = clamp_index (List.length (visible_safe_aids snapshot interaction)) interaction.selected_rows.safe_aid in
  { interaction with selected_rows = { active; readiness; queue; safe_aid } }

let row_count_for_panel snapshot interaction = function
  | Active_work | Task_detail -> List.length (visible_active_rows snapshot interaction)
  | Readiness_attention -> List.length (visible_readiness_rows snapshot interaction)
  | Ordered_queue -> List.length (visible_queue_rows snapshot interaction)
  | Compozy_run -> Option.fold ~none:0 ~some:(fun _ -> 1) snapshot.Projection.compozy
  | Safe_aids -> List.length (visible_safe_aids snapshot interaction)

let selected_row_for_panel interaction = function
  | Active_work | Task_detail -> interaction.selected_rows.active
  | Readiness_attention -> interaction.selected_rows.readiness
  | Ordered_queue -> interaction.selected_rows.queue
  | Compozy_run -> 0
  | Safe_aids -> interaction.selected_rows.safe_aid

let set_selected_row_for_panel interaction panel selected =
  let selected_rows =
    match panel with
    | Active_work | Task_detail -> { interaction.selected_rows with active = selected }
    | Readiness_attention -> { interaction.selected_rows with readiness = selected }
    | Ordered_queue -> { interaction.selected_rows with queue = selected }
    | Compozy_run -> interaction.selected_rows
    | Safe_aids -> { interaction.selected_rows with safe_aid = selected }
  in
  { interaction with selected_rows }

let move_row delta snapshot interaction =
  let panel = interaction.focused_panel in
  let count = row_count_for_panel snapshot interaction panel in
  let current = selected_row_for_panel interaction panel in
  let selected = clamp_index count (current + delta) in
  set_selected_row_for_panel interaction panel selected

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

let home_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let active_rows = visible_active_rows snapshot interaction in
  let active_lines =
    match active_rows with
    | [] when filter_query interaction <> "" -> [ "No active rows match the current filter." ]
    | [] -> [ idle_home_line snapshot.mode ]
    | rows -> List.mapi (fun index row -> task_row_line ~prefix:(row_marker interaction.selected_rows.active index) row) rows
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
  { title = "Active Work"; lines = wrap_lines ~width lines }

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

let readiness_attention_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let readiness = readiness_lines ~width ~selected:interaction.selected_rows.readiness (visible_readiness_rows snapshot interaction) in
  let attention = attention_lines ~width (visible_active_rows snapshot interaction) in
  let lines =
    match (readiness, attention) with
    | [], [] when filter_query interaction <> "" -> [ "No Readiness Gaps or task attention rows match the filter." ]
    | [], [] -> [ "No Readiness Gaps or task attention conditions." ]
    | readiness, [] -> readiness
    | [], attention -> attention
    | readiness, attention -> readiness @ [ "" ] @ attention
  in
  { title = "Readiness and Attention"; lines }

let ordered_queue_panel ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let width = content_width terminal_size in
  let lines =
    match visible_queue_rows snapshot interaction with
    | [] when filter_query interaction <> "" -> [ "No Ordered Queue rows match the current filter." ]
    | [] -> [ "No Ordered Queue state present." ]
    | queue ->
        let next =
          match next_queue_row snapshot with Some row -> [ "Next work: " ^ queue_row_line ~next:true row ] | None -> []
        in
        next
        @ List.mapi
            (fun index row -> queue_row_line row |> fun line -> row_marker interaction.selected_rows.queue index ^ line)
            queue
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

let list_nth_opt list index =
  let rec loop current = function
    | [] -> None
    | value :: _ when current = index -> Some value
    | _ :: rest -> loop (current + 1) rest
  in
  if index < 0 then None else loop 0 list

let selected_task ?(interaction = default_interaction) (snapshot : Projection.t) =
  let rows = visible_active_rows snapshot interaction in
  list_nth_opt rows interaction.selected_rows.active

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

let help_lines =
  [
    "q quit";
    "Tab/Left/Right switch panels";
    "Up/Down or k/j move rows";
    "/ search visible rows";
    "r refresh latest in-memory snapshot";
    "w show Web Dashboard handoff";
    "o inspect selected local path";
    "? toggle help";
  ]

let safe_aids_panel ?(interaction = default_interaction) (snapshot : Projection.t) =
  let aids =
    visible_safe_aids snapshot interaction
    |> List.mapi (fun index aid -> row_marker interaction.selected_rows.safe_aid index ^ safe_aid_label aid)
  in
  let lines = if interaction.help_visible then aids @ [ ""; "Help" ] @ help_lines else aids in
  { title = "Safe Aids"; lines }

let contextual_footer ?(interaction = default_interaction) handoff_available =
  if interaction.filter_active then
    Printf.sprintf "search: %s | type to filter, Backspace edit, Enter apply, Esc cancel"
      (if interaction.filter_text = "" then "<empty>" else interaction.filter_text)
  else
    let handoff = if handoff_available then "w Web Dashboard" else "w handoff unavailable" in
    String.concat " | "
      [
        "q quit";
        "Tab/Left/Right panels";
        "Up/Down rows";
        "/ search";
        "r refresh";
        handoff;
        "o inspect path";
        "? help";
      ]

let render_snapshot ?terminal_size ?(interaction = default_interaction) (snapshot : Projection.t) =
  let interaction = clamp_interaction snapshot interaction in
  match terminal_size with
  | Some size when terminal_too_small size ->
      {
        heading = "Terminal Console";
        subheading = "Resize required";
        panels = [ { title = "Minimum Size"; lines = minimum_size_lines size } ];
        footer = "q quit | resize terminal";
      }
  | _ ->
      {
        heading = "Terminal Console";
        subheading =
          Printf.sprintf "%s | focus %s | generated %s" (status_label snapshot.mode)
            (focused_panel_title interaction.focused_panel) snapshot.generated_at;
        panels =
          [
            home_panel ?terminal_size ~interaction snapshot;
            readiness_attention_panel ?terminal_size ~interaction snapshot;
            ordered_queue_panel ?terminal_size ~interaction snapshot;
            compozy_panel ?terminal_size snapshot;
            task_detail_panel ?terminal_size ~interaction snapshot;
            safe_aids_panel ~interaction snapshot;
          ];
        footer = contextual_footer ~interaction true;
      }

let rendered_lines rendered =
  rendered.heading :: rendered.subheading
  :: (List.concat_map (fun panel -> panel.title :: panel.lines) rendered.panels @ [ rendered.footer ])

let panel_lines rendered title =
  match List.find_opt (fun panel -> panel.title = title) rendered.panels with
  | Some panel -> panel.lines
  | None -> []

let transition ?(safe_aids = []) ?(quit = false) model = { model; safe_aids; quit }

let selection_status snapshot interaction =
  let count = row_count_for_panel snapshot interaction interaction.focused_panel in
  let title = focused_panel_title interaction.focused_panel in
  if count = 0 then title ^ ": no selectable rows"
  else Printf.sprintf "%s row %d of %d" title (selected_row_for_panel interaction interaction.focused_panel + 1) count

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
    | Character c -> append_filter_char model c
    | _ -> transition model
  else
    match key with
    | Character 'q' -> transition ~quit:true model
    | Escape_key -> transition ~quit:true model
    | Character '?' ->
        let help_visible = not model.interaction.help_visible in
        let interaction = { model.interaction with help_visible } in
        let message = if help_visible then "Help shown" else "Help hidden" in
        transition (update_interaction ~status_message:message model interaction)
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
        let interaction = move_panel (-1) model.interaction in
        transition
          (update_interaction ~status_message:("Focus: " ^ focused_panel_title interaction.focused_panel) model
             interaction)
    | Character 'l' | Right_key | Tab_key ->
        let interaction = move_panel 1 model.interaction in
        transition
          (update_interaction ~status_message:("Focus: " ^ focused_panel_title interaction.focused_panel) model
             interaction)
    | Character 'k' | Up_key ->
        let interaction = move_row (-1) model.snapshot model.interaction in
        transition (update_interaction ~status_message:(selection_status model.snapshot interaction) model interaction)
    | Character 'j' | Down_key ->
        let interaction = move_row 1 model.snapshot model.interaction in
        transition (update_interaction ~status_message:(selection_status model.snapshot interaction) model interaction)
    | Character _ | Enter_key | Backspace_key -> transition model

let render_model model =
  let rendered = render_snapshot ?terminal_size:model.terminal_size ~interaction:model.interaction model.snapshot in
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
        Cmd.none )
  | Key_press key ->
      let transition =
        apply_key ~web_handoff:runtime.web_handoff ~local_surfaces:runtime.local_surfaces key model
      in
      List.iter runtime.safe_aid transition.safe_aids;
      if transition.quit then (transition.model, Cmd.quit) else (transition.model, Cmd.none)
  | Resize { columns; rows } -> ({ model with terminal_size = Some { columns; rows } }, Cmd.none)

let printable_ascii_char uchar =
  let code = Uchar.to_int uchar in
  if code >= 0x20 && code <= 0x7e then Some (Char.chr code) else None

let ui_key_of_event ev =
  let data = Event.Key.data ev in
  match data.key with
  | Char c -> Option.map (fun c -> Character c) (printable_ascii_char c)
  | Enter | KP_enter | Line_feed -> Some Enter_key
  | Backspace | Delete -> Some Backspace_key
  | Escape -> Some Escape_key
  | Up | KP_up -> Some Up_key
  | Down | KP_down -> Some Down_key
  | Left | KP_left -> Some Left_key
  | Right | KP_right -> Some Right_key
  | Tab -> Some Tab_key
  | _ -> None

let subscriptions _model =
  Sub.batch
    [
      Sub.on_key_all (fun ev -> Option.map (fun key -> Key_press key) (ui_key_of_event ev));
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
