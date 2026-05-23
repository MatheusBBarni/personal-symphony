open Tui;

module Projection = Terminal_console_model;
module J = Tui.Jsx;

type web_handoff = {
  command: string,
  url: string,
};
type local_surface = {
  label: string,
  root: string,
};
type settings_state = {
  theme: string,
  port: int,
};
type settings_save_result =
  | Settings_saved(settings_state)
  | Settings_rejected(string)
  | Settings_failed(string);

type runtime = {
  initial_state: Runtime_state.t,
  initial_logs: list(string),
  subscribe: (Runtime_state.t => unit) => unit,
  safe_aid: Projection.safe_aid => unit,
  web_handoff,
  local_surfaces: list(local_surface),
  settings: settings_state,
  save_settings: settings_state => settings_save_result,
};

type active_tab =
  | Queue
  | Logs
  | Tasks
  | Readiness
  | Attention;

type settings_field =
  | Settings_theme
  | Settings_port;

type settings_modal = {
  draft_theme: string,
  draft_port: string,
  focused_field: settings_field,
  validation_message: option(string),
};

type row_selection = {
  active: int,
  readiness: int,
  queue: int,
  attention: int,
  safe_aid: int,
};

type interaction = {
  active_tab,
  selected_rows: row_selection,
  filter_text: string,
  filter_active: bool,
  help_visible: bool,
  settings_modal: option(settings_modal),
  logs_scroll: int,
  expanded_queue_id: option(string),
};

type model = {
  snapshot: Projection.t,
  status_label: string,
  status_message: option(string),
  logs: list(string),
  terminal_size: option(terminal_size),
  web_handoff,
  settings: settings_state,
  interaction,
}

and terminal_size = {
  columns: int,
  rows: int,
};

type panel = {
  title: string,
  lines: list(string),
};

type rendered_snapshot = {
  heading: string,
  status_label: string,
  tabs: string,
  subheading: string,
  panels: list(panel),
  footer: string,
};

type ui_key =
  | Character(char)
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
  | Page_down_key;

type transition = {
  model,
  safe_aids: list(Projection.safe_aid),
  quit: bool,
};

type msg =
  | Snapshot_received(Runtime_state.t)
  | Key_press(ui_key)
  | Resize(terminal_size);

let compile_anchor = "terminal-console-tui";
let minimum_terminal_size = {
  columns: 80,
  rows: 24,
};
let default_settings = {
  theme: Terminal_console_settings.default_theme,
  port: 8080,
};
let default_save_settings = settings => Settings_saved(settings);
let default_web_handoff = (~host="127.0.0.1", ~port=8080, ()) => {
  command: Printf.sprintf("symphony --web --port %d", port),
  url: Printf.sprintf("http://%s:%d/", host, port),
};

let web_handoff_host = handoff =>
  switch (Util.drop_prefix(~prefix="http://", handoff.url)) {
  | Some(rest) =>
    switch (String.split_on_char(':', rest)) {
    | [host, ..._] when Util.trim(host) != "" => host
    | _ => "127.0.0.1"
    }
  | None => "127.0.0.1"
  };

let web_handoff_with_port = (handoff, port) =>
  default_web_handoff(~host=web_handoff_host(handoff), ~port, ());

let local_surface = (~label, ~root) => {
  label: Projection.sanitize(label),
  root,
};

let default_row_selection = {
  active: 0,
  readiness: 0,
  queue: 0,
  attention: 0,
  safe_aid: 0,
};

let default_interaction = {
  active_tab: Queue,
  selected_rows: default_row_selection,
  filter_text: "",
  filter_active: false,
  help_visible: false,
  settings_modal: None,
  logs_scroll: 0,
  expanded_queue_id: None,
};

let status_label =
  fun
  | "idle" => "Idle"
  | "ready" => "Ready"
  | "running" => "Running"
  | "retrying" => "Retrying"
  | "attention" => "Needs attention"
  | "readiness_blocked" => "Readiness blocked"
  | mode => {
      let sanitized = Projection.sanitize(mode);
      if (sanitized == "") {
        "Unknown";
      } else {
        "Unknown: " ++ sanitized;
      };
    };

let status_badge_label =
  fun
  | "idle" => "STOPPED"
  | "readiness_blocked" => "BLOCKED"
  | mode => {
      let mode = Projection.sanitize(mode) |> String.uppercase_ascii;
      if (mode == "") {
        "UNKNOWN";
      } else {
        mode;
      };
    };

let status_badge_tone =
  fun
  | "idle" => Components.Neutral
  | "ready"
  | "running" => Components.Success
  | "retrying"
  | "attention"
  | "readiness_blocked" => Components.Warning
  | _ => Components.Info;

let sanitize_logs = logs =>
  logs |> List.map(Projection.sanitize) |> List.filter(line => line != "");

let max_log_lines = 500;

let keep_recent_logs = logs => {
  let count = List.length(logs);
  if (count <= max_log_lines) {
    logs;
  } else {
    let rec drop = (n, lines) =>
      if (n <= 0) {
        lines;
      } else {
        switch (lines) {
        | [] => []
        | [_, ...rest] => drop(n - 1, rest)
        };
      };
    drop(count - max_log_lines, logs);
  };
};

let rec drop_count = (count, lines) =>
  if (count <= 0) {
    lines;
  } else {
    switch (lines) {
    | [] => []
    | [_, ...rest] => drop_count(count - 1, rest)
    };
  };

let rec take_count = (count, lines) =>
  if (count <= 0) {
    [];
  } else {
    switch (lines) {
    | [] => []
    | [line, ...rest] => [line, ...take_count(count - 1, rest)]
    };
  };

let append_log_line = (model, line) => {
  let new_logs = sanitize_logs([line]);
  let previous_count = List.length(model.logs);
  let logs = keep_recent_logs(model.logs @ new_logs);
  let dropped =
    max(0, previous_count + List.length(new_logs) - List.length(logs));
  let logs_scroll =
    if (model.interaction.logs_scroll == 0) {
      0;
    } else {
      max(
        0,
        model.interaction.logs_scroll + List.length(new_logs) - dropped,
      );
    };

  {
    ...model,
    logs,
    interaction: {
      ...model.interaction,
      logs_scroll,
    },
  };
};

let initial_model =
    (
      ~terminal_size=?,
      ~logs=[],
      ~web_handoff=default_web_handoff(),
      ~settings=default_settings,
      state,
    ) => {
  let snapshot = Projection.of_runtime_state(state);
  {
    snapshot,
    status_label: status_label(snapshot.mode),
    status_message: None,
    logs: keep_recent_logs(sanitize_logs(logs)),
    terminal_size,
    web_handoff,
    settings,
    interaction: default_interaction,
  };
};

let starts_with = (text, prefix) => {
  let prefix_len = String.length(prefix);
  prefix_len <= String.length(text)
  && String.sub(text, 0, prefix_len) == prefix;
};

let option_value = (~default) =>
  fun
  | Some(value) => value
  | None => default;

let is_state = (state, row: Projection.task_row) =>
  String.lowercase_ascii(row.state) == state;

let state_rank = state =>
  switch (String.lowercase_ascii(state)) {
  | "attention" => 0
  | "needs_attention" => 0
  | "budget_exhausted" => 0
  | "failed" => 1
  | "retrying" => 2
  | "running" => 3
  | "pending" => 4
  | "goal_met" => 5
  | "completed" => 5
  | "skipped" => 6
  | _ => 6
  };

let ordered_rows = rows =>
  List.stable_sort(
    (left: Projection.task_row, right: Projection.task_row) =>
      compare(state_rank(left.state), state_rank(right.state)),
    rows,
  );

let tab_title =
  fun
  | Queue => "Queue"
  | Logs => "Logs"
  | Tasks => "Tasks"
  | Readiness => "Readiness"
  | Attention => "Needs attention";

let focused_tab_title = tab_title;

let tab_order = [Queue, Logs, Tasks, Readiness, Attention];

let tab_index = tab => {
  let rec loop = index =>
    fun
    | [] => 0
    | [current, ...rest] =>
      if (current == tab) {
        index;
      } else {
        loop(index + 1, rest);
      };

  loop(0, tab_order);
};

let tab_at = index => {
  let count = List.length(tab_order);
  let normalized = (index mod count + count) mod count;
  List.nth(tab_order, normalized);
};

let move_tab = (delta, interaction) => {
  let active_tab = tab_at(tab_index(interaction.active_tab) + delta);
  {
    ...interaction,
    active_tab,
    filter_active: false,
  };
};

let contains_substring = (text, needle) => {
  let text_len = String.length(text);
  let needle_len = String.length(needle);
  if (needle_len == 0) {
    true;
  } else {
    let rec loop = index =>
      index
      + needle_len <= text_len
      && (String.sub(text, index, needle_len) == needle || loop(index + 1));

    loop(0);
  };
};

let filter_query = interaction =>
  interaction.filter_text
  |> Projection.sanitize
  |> String.lowercase_ascii
  |> Util.trim;

let row_search_text = (row: Projection.task_row) =>
  [
    Some(row.id),
    Some(row.title),
    Some(row.state),
    row.detail,
    row.error,
    Option.bind(row.goal_usage, usage => usage.text),
    Option.map(
      (loop: Projection.goal_loop) => loop.goal ++ " " ++ loop.text,
      row.goal_loop,
    ),
    Option.map(
      (status: Projection.context_status) => status.text,
      row.context_status,
    ),
  ]
  |> List.filter_map(Fun.id)
  |> String.concat(" ")
  |> String.lowercase_ascii;

let task_row_matches = (interaction, row) => {
  let query = filter_query(interaction);
  query == "" || contains_substring(row_search_text(row), query);
};

let visible_task_rows = (interaction, rows) =>
  rows |> List.filter(task_row_matches(interaction)) |> ordered_rows;
let visible_active_rows = (snapshot, interaction) =>
  visible_task_rows(interaction, snapshot.Projection.active);
let visible_queue_rows = (snapshot, interaction) =>
  visible_task_rows(interaction, snapshot.Projection.queue);
let is_attention_row = (row: Projection.task_row) =>
  switch (String.lowercase_ascii(row.state)) {
  | "attention"
  | "needs_attention"
  | "budget_exhausted" => true
  | _ => false
  };

let visible_attention_rows = (snapshot, interaction) =>
  visible_active_rows(snapshot, interaction) |> List.filter(is_attention_row);

let readiness_search_text = (row: Projection.readiness_row) =>
  String.lowercase_ascii(row.requirement ++ " " ++ row.remediation);

let readiness_matches = (interaction, row) => {
  let query = filter_query(interaction);
  query == "" || contains_substring(readiness_search_text(row), query);
};

let visible_readiness_rows = (snapshot, interaction) =>
  List.filter(readiness_matches(interaction), snapshot.Projection.readiness);

let safe_aid_label =
  fun
  | Projection.Refresh_view => "Refresh view"
  | Show_web_handoff => "Show Web Dashboard handoff"
  | Show_path(path) => "Show path " ++ Projection.sanitize(path);

let safe_aid_search_text = aid =>
  safe_aid_label(aid) |> String.lowercase_ascii;

let safe_aid_matches = (interaction, aid) => {
  let query = filter_query(interaction);
  query == "" || contains_substring(safe_aid_search_text(aid), query);
};

let visible_safe_aids = (snapshot, interaction) =>
  List.filter(safe_aid_matches(interaction), snapshot.Projection.safe_aids);

let clamp_index = (count, index) =>
  if (count <= 0) {
    0;
  } else {
    max(0, min(count - 1, index));
  };

let list_nth_opt = (list, index) => {
  let rec loop = current =>
    fun
    | [] => None
    | [value, ..._] when current == index => Some(value)
    | [_, ...rest] => loop(current + 1, rest);

  if (index < 0) {
    None;
  } else {
    loop(0, list);
  };
};

let clamp_interaction = (snapshot, interaction) => {
  let active =
    clamp_index(
      List.length(visible_active_rows(snapshot, interaction)),
      interaction.selected_rows.active,
    );
  let readiness =
    clamp_index(
      List.length(visible_readiness_rows(snapshot, interaction)),
      interaction.selected_rows.readiness,
    );
  let queue_rows = visible_queue_rows(snapshot, interaction);
  let queue =
    clamp_index(List.length(queue_rows), interaction.selected_rows.queue);
  let attention =
    clamp_index(
      List.length(visible_attention_rows(snapshot, interaction)),
      interaction.selected_rows.attention,
    );
  let safe_aid =
    clamp_index(
      List.length(visible_safe_aids(snapshot, interaction)),
      interaction.selected_rows.safe_aid,
    );
  let expanded_queue_id =
    switch (interaction.expanded_queue_id) {
    | Some(id)
        when
          List.exists((row: Projection.task_row) => row.id == id, queue_rows) =>
      Some(id)
    | _ => None
    };

  {
    ...interaction,
    selected_rows: {
      active,
      readiness,
      queue,
      attention,
      safe_aid,
    },
    logs_scroll: max(0, interaction.logs_scroll),
    expanded_queue_id,
  };
};

let row_count_for_tab = (snapshot, interaction) =>
  fun
  | Queue => List.length(visible_queue_rows(snapshot, interaction))
  | Logs => 0
  | Tasks => List.length(visible_active_rows(snapshot, interaction))
  | Readiness => List.length(visible_readiness_rows(snapshot, interaction))
  | Attention => List.length(visible_attention_rows(snapshot, interaction));

let selected_row_for_tab = interaction =>
  fun
  | Queue => interaction.selected_rows.queue
  | Logs => 0
  | Tasks => interaction.selected_rows.active
  | Readiness => interaction.selected_rows.readiness
  | Attention => interaction.selected_rows.attention;

let set_selected_row_for_tab = (interaction, tab, selected) => {
  let selected_rows =
    switch (tab) {
    | Queue => {
        ...interaction.selected_rows,
        queue: selected,
      }
    | Logs => interaction.selected_rows
    | Tasks => {
        ...interaction.selected_rows,
        active: selected,
      }
    | Readiness => {
        ...interaction.selected_rows,
        readiness: selected,
      }
    | Attention => {
        ...interaction.selected_rows,
        attention: selected,
      }
    };

  {
    ...interaction,
    selected_rows,
  };
};

let move_row = (delta, snapshot, interaction) => {
  let tab = interaction.active_tab;
  let count = row_count_for_tab(snapshot, interaction, tab);
  let current = selected_row_for_tab(interaction, tab);
  let selected = clamp_index(count, current + delta);
  set_selected_row_for_tab(interaction, tab, selected);
};

let state_token = state =>
  switch (String.lowercase_ascii(state)) {
  | "idle" => "IDLE"
  | "ready" => "READY"
  | "running" => "RUNNING"
  | "retrying" => "RETRYING"
  | "attention" => "ATTENTION"
  | "needs_attention" => "NEEDS ATTENTION"
  | "budget_exhausted" => "BUDGET EXHAUSTED"
  | "goal_met" => "GOAL MET"
  | "failed" => "FAILED"
  | "readiness_blocked" => "READINESS BLOCKED"
  | "pending" => "PENDING"
  | "completed" => "COMPLETED"
  | "skipped" => "SKIPPED"
  | state =>
    let sanitized = Projection.sanitize(state);
    if (sanitized == "") {
      "UNKNOWN";
    } else {
      String.uppercase_ascii(sanitized);
    };
  };

let shorten = (~max=160, text) => {
  let text = Projection.sanitize(text);
  if (String.length(text) <= max) {
    text;
  } else if (max <= 3) {
    String.sub(text, 0, max);
  } else {
    String.sub(text, 0, max - 3) ++ "...";
  };
};

let words = text =>
  text |> String.split_on_char(' ') |> List.filter(word => word != "");

let rec chunks = (width, word) =>
  if (String.length(word) <= width) {
    [word];
  } else {
    [
      String.sub(word, 0, width),
      ...chunks(
           width,
           String.sub(word, width, String.length(word) - width),
         ),
    ];
  };

let wrap_line = (~width, text) => {
  let width = max(12, width);
  let words = words(text) |> List.concat_map(chunks(width));
  let rec loop = (current, current_len, acc) =>
    fun
    | [] =>
      switch (current) {
      | "" => List.rev(acc)
      | _ => List.rev([current, ...acc])
      }
    | [word, ...rest] => {
        let word_len = String.length(word);
        if (current == "") {
          loop(word, word_len, acc, rest);
        } else if (current_len + 1 + word_len <= width) {
          loop(current ++ " " ++ word, current_len + 1 + word_len, acc, rest);
        } else {
          loop(word, word_len, [current, ...acc], rest);
        };
      };

  switch (words) {
  | [] => [""]
  | words => loop("", 0, [], words)
  };
};

let wrap_lines = (~width, lines) =>
  List.concat_map(wrap_line(~width), lines);

let content_width =
  fun
  | None => 100
  | Some(size) => max(32, size.columns - 6);

let terminal_too_small = size =>
  size.columns < minimum_terminal_size.columns
  || size.rows < minimum_terminal_size.rows;

let minimum_size_lines = size => [
  Printf.sprintf(
    "Terminal Console needs at least %d columns x %d rows.",
    minimum_terminal_size.columns,
    minimum_terminal_size.rows,
  ),
  Printf.sprintf(
    "Current size: %d columns x %d rows.",
    size.columns,
    size.rows,
  ),
  "Resize the terminal to continue.",
];

let summary_line = (snapshot, prefix) =>
  List.find_opt(
    line => starts_with(line, prefix),
    snapshot.Projection.summary,
  );

let summary_value = (snapshot, prefix) =>
  switch (summary_line(snapshot, prefix)) {
  | None => None
  | Some(line) =>
    let prefix_len = String.length(prefix);
    Some(
      String.sub(line, prefix_len, String.length(line) - prefix_len)
      |> Util.trim,
    );
  };

let project_title = snapshot =>
  switch (summary_value(snapshot, "Workspace Repository:")) {
  | Some(title) when title != "" => title
  | _ => "Symphony"
  };

let total_tokens_line = snapshot =>
  option_value(
    ~default="Total tokens: unavailable",
    summary_line(snapshot, "Total tokens:"),
  );

let count_active = (state, rows) =>
  rows |> List.filter(is_state(state)) |> List.length;

let next_queue_row = snapshot =>
  List.find_opt(is_state("pending"), snapshot.Projection.queue);

let compozy_row_matches =
    (progress: Projection.compozy_progress, row: Projection.task_row) =>
  row.id == progress.run_id
  || row.id == "compozy:"
  ++ progress.slug
  || row.title == "Compozy PRD run: "
  ++ progress.slug;

let compozy_progress_for_row = (snapshot: Projection.t, row) =>
  switch (
    List.find_opt(
      progress => compozy_row_matches(progress, row),
      snapshot.Projection.compozy_progresses,
    )
  ) {
  | Some(_) as progress => progress
  | None =>
    switch (snapshot.Projection.compozy) {
    | Some(progress) when compozy_row_matches(progress, row) =>
      Some(progress)
    | _ => None
    }
  };

let queue_row_has_active_compozy_step = row =>
  switch (String.lowercase_ascii(row.Projection.state)) {
  | "pending"
  | "running"
  | "retrying" => true
  | _ => false
  };

let compozy_progress_for_active_queue_row = (snapshot, row) =>
  if (queue_row_has_active_compozy_step(row)) {
    compozy_progress_for_row(snapshot, row);
  } else {
    None;
  };

let compozy_task_step_summary = (progress: Projection.compozy_progress) => {
  let step = option_value(~default="none", progress.current_step);
  let next = option_value(~default="none", progress.next_step);
  Printf.sprintf(
    "Compozy Task Step: %s -> next %s | progress %d/%d completed, %d failed, %d skipped",
    step,
    next,
    progress.completed,
    progress.total,
    progress.failed,
    progress.skipped,
  );
};

let compozy_task_step_lines = (progress: Projection.compozy_progress) => [
  "    Current Compozy Task Step: "
  ++ option_value(~default="none", progress.current_step),
  "    Next Compozy Task Step: "
  ++ option_value(~default="none", progress.next_step),
  Printf.sprintf(
    "    Compozy progress: completed %d | failed %d | skipped %d | total %d",
    progress.completed,
    progress.failed,
    progress.skipped,
    progress.total,
  ),
];

let compozy_detail_for_row = (snapshot: Projection.t, row) =>
  Option.map(
    compozy_task_step_summary,
    compozy_progress_for_row(snapshot, row),
  );

let combined_detail = items =>
  switch (List.filter_map(Fun.id, items)) {
  | [] => None
  | items => Some(String.concat(" | ", items))
  };

let goal_loop_summary = (loop: Projection.goal_loop) =>
  "Goal Loop: " ++ loop.text;

let task_row_line = (~prefix="", ~compozy_detail=?, row: Projection.task_row) => {
  let base =
    Printf.sprintf(
      "%s%s %s %s",
      prefix,
      state_token(row.state),
      row.id,
      row.title,
    );
  let goal_loop_detail = Option.map(goal_loop_summary, row.goal_loop);
  let detail =
    combined_detail([compozy_detail, goal_loop_detail, row.detail]);
  switch (detail) {
  | None => base
  | Some(detail) => base ++ " - " ++ shorten(detail)
  };
};

let row_marker = (selected, index) =>
  if (selected == index) {
    "> ";
  } else {
    "  ";
  };

let queue_row_line =
    (~next=false, ~compozy_detail=?, row: Projection.task_row) => {
  let base =
    Printf.sprintf(
      "%s%s %s %s",
      if (next) {"NEXT "} else {""},
      state_token(row.state),
      row.id,
      row.title,
    );

  let detail =
    switch (row.error) {
    | Some(reason) when String.lowercase_ascii(row.state) == "skipped" =>
      Some("skip reason: " ++ reason)
    | Some(reason) when String.lowercase_ascii(row.state) == "failed" =>
      Some("failure reason: " ++ reason)
    | Some(reason) when String.lowercase_ascii(row.state) == "attention" =>
      Some("attention reason: " ++ reason)
    | _ => row.detail
    };

  let detail =
    switch (detail, compozy_detail) {
    | (None, None) => None
    | (Some(detail), None) => Some(detail)
    | (None, Some(compozy_detail)) => Some(compozy_detail)
    | (Some(detail), Some(compozy_detail)) =>
      Some(compozy_detail ++ " | " ++ detail)
    };

  switch (detail) {
  | None => base
  | Some(detail) => base ++ " - " ++ shorten(detail)
  };
};

let idle_home_line = mode =>
  switch (mode) {
  | "readiness_blocked" => "READINESS BLOCKED Dispatch is blocked by Readiness Gaps."
  | "ready" => "READY Waiting for next Ordered Queue dispatch."
  | _ => "IDLE No active work."
  };

let filter_line = interaction => {
  let query = filter_query(interaction);
  if (query == "") {
    [];
  } else {
    ["Filter: " ++ query];
  };
};

let task_separator_line = width =>
  "  " ++ String.make(min(72, max(12, width - 2)), '-');

let rec intersperse = separator =>
  fun
  | [] => []
  | [line] => [line]
  | [line, ...rest] => [line, separator, ...intersperse(separator, rest)];

let tasks_panel =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      snapshot: Projection.t,
    ) => {
  let width = content_width(terminal_size);
  let active_rows = visible_active_rows(snapshot, interaction);
  let active_lines =
    switch (active_rows) {
    | [] when filter_query(interaction) != "" => [
        "No active rows match the current filter.",
      ]
    | [] => [idle_home_line(snapshot.mode)]
    | rows =>
      rows
      |> List.mapi((index, row) => {
           let compozy_detail = compozy_detail_for_row(snapshot, row);
           task_row_line(
             ~prefix=row_marker(interaction.selected_rows.active, index),
             ~compozy_detail?,
             row,
           );
         })
      |> intersperse(task_separator_line(width))
    };

  let next_lines =
    switch (next_queue_row(snapshot)) {
    | Some(row) =>
      let compozy_detail = compozy_detail_for_row(snapshot, row);
      ["Next work: " ++ queue_row_line(~next=true, ~compozy_detail?, row)];
    | None => []
    };

  let error_lines =
    switch (snapshot.last_error) {
    | Some(error) => ["Last state error: " ++ shorten(error)]
    | None => []
    };

  let lines =
    [
      "Status: " ++ status_label(snapshot.mode),
      "Updated: " ++ snapshot.generated_at,
      Printf.sprintf(
        "Active: RUNNING %d | RETRYING %d | ATTENTION %d",
        count_active("running", snapshot.active),
        count_active("retrying", snapshot.active),
        List.length(List.filter(is_attention_row, snapshot.active)),
      ),
      total_tokens_line(snapshot),
    ]
    @ filter_line(interaction)
    @ active_lines
    @ next_lines
    @ error_lines;

  {
    title: "Tasks",
    lines: wrap_lines(~width, lines),
  };
};

let readiness_lines = (~width, ~selected, readiness) =>
  readiness
  |> List.mapi((index, row: Projection.readiness_row) =>
       wrap_lines(
         ~width,
         [
           Printf.sprintf(
             "%sREADINESS GAP %d requirement: %s",
             row_marker(selected, index),
             index + 1,
             row.requirement,
           ),
           "Remediation: " ++ row.remediation,
         ],
       )
     )
  |> List.concat;

let attention_lines = (~width, ~selected, active) =>
  active
  |> List.mapi((index, row) => {
       let lines = [
         task_row_line(~prefix=row_marker(selected, index), row),
         ...switch (row.error) {
            | Some(error) => ["Current error: " ++ shorten(error)]
            | None => []
            },
       ];

       wrap_lines(~width, lines);
     })
  |> List.concat;

let readiness_panel =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      snapshot: Projection.t,
    ) => {
  let width = content_width(terminal_size);
  let readiness =
    readiness_lines(
      ~width,
      ~selected=interaction.selected_rows.readiness,
      visible_readiness_rows(snapshot, interaction),
    );
  let lines =
    switch (readiness) {
    | [] when filter_query(interaction) != "" => [
        "No Readiness Gaps match the current filter.",
      ]
    | [] => ["No Readiness Gaps."]
    | readiness => readiness
    };

  {
    title: "Readiness",
    lines,
  };
};

let attention_panel =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      snapshot: Projection.t,
    ) => {
  let width = content_width(terminal_size);
  let attention =
    attention_lines(
      ~width,
      ~selected=interaction.selected_rows.attention,
      visible_attention_rows(snapshot, interaction),
    );

  let lines =
    switch (attention) {
    | [] when filter_query(interaction) != "" => [
        "No task attention rows match the current filter.",
      ]
    | [] => ["No task attention conditions."]
    | attention => attention
    };

  {
    title: "Needs attention",
    lines,
  };
};

let split_detail = detail =>
  detail
  |> String.split_on_char('|')
  |> List.map(Util.trim)
  |> List.filter(item => item != "");

let detail_items = row =>
  switch (row.Projection.detail) {
  | None => []
  | Some(detail) => split_detail(detail)
  };

let detail_group = (prefixes, items) =>
  List.filter(
    item => List.exists(prefix => starts_with(item, prefix), prefixes),
    items,
  );

let optional_join = (label, items) =>
  switch (items) {
  | [] => []
  | items => [label ++ String.concat(" | ", items)]
  };

let goal_loop_detail_lines = (loop: Projection.goal_loop) => {
  let headline =
    [
      "state " ++ loop.state,
      Printf.sprintf("attempt %d", loop.attempt_count),
    ]
    |> (
      parts =>
        switch (loop.stop_outcome) {
        | Some(outcome) => parts @ ["outcome " ++ outcome]
        | None => parts
        }
    )
    |> (parts => parts @ ["updated " ++ loop.updated_at]);

  [
    Some("Goal Loop: " ++ String.concat(" | ", headline)),
    Some("Goal Loop Goal: " ++ loop.goal),
    Option.map(budget => "Goal Loop Budget: " ++ budget, loop.budget),
    Option.map(
      evidence => "Goal Loop Evidence: " ++ evidence,
      loop.latest_evidence,
    ),
    Option.map(
      reason => "Goal Loop Stop Reason: " ++ reason,
      loop.stop_reason,
    ),
    Option.map(
      action => "Goal Loop Next Action: " ++ action,
      loop.next_action,
    ),
    Option.map(
      path => "Goal Loop Diagnostics: " ++ path,
      loop.diagnostics_path,
    ),
  ]
  |> List.filter_map(Fun.id);
};

let matching_active_task = (snapshot, row: Projection.task_row) =>
  List.find_opt(
    (active: Projection.task_row) => active.id == row.id,
    snapshot.Projection.active,
  );

let queue_expansion_lines = (snapshot, row: Projection.task_row) => {
  let task_line = Printf.sprintf("    Task: %s %s", row.id, row.title);
  let compozy_lines =
    switch (compozy_progress_for_active_queue_row(snapshot, row)) {
    | Some(progress) => compozy_task_step_lines(progress)
    | None => []
    };

  switch (matching_active_task(snapshot, row)) {
  | Some(active) =>
    let items = detail_items(active);
    let stage_items =
      detail_group(
        ["stage agent ", "stage states ", "last event ", "last message "],
        items,
      );
    let stage_line =
      switch (stage_items) {
      | [] => "    Stage: " ++ state_token(active.state)
      | stage_items => "    Stage: " ++ String.concat(" | ", stage_items)
      };

    [task_line, stage_line] @ compozy_lines;
  | None =>
    [task_line, "    Stage: " ++ state_token(row.state)] @ compozy_lines
  };
};

let queue_row_lines = (snapshot, interaction, index, row) => {
  let compozy_detail =
    Option.map(
      compozy_task_step_summary,
      compozy_progress_for_active_queue_row(snapshot, row),
    );
  let line =
    queue_row_line(~compozy_detail?, row)
    |> (line => row_marker(interaction.selected_rows.queue, index) ++ line);

  switch (interaction.expanded_queue_id) {
  | Some(id) when id == row.Projection.id => [
      line,
      ...queue_expansion_lines(snapshot, row),
    ]
  | _ => [line]
  };
};

let queue_panel =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      snapshot: Projection.t,
    ) => {
  let width = content_width(terminal_size);
  let lines =
    switch (visible_queue_rows(snapshot, interaction)) {
    | [] when filter_query(interaction) != "" => [
        "No Ordered Queue rows match the current filter.",
      ]
    | [] => ["No Ordered Queue state present."]
    | queue =>
      let next =
        switch (next_queue_row(snapshot)) {
        | Some(row) =>
          let compozy_detail =
            Option.map(
              compozy_task_step_summary,
              compozy_progress_for_active_queue_row(snapshot, row),
            );
          [
            "Next work: " ++ queue_row_line(~next=true, ~compozy_detail?, row),
          ];
        | None => []
        };

      next
      @ (
        List.mapi(queue_row_lines(snapshot, interaction), queue)
        |> List.concat
      );
    };

  {
    title: "Queue",
    lines: wrap_lines(~width, lines),
  };
};

let compozy_panel = (~terminal_size=?, snapshot: Projection.t) => {
  let width = content_width(terminal_size);
  let lines =
    switch (snapshot.Projection.compozy) {
    | None => ["No Compozy PRD Run progress present."]
    | Some(progress) => [
        "Compozy PRD Run: " ++ progress.slug,
        "Run ID: " ++ progress.run_id,
        "Current step: "
        ++ option_value(~default="No active step", progress.current_step),
        Printf.sprintf(
          "Progress: completed %d | failed %d | skipped %d | total %d",
          progress.completed,
          progress.failed,
          progress.skipped,
          progress.total,
        ),
      ]
    };

  {
    title: "Compozy PRD Run",
    lines: wrap_lines(~width, lines),
  };
};

let goal_usage_line = (usage: Projection.goal_usage) =>
  switch (usage.text) {
  | Some(text) => Some("Goal Usage: " ++ text)
  | None =>
    let parts =
      []
      |> (
        parts =>
          switch (usage.status) {
          | Some(status) => ["status " ++ status, ...parts]
          | None => parts
          }
      )
      |> (
        parts =>
          switch (usage.time_used_seconds) {
          | Some(seconds) => [
              Printf.sprintf("time %.0fs", seconds),
              ...parts,
            ]
          | None => parts
          }
      )
      |> (
        parts =>
          switch (usage.tokens_used) {
          | Some(tokens) => [Printf.sprintf("tokens %d", tokens), ...parts]
          | None => parts
          }
      );

    if (parts == []) {
      None;
    } else {
      Some("Goal Usage: " ++ String.concat(" | ", List.rev(parts)));
    };
  };

let selected_task = (~interaction=default_interaction, snapshot: Projection.t) => {
  let (rows, selected) =
    switch (interaction.active_tab) {
    | Attention => (
        visible_attention_rows(snapshot, interaction),
        interaction.selected_rows.attention,
      )
    | _ => (
        visible_active_rows(snapshot, interaction),
        interaction.selected_rows.active,
      )
    };

  list_nth_opt(rows, selected);
};

let task_detail_panel =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      snapshot: Projection.t,
    ) => {
  let width = content_width(terminal_size);
  let lines =
    switch (selected_task(~interaction, snapshot)) {
    | None => ["No active, retrying, or attention work selected."]
    | Some(row) =>
      let items = detail_items(row);
      let issue_metadata = detail_group(["issue state ", "branch "], items);
      let stage_state =
        detail_group(
          ["stage agent ", "stage states ", "last event ", "last message "],
          items,
        );
      let harness_identity =
        detail_group(["harness ", "harness kind "], items);
      [
        Printf.sprintf("Task: %s %s", row.id, row.title),
        "State: " ++ state_token(row.state),
      ]
      @ (
        switch (compozy_progress_for_row(snapshot, row)) {
        | Some(progress) => compozy_task_step_lines(progress)
        | None => []
        }
      )
      @ optional_join("Issue metadata: ", issue_metadata)
      @ optional_join("Stage state: ", stage_state)
      @ optional_join("Harness identity: ", harness_identity)
      @ (
        switch (row.goal_loop) {
        | Some(loop) => goal_loop_detail_lines(loop)
        | None => []
        }
      )
      @ (
        switch (row.goal_usage) {
        | Some(usage) => Option.to_list(goal_usage_line(usage))
        | None => []
        }
      )
      @ (
        switch (row.context_status) {
        | Some(context) => ["Context Status: " ++ context.text]
        | None => []
        }
      )
      @ (
        switch (row.error) {
        | Some(error) => ["Current error: " ++ shorten(error)]
        | None => []
        }
      );
    };

  {
    title: "Task Detail",
    lines: wrap_lines(~width, lines),
  };
};

let help_commands = [
  ("q", "quit Terminal Console"),
  ("Tab / h/l / Left/Right", "switch tabs"),
  ("Up/Down / j/k", "move selectable rows"),
  ("Space", "expand selected Queue task stage"),
  ("/", "search visible rows"),
  ("r", "refresh latest in-memory Runtime State snapshot"),
  ("s", "open Terminal Console settings"),
  ("w", "show Web Dashboard handoff"),
  ("o", "inspect selected local path"),
  ("Esc / ?", "close this modal"),
];

let help_lines =
  List.map(((key, label)) => key ++ " " ++ label, help_commands);

let safe_aids_panel =
    (~interaction=default_interaction, snapshot: Projection.t) => {
  let aids =
    visible_safe_aids(snapshot, interaction)
    |> List.mapi((index, aid) =>
         row_marker(interaction.selected_rows.safe_aid, index)
         ++ safe_aid_label(aid)
       );

  let lines = aids;
  {
    title: "Safe Aids",
    lines,
  };
};

let ends_with = (~suffix, text) => {
  let suffix_len = String.length(suffix);
  let text_len = String.length(text);
  suffix_len <= text_len
  && String.sub(text, text_len - suffix_len, suffix_len) == suffix;
};

let is_path_token = token => {
  let is_url =
    starts_with(token, "http://") || starts_with(token, "https://");
  !is_url
  && (
    starts_with(token, "/")
    || starts_with(token, "./")
    || starts_with(token, "../")
    || starts_with(token, ".symphony/")
    || starts_with(token, "apps/")
    || starts_with(token, "docs/")
    || String.contains(token, '/')
    || ends_with(~suffix="/...", token)
  );
};

let split_trailing_log_punctuation = token => {
  let len = String.length(token);
  if (len == 0) {
    (token, "");
  } else {
    switch (token.[len - 1]) {
    | ','
    | ';' => (
        String.sub(token, 0, len - 1),
        String.make(1, token.[len - 1]),
      )
    | _ => (token, "")
    };
  };
};

let join_path_components = components => String.concat("/", components);

let rec suffix_from_component = marker =>
  fun
  | [component, ..._] as suffix when component == marker => Some(suffix)
  | [_, ...rest] => suffix_from_component(marker, rest)
  | [] => None;

let last_path_components = (count, components) => {
  let rec drop = (count, items) =>
    if (count <= 0) {
      items;
    } else {
      switch (items) {
      | [] => []
      | [_, ...rest] => drop(count - 1, rest)
      };
    };

  let extra = List.length(components) - count;
  drop(extra, components);
};

let compact_absolute_path = components => {
  let rec from_runtime_dir =
    fun
    | [root, (".symphony" | ".compozy") as runtime_dir, ...rest] =>
      Some([root, runtime_dir, ...rest])
    | [_, ...rest] => from_runtime_dir(rest)
    | [] => None;

  switch (from_runtime_dir(components)) {
  | Some(suffix) => join_path_components(suffix)
  | None =>
    let cwd_root = Filename.basename(Sys.getcwd());
    switch (suffix_from_component(cwd_root, components)) {
    | Some(suffix) => join_path_components(suffix)
    | None =>
      switch (last_path_components(3, components)) {
      | [] => "/"
      | suffix => join_path_components(suffix)
      }
    };
  };
};

let compact_relative_path = components =>
  switch (components) {
  | [_, ..._] => join_path_components(components)
  | [] => "."
  };

let compact_path_token = token => {
  let (body, punctuation) = split_trailing_log_punctuation(token);
  if (!is_path_token(body)) {
    token;
  } else {
    let components =
      body |> String.split_on_char('/') |> List.filter(part => part != "");
    let compact =
      if (starts_with(body, "/")) {
        compact_absolute_path(components);
      } else {
        compact_relative_path(components);
      };

    compact ++ punctuation;
  };
};

let compact_log_token = token =>
  switch (String.index_opt(token, '=')) {
  | Some(index) when index > 0 =>
    let key = String.sub(token, 0, index);
    let value =
      String.sub(token, index + 1, String.length(token) - index - 1);
    key
    ++ "="
    ++ (
      if (is_path_token(value)) {
        compact_path_token(value);
      } else {
        value;
      }
    );
  | _ =>
    if (is_path_token(token)) {
      compact_path_token(token);
    } else {
      token;
    }
  };

let compact_log_line = line =>
  line
  |> String.split_on_char(' ')
  |> List.filter(token => token != "")
  |> List.map(compact_log_token)
  |> String.concat(" ");

let logs_window_size =
  fun
  | None => None
  | Some(size) => Some(max(1, size.rows - 10));

let logs_panel = (~terminal_size=?, ~interaction=default_interaction, logs) => {
  let width = content_width(terminal_size);
  let lines =
    switch (sanitize_logs(logs)) {
    | [] => ["No background logs captured yet."]
    | logs =>
      let logs = List.rev(logs) |> List.map(compact_log_line);
      let offset =
        min(
          max(0, interaction.logs_scroll),
          max(0, List.length(logs) - 1),
        );
      let logs = drop_count(offset, logs);
      let logs =
        switch (logs_window_size(terminal_size)) {
        | None => logs
        | Some(limit) => take_count(limit, logs)
        };

      logs;
    };

  {
    title: "Logs",
    lines: wrap_lines(~width, lines),
  };
};

let contextual_footer = (~interaction=default_interaction, handoff_available) =>
  if (interaction.filter_active) {
    Printf.sprintf(
      "search: %s | type to filter, Backspace edit, Enter apply, Esc cancel",
      if (interaction.filter_text == "") {
        "<empty>";
      } else {
        interaction.filter_text;
      },
    );
  } else {
    let handoff = if (handoff_available) {"[w]web"} else {"[w]unavailable"};
    let movement =
      switch (interaction.active_tab) {
      | Logs => "[j/k]scroll"
      | Queue => "[j/k]rows [Space]expand"
      | _ => "[j/k]rows"
      };

    String.concat(
      " | ",
      [
        "[q]quit",
        "[Tab]tabs",
        "[h/l]tabs",
        movement,
        "[/]search",
        "[r]refresh",
        "[s]settings",
        handoff,
        "[o]path",
        "[?]help",
      ],
    );
  };

let render_snapshot =
    (
      ~terminal_size=?,
      ~interaction=default_interaction,
      ~logs=[],
      snapshot: Projection.t,
    ) => {
  let interaction = clamp_interaction(snapshot, interaction);
  let tabs = tab_order |> List.map(tab_title) |> String.concat(" | ");
  let status = status_badge_label(snapshot.mode);
  switch (terminal_size) {
  | Some(size) when terminal_too_small(size) => {
      heading: project_title(snapshot),
      status_label: status,
      tabs,
      subheading: "Resize required",
      panels: [
        {
          title: "Minimum Size",
          lines: minimum_size_lines(size),
        },
      ],
      footer: "q quit | resize terminal",
    }
  | _ => {
      heading: project_title(snapshot),
      status_label: status,
      tabs,
      subheading: Printf.sprintf("generated %s", snapshot.generated_at),
      panels: [
        queue_panel(~terminal_size?, ~interaction, snapshot),
        logs_panel(~terminal_size?, ~interaction, logs),
        tasks_panel(~terminal_size?, ~interaction, snapshot),
        readiness_panel(~terminal_size?, ~interaction, snapshot),
        attention_panel(~terminal_size?, ~interaction, snapshot),
      ],
      footer: contextual_footer(~interaction, true),
    }
  };
};

let rendered_lines = rendered => [
  rendered.heading,
  rendered.status_label,
  rendered.tabs,
  rendered.subheading,
  ...List.concat_map(panel => [panel.title, ...panel.lines], rendered.panels)
     @ [rendered.footer],
];

let panel_lines = (rendered, title) =>
  switch (List.find_opt(panel => panel.title == title, rendered.panels)) {
  | Some(panel) => panel.lines
  | None => []
  };

let transition = (~safe_aids=[], ~quit=false, model) => {
  model,
  safe_aids,
  quit,
};

let selection_status = (snapshot, interaction) => {
  let count =
    row_count_for_tab(snapshot, interaction, interaction.active_tab);
  let title = focused_tab_title(interaction.active_tab);
  if (count == 0) {
    title ++ ": no selectable rows";
  } else {
    Printf.sprintf(
      "%s row %d of %d",
      title,
      selected_row_for_tab(interaction, interaction.active_tab) + 1,
      count,
    );
  };
};

let update_interaction = (~status_message=?, model, interaction) => {
  let interaction = clamp_interaction(model.snapshot, interaction);
  {
    ...model,
    interaction,
    status_message,
  };
};

let set_filter_text = (model, text) => {
  let filter_text = Projection.sanitize(text);
  let interaction = {
    ...model.interaction,
    filter_text,
  };
  let model =
    update_interaction(
      ~status_message=
        if (filter_text == "") {
          "Search filter cleared";
        } else {
          "Search filter: " ++ filter_text;
        },
      model,
      interaction,
    );

  transition(model);
};

let append_filter_char = (model, c) =>
  set_filter_text(model, model.interaction.filter_text ++ String.make(1, c));

let remove_filter_char = model => {
  let text = model.interaction.filter_text;
  let next =
    if (text == "") {
      "";
    } else {
      String.sub(text, 0, String.length(text) - 1);
    };
  set_filter_text(model, next);
};

let web_handoff_message = handoff =>
  "Web Dashboard: " ++ handoff.command ++ " | " ++ handoff.url;

let normalize_root = root =>
  try(Some(Unix.realpath(root))) {
  | _ => None
  };

let path_inside = (~root, path) =>
  path == root
  || {
    let prefix =
      if (String.length(root) > 0 && root.[String.length(root) - 1] == '/') {
        root;
      } else {
        root ++ "/";
      };
    starts_with(path, prefix);
  };

let validate_local_path = (~local_surfaces, path) => {
  let path = Projection.sanitize(path);
  if (path == "") {
    Error("No local path selected for inspection.");
  } else {
    let surfaces =
      local_surfaces
      |> List.filter_map(surface =>
           switch (normalize_root(surface.root)) {
           | Some(root) =>
             Some({
               ...surface,
               root,
             })
           | None => None
           }
         );

    switch (surfaces) {
    | [] =>
      Error(
        "No Workspace Repository local inspection surfaces are configured.",
      )
    | surfaces =>
      let candidates =
        if (Filename.is_relative(path)) {
          List.map(
            surface => (surface, Filename.concat(surface.root, path)),
            surfaces,
          );
        } else {
          List.map(surface => (surface, path), surfaces);
        };

      let rec loop = outside_seen => (
        fun
        | [] =>
          if (outside_seen) {
            Error(
              "Local path is outside allowed Workspace Repository surfaces: "
              ++ path,
            );
          } else {
            Error(
              "Local path is unavailable for read-only inspection: " ++ path,
            );
          }
        | [(surface, candidate), ...rest] =>
          switch (Unix.realpath(candidate)) {
          | resolved when path_inside(~root=surface.root, resolved) =>
            Ok(resolved)
          | _ => loop(true, rest)
          | exception _ => loop(outside_seen, rest)
          }
      );

      loop(false, candidates);
    };
  };
};

let selected_safe_aid = model =>
  visible_safe_aids(model.snapshot, model.interaction)
  |> (aids => list_nth_opt(aids, model.interaction.selected_rows.safe_aid));

let selected_local_path = model =>
  switch (selected_safe_aid(model)) {
  | Some(Projection.Show_path(path)) => Some(path)
  | _ =>
    switch (selected_task(~interaction=model.interaction, model.snapshot)) {
    | Some({
        Projection.goal_loop: Some({ diagnostics_path: Some(path), _ }),
        _,
      }) =>
      Some(path)
    | Some({
        Projection.context_status: Some({ diagnostics_path: Some(path), _ }),
        _,
      }) =>
      Some(path)
    | _ =>
      model.snapshot.Projection.safe_aids
      |> List.find_map(
           fun
           | Projection.Show_path(path) => Some(path)
           | _ => None,
         )
    }
  };

let inspect_selected_path = (~local_surfaces, model) =>
  switch (selected_local_path(model)) {
  | None =>
    transition({
      ...model,
      status_message:
        Some("No local path is available for the current selection."),
    })
  | Some(path) =>
    switch (validate_local_path(~local_surfaces, path)) {
    | Error(message) =>
      transition({
        ...model,
        status_message: Some(message),
      })
    | Ok(path) =>
      transition(
        {
          ...model,
          status_message: Some("Inspect path read-only: " ++ path),
        },
        ~safe_aids=[Projection.Show_path(path)],
      )
    }
  };

let logs_scroll_step = model =>
  switch (logs_window_size(model.terminal_size)) {
  | Some(step) => step
  | None => 10
  };

let move_log_scroll = (delta, model) => {
  let log_count = List.length(sanitize_logs(model.logs));
  let max_scroll = max(0, log_count - 1);
  let logs_scroll =
    max(0, min(max_scroll, model.interaction.logs_scroll + delta));
  let interaction = {
    ...model.interaction,
    logs_scroll,
  };
  let status_message =
    if (log_count == 0) {
      "Logs: no captured lines";
    } else {
      Printf.sprintf("Logs line %d of %d", logs_scroll + 1, log_count);
    };

  transition(update_interaction(~status_message, model, interaction));
};

let selected_queue_row = model =>
  visible_queue_rows(model.snapshot, model.interaction)
  |> (rows => list_nth_opt(rows, model.interaction.selected_rows.queue));

let toggle_queue_expansion = model =>
  switch (selected_queue_row(model)) {
  | None =>
    transition({
      ...model,
      status_message: Some("Queue: no row selected"),
    })
  | Some(row) =>
    let expanded_queue_id =
      switch (model.interaction.expanded_queue_id) {
      | Some(id) when id == row.id => None
      | _ => Some(row.id)
      };

    let status_message =
      switch (expanded_queue_id) {
      | Some(_) => Printf.sprintf("Queue details: %s %s", row.id, row.title)
      | None => "Queue details hidden"
      };

    let interaction = {
      ...model.interaction,
      expanded_queue_id,
    };
    transition(update_interaction(~status_message, model, interaction));
  };

let supported_settings_themes = Terminal_console_settings.supported_themes;

let settings_theme_index = theme => {
  let rec loop = index =>
    fun
    | [] => 0
    | [candidate, ...rest] =>
      if (candidate == theme) {
        index;
      } else {
        loop(index + 1, rest);
      };

  loop(0, supported_settings_themes);
};

let settings_theme_at = index => {
  let count = List.length(supported_settings_themes);
  let normalized = (index mod count + count) mod count;
  List.nth(supported_settings_themes, normalized);
};

let move_settings_theme = (delta, theme) =>
  settings_theme_at(settings_theme_index(theme) + delta);

let settings_field_label =
  fun
  | Settings_theme => "Terminal Console theme"
  | Settings_port => "Web Dashboard port";

let move_settings_field = delta =>
  fun
  | Settings_theme =>
    if (delta > 0) {
      Settings_port;
    } else {
      Settings_port;
    }
  | Settings_port =>
    if (delta > 0) {
      Settings_theme;
    } else {
      Settings_theme;
    };

let open_settings_modal = model => {
  let modal = {
    draft_theme: model.settings.theme,
    draft_port: string_of_int(model.settings.port),
    focused_field: Settings_theme,
    validation_message: None,
  };

  let interaction = {
    ...model.interaction,
    filter_active: false,
    help_visible: false,
    settings_modal: Some(modal),
  };

  transition(
    update_interaction(~status_message="Settings shown", model, interaction),
  );
};

let close_settings_modal = (~status_message="Settings cancelled", model) => {
  let interaction = {
    ...model.interaction,
    settings_modal: None,
  };
  transition(update_interaction(~status_message, model, interaction));
};

let update_settings_modal = (model, modal, ~status_message=?, ()) => {
  let interaction = {
    ...model.interaction,
    settings_modal: Some(modal),
  };
  transition(update_interaction(~status_message?, model, interaction));
};

let printable_settings_char =
  fun
  | ' ' .. '~' => true
  | _ => false;

let save_settings_modal = (~save_settings, model, modal) =>
  switch (Terminal_console_settings.validate_port(modal.draft_port)) {
  | Terminal_console_settings.Port_invalid(reason) =>
    let modal = {
      ...modal,
      validation_message: Some(reason),
    };
    update_settings_modal(model, modal, ~status_message=reason, ());
  | Terminal_console_settings.Port_valid(port) =>
    let theme =
      Terminal_console_settings.theme_of_validation(
        Terminal_console_settings.validate_theme(modal.draft_theme),
      );
    switch (
      save_settings({
        theme,
        port,
      })
    ) {
    | Settings_saved(settings) =>
      let interaction = {
        ...model.interaction,
        settings_modal: None,
      };
      let web_handoff =
        web_handoff_with_port(model.web_handoff, settings.port);
      let status_message =
        Printf.sprintf(
          "Settings saved: Terminal Console theme %s | Web Dashboard port %d",
          settings.theme,
          settings.port,
        );

      transition(
        update_interaction(
          ~status_message,
          {
            ...model,
            settings,
            web_handoff,
          },
          interaction,
        ),
      );
    | Settings_rejected(reason) =>
      let modal = {
        ...modal,
        validation_message: Some(reason),
      };
      update_settings_modal(model, modal, ~status_message=reason, ());
    | Settings_failed(reason) =>
      let message = "Settings save failed: " ++ reason;
      let modal = {
        ...modal,
        validation_message: Some(message),
      };
      update_settings_modal(model, modal, ~status_message=message, ());
    };
  };

let apply_settings_key = (~save_settings, key, model, modal) =>
  switch (key) {
  | Escape_key => close_settings_modal(model)
  | Enter_key => save_settings_modal(~save_settings, model, modal)
  | Tab_key
  | Down_key
  | Character('j') =>
    let modal = {
      ...modal,
      focused_field: move_settings_field(1, modal.focused_field),
      validation_message: None,
    };
    update_settings_modal(
      model,
      modal,
      ~status_message=
        "Settings field: " ++ settings_field_label(modal.focused_field),
      (),
    );
  | Up_key
  | Character('k') =>
    let modal = {
      ...modal,
      focused_field: move_settings_field(-1, modal.focused_field),
      validation_message: None,
    };
    update_settings_modal(
      model,
      modal,
      ~status_message=
        "Settings field: " ++ settings_field_label(modal.focused_field),
      (),
    );
  | Left_key
  | Character('h') when modal.focused_field == Settings_theme =>
    let modal = {
      ...modal,
      draft_theme: move_settings_theme(-1, modal.draft_theme),
      validation_message: None,
    };
    update_settings_modal(
      model,
      modal,
      ~status_message="Terminal Console theme: " ++ modal.draft_theme,
      (),
    );
  | Right_key
  | Character('l') when modal.focused_field == Settings_theme =>
    let modal = {
      ...modal,
      draft_theme: move_settings_theme(1, modal.draft_theme),
      validation_message: None,
    };
    update_settings_modal(
      model,
      modal,
      ~status_message="Terminal Console theme: " ++ modal.draft_theme,
      (),
    );
  | Backspace_key when modal.focused_field == Settings_port =>
    let draft_port =
      if (modal.draft_port == "") {
        "";
      } else {
        String.sub(modal.draft_port, 0, String.length(modal.draft_port) - 1);
      };

    update_settings_modal(
      model,
      {
        ...modal,
        draft_port,
        validation_message: None,
      },
      (),
    );
  | Character(c)
      when modal.focused_field == Settings_port && printable_settings_char(c) =>
    let draft_port = modal.draft_port ++ String.make(1, c);
    update_settings_modal(
      model,
      {
        ...modal,
        draft_port,
        validation_message: None,
      },
      (),
    );
  | Space_key when modal.focused_field == Settings_port =>
    let draft_port = modal.draft_port ++ " ";
    update_settings_modal(
      model,
      {
        ...modal,
        draft_port,
        validation_message: None,
      },
      (),
    );
  | _ => transition(model)
  };

let apply_key =
    (
      ~web_handoff=default_web_handoff(),
      ~local_surfaces=[],
      ~save_settings=default_save_settings,
      key,
      model,
    ) =>
  if (model.interaction.filter_active) {
    switch (key) {
    | Escape_key =>
      let interaction = {
        ...model.interaction,
        filter_active: false,
        filter_text: "",
      };
      transition(
        update_interaction(
          ~status_message="Search cancelled",
          model,
          interaction,
        ),
      );
    | Enter_key =>
      let interaction = {
        ...model.interaction,
        filter_active: false,
      };
      transition(
        update_interaction(
          ~status_message="Search applied",
          model,
          interaction,
        ),
      );
    | Backspace_key => remove_filter_char(model)
    | Space_key => append_filter_char(model, ' ')
    | Character(c) => append_filter_char(model, c)
    | _ => transition(model)
    };
  } else if (model.interaction.help_visible) {
    switch (key) {
    | Character('q') => transition(~quit=true, model)
    | Character('s') => open_settings_modal(model)
    | Character('?')
    | Escape_key =>
      let interaction = {
        ...model.interaction,
        help_visible: false,
      };
      transition(
        update_interaction(
          ~status_message="Commands hidden",
          model,
          interaction,
        ),
      );
    | _ => transition(model)
    };
  } else {
    switch (model.interaction.settings_modal) {
    | Some(modal) => apply_settings_key(~save_settings, key, model, modal)
    | None =>
      switch (key) {
      | Character('q') => transition(~quit=true, model)
      | Escape_key => transition(~quit=true, model)
      | Character('?') =>
        let interaction = {
          ...model.interaction,
          help_visible: true,
        };
        transition(
          update_interaction(
            ~status_message="Commands shown",
            model,
            interaction,
          ),
        );
      | Character('s') => open_settings_modal(model)
      | Character('/') =>
        let interaction = {
          ...model.interaction,
          filter_active: true,
        };
        transition(
          update_interaction(
            ~status_message="Search visible rows",
            model,
            interaction,
          ),
        );
      | Character('r') =>
        transition(
          {
            ...model,
            status_message:
              Some("Refreshed latest in-memory Runtime State snapshot"),
          },
          ~safe_aids=[Projection.Refresh_view],
        )
      | Character('w') =>
        transition(
          {
            ...model,
            status_message: Some(web_handoff_message(web_handoff)),
          },
          ~safe_aids=[Projection.Show_web_handoff],
        )
      | Character('o') => inspect_selected_path(~local_surfaces, model)
      | Character('h')
      | Left_key =>
        let interaction = move_tab(-1, model.interaction);
        transition(
          update_interaction(
            ~status_message=
              "Tab: " ++ focused_tab_title(interaction.active_tab),
            model,
            interaction,
          ),
        );
      | Character('l')
      | Right_key
      | Tab_key =>
        let interaction = move_tab(1, model.interaction);
        transition(
          update_interaction(
            ~status_message=
              "Tab: " ++ focused_tab_title(interaction.active_tab),
            model,
            interaction,
          ),
        );
      | Character('j')
      | Down_key =>
        if (model.interaction.active_tab == Logs) {
          move_log_scroll(1, model);
        } else {
          let interaction = move_row(1, model.snapshot, model.interaction);
          transition(
            update_interaction(
              ~status_message=selection_status(model.snapshot, interaction),
              model,
              interaction,
            ),
          );
        }
      | Character('k')
      | Up_key =>
        if (model.interaction.active_tab == Logs) {
          move_log_scroll(-1, model);
        } else {
          let interaction = move_row(-1, model.snapshot, model.interaction);
          transition(
            update_interaction(
              ~status_message=selection_status(model.snapshot, interaction),
              model,
              interaction,
            ),
          );
        }
      | Page_down_key =>
        if (model.interaction.active_tab == Logs) {
          move_log_scroll(logs_scroll_step(model), model);
        } else {
          transition(model);
        }
      | Page_up_key =>
        if (model.interaction.active_tab == Logs) {
          move_log_scroll(- logs_scroll_step(model), model);
        } else {
          transition(model);
        }
      | Space_key
      | Character(' ') =>
        if (model.interaction.active_tab == Queue) {
          toggle_queue_expansion(model);
        } else {
          transition(model);
        }
      | Character(_)
      | Enter_key
      | Backspace_key => transition(model)
      }
    };
  };

let render_model = model => {
  let rendered =
    render_snapshot(
      ~terminal_size=?model.terminal_size,
      ~interaction=model.interaction,
      ~logs=model.logs,
      model.snapshot,
    );

  let footer =
    switch (model.status_message) {
    | None => rendered.footer
    | Some(message) => message ++ " | " ++ rendered.footer
    };

  {
    ...rendered,
    footer,
  };
};

let nonempty_lines = fallback =>
  fun
  | [] => [fallback]
  | lines => lines;

let cursor_canvas = Color.rgb(22, 21, 18);
let cursor_canvas_soft = Color.rgb(30, 29, 25);
let cursor_surface_card = Color.rgb(38, 37, 32);
let cursor_surface_strong = Color.rgb(52, 50, 43);
let cursor_ink = Color.rgb(247, 247, 244);
let cursor_body = Color.rgb(214, 211, 202);
let cursor_muted = Color.rgb(160, 156, 146);
let cursor_orange = Color.rgb(245, 78, 0);
let cursor_success = Color.rgb(88, 181, 142);
let cursor_error = Color.rgb(232, 83, 118);
/* Cursor timeline pastels are reserved for agent timeline markers, not global semantics. */
let terminal_console_warning = Color.rgb(218, 164, 65);
let terminal_console_info = Color.rgb(139, 177, 224);

let terminal_console_theme =
  Theme.of_palette(
    Theme.make(
      ~fg_default=cursor_body,
      ~fg_muted=cursor_muted,
      ~fg_emphasis=cursor_ink,
      ~bg_base=cursor_canvas,
      ~bg_surface=cursor_canvas_soft,
      ~bg_overlay=cursor_surface_card,
      ~bg_selection=cursor_surface_strong,
      ~accent_primary=cursor_orange,
      ~accent_secondary=cursor_ink,
      ~status_error=cursor_error,
      ~status_warning=terminal_console_warning,
      ~status_success=cursor_success,
      ~status_info=terminal_console_info,
      (),
    ),
  );

let theme_for_name = name =>
  switch (String.lowercase_ascii(Util.trim(name))) {
  | "cursor-dark" => terminal_console_theme
  | name =>
    switch (Theme.named(name)) {
    | Some(theme) => theme
    | None => terminal_console_theme
    }
  };

let terminal_console_design =
  Components.make_design(~theme=terminal_console_theme, ());

let active_render_theme = ref(terminal_console_theme);

let with_render_theme = (theme, f) => {
  let previous = active_render_theme^;
  active_render_theme := theme;
  Fun.protect(~finally=() => active_render_theme := previous, f);
};

let current_design = () =>
  Components.make_design(~theme=active_render_theme^, ());

let theme_color = slot => active_render_theme^(slot);

let span = (~attrs=[], ~bg=Theme.Bg_surface, slot, text) =>
  Span.make(
    ~style=
      Style.(make(~fg=theme_color(slot), ~bg=theme_color(bg), ~attrs, ())),
    text,
  );

let theme_slot_of_tone =
  fun
  | Components.Neutral => Theme.Fg_muted
  | Components.Accent => Theme.Accent_primary
  | Components.Info => Theme.Status_info
  | Components.Success => Theme.Status_success
  | Components.Warning => Theme.Status_warning
  | Components.Error => Theme.Status_error;

let toned_span = (~attrs=[Attr.Bold], tone, text) =>
  span(~attrs, theme_slot_of_tone(tone), text);

let tab_tone =
  fun
  | Queue => Components.Accent
  | Logs => Components.Info
  | Tasks => Components.Success
  | Readiness => Components.Warning
  | Attention => Components.Error;

let log_default = text => span(Theme.Fg_default, text);
let log_muted = (~attrs=[Attr.Dim], text) =>
  span(~attrs, Theme.Fg_muted, text);
let log_emphasis = text => span(~attrs=[Attr.Bold], Theme.Fg_emphasis, text);
let log_info = text => span(~attrs=[Attr.Bold], Theme.Status_info, text);
let log_success = text =>
  span(~attrs=[Attr.Bold], Theme.Status_success, text);
let log_warning = text =>
  span(~attrs=[Attr.Bold], Theme.Status_warning, text);
let log_error = text => span(~attrs=[Attr.Bold], Theme.Status_error, text);
let log_accent = text =>
  span(~attrs=[Attr.Bold], Theme.Accent_primary, text);
let log_secondary = text =>
  span(~attrs=[Attr.Bold], Theme.Accent_secondary, text);

let lowercase_token = token =>
  token
  |> String.lowercase_ascii
  |> String.map(
       fun
       | ','
       | ';' => ' '
       | c => c,
     )
  |> Util.trim;

let tone_of_keyword =
  fun
  | "running"
  | "ready"
  | "completed"
  | "ok"
  | "success"
  | "succeeded"
  | "active"
  | "merged" => Some(Components.Success)
  | "retrying"
  | "pending"
  | "warning"
  | "skipped"
  | "draft"
  | "not-ready"
  | "not_ready"
  | "kept" => Some(Components.Warning)
  | "attention"
  | "blocked"
  | "failed"
  | "failure"
  | "error"
  | "readiness_blocked" => Some(Components.Error)
  | "checking"
  | "generated"
  | "created"
  | "present"
  | "in_progress"
  | "in_execution"
  | "in_review"
  | "in_planning"
  | "handoff_completed"
  | "handoff_attempting"
  | "handoff_failed" => Some(Components.Info)
  | _ => None;

let split_first_word = text =>
  switch (String.index_opt(text, ' ')) {
  | Some(index) =>
    let first = String.sub(text, 0, index);
    let rest = String.sub(text, index + 1, String.length(text) - index - 1);
    Some((first, rest));
  | None when text != "" => Some((text, ""))
  | None => None
  };

let is_timestamp_token = token => {
  let token = lowercase_token(token);
  let len = String.length(token);
  len >= 5
  && String.contains(token, ':')
  && String.for_all(
       fun
       | '0' .. '9'
       | ':' => true
       | _ => false,
       token,
     );
};

let is_issue_token = token => {
  let token = Projection.sanitize(token);
  token != ""
  && (
    switch (token.[0]) {
    | '#' => true
    | _ => starts_with(token, "ISSUE-") || starts_with(token, "MB-")
    }
  );
};

let is_number_like = token => {
  let token = lowercase_token(token);
  token != ""
  && String.for_all(
       fun
       | '0' .. '9'
       | '.'
       | '%'
       | '/' => true
       | _ => false,
       token,
     );
};

let value_span = value => {
  let display =
    if (is_path_token(value)) {
      compact_path_token(value);
    } else {
      value;
    };
  switch (lowercase_token(value)) {
  | "completed"
  | "created"
  | "ready"
  | "running"
  | "success"
  | "ok" => log_success(display)
  | "failed"
  | "failure"
  | "error"
  | "blocked" => log_error(display)
  | "retrying"
  | "checking"
  | "attention"
  | "skipped"
  | "kept" => log_warning(display)
  | "terminal_console"
  | "compozy_tasks"
  | "github"
  | "minibeads" => log_secondary(display)
  | _ when is_path_token(value) => log_default(display)
  | _ => log_default(display)
  };
};

let key_value_spans = token =>
  switch (String.index_opt(token, '=')) {
  | Some(index) when index > 0 =>
    let key = String.sub(token, 0, index);
    let value =
      String.sub(token, index + 1, String.length(token) - index - 1);
    Some([
      log_muted(~attrs=[], key),
      log_muted(~attrs=[], "="),
      value_span(value),
    ]);
  | _ => None
  };

let token_spans = token =>
  switch (key_value_spans(token)) {
  | Some(spans) => spans
  | None =>
    switch (lowercase_token(token)) {
    | token when token == "" => [log_default(token)]
    | "bootstrap"
    | "startup"
    | "poll"
    | "event" => [log_accent(token)]
    | "created"
    | "ready"
    | "running"
    | "completed"
    | "success"
    | "ok" => [log_success(token)]
    | "present"
    | "checking" => [log_info(token)]
    | "kept"
    | "retrying"
    | "skipped"
    | "attention"
    | "blocked" => [log_warning(token)]
    | "failed"
    | "error"
    | "reason" => [log_error(token)]
    | "tracker"
    | "mode"
    | "runtime_home"
    | "workspace_root"
    | "project_number" => [log_secondary(token)]
    | _ when is_timestamp_token(token) => [log_info(token)]
    | _ when is_path_token(token) => [
        log_default(compact_path_token(token)),
      ]
    | _ => [log_default(token)]
    }
  };

let log_line_spans = line =>
  line
  |> String.split_on_char(' ')
  |> List.filter(token => token != "")
  |> List.mapi((index, token) => {
       let prefix =
         if (index == 0) {
           [];
         } else {
           [log_muted(~attrs=[], " ")];
         };
       prefix @ token_spans(token);
     })
  |> List.concat;

let content_label_tone = label => {
  let label = String.lowercase_ascii(label);
  if (contains_substring(label, "error")
      || contains_substring(label, "attention")) {
    Components.Error;
  } else if (contains_substring(label, "readiness")
             || contains_substring(label, "remediation")) {
    Components.Warning;
  } else if (contains_substring(label, "status")
             || contains_substring(label, "active")) {
    Components.Success;
  } else if (contains_substring(label, "updated")
             || contains_substring(label, "progress")) {
    Components.Info;
  } else {
    Components.Accent;
  };
};

let content_prefix_spans = line =>
  if (starts_with(line, "> ")) {
    (
      [toned_span(Components.Accent, ">"), log_muted(~attrs=[], " ")],
      String.sub(line, 2, String.length(line) - 2),
    );
  } else {
    let rec take_spaces = index =>
      if (index < String.length(line) && line.[index] == ' ') {
        take_spaces(index + 1);
      } else {
        index;
      };

    let prefix_len = take_spaces(0);
    if (prefix_len == 0) {
      ([], line);
    } else {
      (
        [log_muted(~attrs=[], String.sub(line, 0, prefix_len))],
        String.sub(line, prefix_len, String.length(line) - prefix_len),
      );
    };
  };

let clause_prefixes = [
  ("issue state ", Components.Info),
  ("stage agent ", Components.Accent),
  ("stage states ", Components.Success),
  ("last event ", Components.Info),
  ("last message ", Components.Info),
  ("harness ", Components.Accent),
  ("harness kind ", Components.Accent),
  ("branch ", Components.Info),
  ("attempt ", Components.Warning),
  ("due ", Components.Info),
  ("status ", Components.Info),
  ("time ", Components.Info),
  ("tokens ", Components.Accent),
  ("reason ", Components.Warning),
  ("lifecycle ", Components.Success),
  ("dispatch state ", Components.Info),
  ("pr readiness ", Components.Warning),
  ("handoff ", Components.Accent),
  ("current step ", Components.Info),
  ("run id ", Components.Info),
  ("task ", Components.Accent),
  ("stage ", Components.Accent),
];

let rec value_token_spans = token => {
  let normalized = lowercase_token(token);
  switch (tone_of_keyword(normalized)) {
  | Some(tone) => [toned_span(tone, token)]
  | None when normalized == "|" || normalized == "-" => [
      log_muted(~attrs=[], token),
    ]
  | None when is_issue_token(token) => [log_secondary(token)]
  | None when starts_with(token, "symphony/") || starts_with(token, "codex/") => [
      log_secondary(token),
    ]
  | None
      when
        is_timestamp_token(token)
        || String.contains(token, 'T')
        && String.contains(token, ':') => [
      log_info(token),
    ]
  | None when is_number_like(token) => [log_emphasis(token)]
  | None when is_path_token(token) => [
      log_default(compact_path_token(token)),
    ]
  | None
      when String.length(token) > 1 && token == String.uppercase_ascii(token) => [
      log_emphasis(token),
    ]
  | None => [log_default(token)]
  };
}

and tokenized_value_spans = text =>
  text
  |> String.split_on_char(' ')
  |> List.filter(token => token != "")
  |> List.mapi((index, token) => {
       let prefix =
         if (index == 0) {
           [];
         } else {
           [log_muted(~attrs=[], " ")];
         };
       prefix @ value_token_spans(token);
     })
  |> List.concat

and clause_spans = clause => {
  let lowered = String.lowercase_ascii(clause);
  switch (
    List.find_opt(
      ((prefix, _)) => starts_with(lowered, prefix),
      clause_prefixes,
    )
  ) {
  | Some((prefix, tone)) =>
    let prefix_len = String.length(prefix);
    let label = String.sub(clause, 0, prefix_len) |> Util.trim;
    let value =
      String.sub(clause, prefix_len, String.length(clause) - prefix_len)
      |> Util.trim;
    [toned_span(tone, label), log_muted(~attrs=[], " ")]
    @ tokenized_value_spans(value);
  | None =>
    switch (split_first_word(clause)) {
    | Some((first, rest)) =>
      switch (tone_of_keyword(lowercase_token(first))) {
      | Some(tone) =>
        [toned_span(tone, first)]
        @ (
          if (rest == "") {
            [];
          } else {
            [log_muted(~attrs=[], " ")] @ tokenized_value_spans(rest);
          }
        )
      | None => tokenized_value_spans(clause)
      }
    | None => []
    }
  };
};

let value_spans = text =>
  text
  |> String.split_on_char('|')
  |> List.map(Util.trim)
  |> List.filter(clause => clause != "")
  |> List.mapi((index, clause) => {
       let prefix =
         if (index == 0) {
           [];
         } else {
           [log_muted(~attrs=[], " | ")];
         };
       prefix @ clause_spans(clause);
     })
  |> List.concat;

let content_line_spans = line => {
  let (prefix_spans, body) = content_prefix_spans(line);
  let body = Projection.sanitize(body);
  let body_spans =
    if (body == "") {
      [];
    } else if (String.for_all(c => c == '-', body)) {
      [log_muted(body)];
    } else {
      switch (String.index_opt(body, ':')) {
      | Some(index) when index > 0 =>
        let label = String.sub(body, 0, index) |> Util.trim;
        let value =
          String.sub(body, index + 1, String.length(body) - index - 1)
          |> Util.trim;
        [toned_span(content_label_tone(label), label ++ ":")]
        @ (
          if (value == "") {
            [];
          } else {
            [log_muted(~attrs=[], " ")] @ value_spans(value);
          }
        );
      | _ =>
        switch (split_first_word(body)) {
        | Some(("No", rest)) =>
          [toned_span(Components.Success, "No")]
          @ (
            if (rest == "") {
              [];
            } else {
              [log_muted(~attrs=[], " "), log_default(rest)];
            }
          )
        | Some(("Resize", rest)) =>
          [toned_span(Components.Info, "Resize")]
          @ (
            if (rest == "") {
              [];
            } else {
              [log_muted(~attrs=[], " "), log_default(rest)];
            }
          )
        | _ => value_spans(body)
        }
      };
    };

  prefix_spans @ body_spans;
};

let line_nodes = (~spaced=false, lines) =>
  lines
  |> nonempty_lines("None")
  |> List.map(line =>
       <J.Text
         style=Style.(
           make(
             ~fg=theme_color(Theme.Fg_default),
             ~bg=theme_color(Theme.Bg_surface),
             ~height=Cells(1),
             ~margin=spacing(~bottom=if (spaced) {1} else {0}, ()),
             (),
           )
         )
         value=line
       />
     );

let content_line_nodes = lines =>
  lines
  |> nonempty_lines("None")
  |> List.map(line =>
       <J.RichText
         style=Style.(
           make(
             ~height=Cells(1),
             ~fg=theme_color(Theme.Fg_default),
             ~bg=theme_color(Theme.Bg_surface),
             ~margin=spacing(~bottom=1, ()),
             (),
           )
         )
         spans={content_line_spans(line)}
       />
     );

let log_line_nodes = lines =>
  lines
  |> nonempty_lines("No background logs captured yet.")
  |> List.map(line =>
       <J.RichText
         style=Style.(
           make(
             ~height=Cells(1),
             ~fg=theme_color(Theme.Fg_default),
             ~bg=theme_color(Theme.Bg_surface),
             (),
           )
         )
         spans={log_line_spans(line)}
       />
     );

let command_help_row = ((key, label)) =>
  <J.RichText
    style=Style.(
      make(~height=Cells(1), ~bg=theme_color(Theme.Bg_surface), ())
    )
    spans=[
      span(~attrs=[Attr.Bold], Theme.Accent_primary, key),
      span(~attrs=[], Theme.Fg_muted, "  "),
      span(~attrs=[], Theme.Fg_default, label),
    ]
  />;

let help_modal_node = () => {
  let rows = List.map(command_help_row, help_commands);
  <J.Modal
    id="terminal-console-command-modal"
    tone=Components.Info
    design={current_design()}
    style=Style.(make(~width=Cells(72), ~height=Cells(15), ()))
    title="Commands">
    <J.Column style=Style.(make(~flex_grow=1., ()))> ...rows </J.Column>
  </J.Modal>;
};

let settings_modal_lines = (_settings, modal) => {
  let marker = field =>
    if (modal.focused_field == field) {
      "> ";
    } else {
      "  ";
    };
  let validation =
    switch (modal.validation_message) {
    | None => []
    | Some(message) => ["Validation: " ++ message]
    };

  [
    marker(Settings_theme) ++ "Terminal Console theme: " ++ modal.draft_theme,
    marker(Settings_port)
    ++ "Web Dashboard port: "
    ++ (
      if (modal.draft_port == "") {
        "<empty>";
      } else {
        modal.draft_port;
      }
    ),
  ]
  @ validation
  @ ["Enter save | Esc cancel | Up/Down field | Left/Right theme | type port"];
};

let settings_modal_node = (settings, modal) => {
  let lines = content_line_nodes(settings_modal_lines(settings, modal));
  <J.Modal
    id="terminal-console-settings-modal"
    tone=Components.Info
    design={current_design()}
    style=Style.(make(~width=Cells(78), ~height=Cells(9), ()))
    title="Terminal Console Settings">
    <J.Column style=Style.(make(~flex_grow=1., ()))> ...lines </J.Column>
  </J.Modal>;
};

let find_panel = (rendered, title) =>
  List.find_opt(panel => panel.title == title, rendered.panels);

let active_panel = (rendered, interaction) =>
  switch (find_panel(rendered, tab_title(interaction.active_tab))) {
  | Some(panel) => panel
  | None =>
    switch (rendered.panels) {
    | [panel, ..._] => panel
    | [] => {
        title: tab_title(interaction.active_tab),
        lines: ["No content available."],
      }
    }
  };

let footer_segment_spans = text => {
  let text = Util.trim(text);
  switch (String.index_opt(text, ']')) {
  | Some(index) when starts_with(text, "[") =>
    let key = String.sub(text, 1, index - 1);
    let label = String.sub(text, index + 1, String.length(text) - index - 1);
    [
      toned_span(Components.Accent, "[" ++ key ++ "]"),
      span(Theme.Fg_muted, label),
    ];
  | _ => content_line_spans(text)
  };
};

let footer_spans = text =>
  text
  |> String.split_on_char('|')
  |> List.mapi((index, segment) => {
       let prefix =
         if (index == 0) {
           [];
         } else {
           [span(Theme.Fg_muted, " | ")];
         };
       prefix @ footer_segment_spans(segment);
     })
  |> List.concat;

let footer_node = rendered =>
  <J.RichText
    style=Style.(
      make(
        ~height=Cells(1),
        ~width=Percent(1.),
        ~bg=theme_color(Theme.Bg_surface),
        ~fg=theme_color(Theme.Fg_default),
        (),
      )
    )
    spans={footer_spans(rendered.footer)}
  />;

let tab_node = (active, tab) => {
  let tone = tab_tone(tab);
  let attrs =
    if (active) {
      [Attr.Bold, Attr.Underline];
    } else {
      [Attr.Dim];
    };
  <J.RichText
    style=Style.(
      make(~height=Cells(1), ~bg=theme_color(Theme.Bg_surface), ())
    )
    spans=[toned_span(~attrs, tone, tab_title(tab))]
  />;
};

let header_node = (rendered, active_tab, mode) => {
  let title =
    <J.Text
      style=Style.(
        make(
          ~fg=theme_color(Theme.Fg_emphasis),
          ~bg=theme_color(Theme.Bg_base),
          ~attrs=[Attr.Bold],
          (),
        )
      )
      value={rendered.heading}
    />;

  let subtitle =
    <J.Text
      style=Style.(
        make(
          ~fg=theme_color(Theme.Fg_default),
          ~bg=theme_color(Theme.Bg_base),
          (),
        )
      )
      value={rendered.subheading}
    />;

  let badges =
    [
      (tab_tone(active_tab), tab_title(active_tab)),
      (status_badge_tone(mode), rendered.status_label),
    ]
    |> List.map(((tone, label)) =>
         <J.Badge tone design={current_design()} label />
       );

  <J.Box
    style=Style.(
      make(
        ~height=Cells(3),
        ~flex_direction=Row,
        ~justify_content=Space_between,
        ~align_items=Align_center,
        ~padding=spacing_xy(~x=2, ~y=0),
        (),
      )
    )>
    <J.Box style=Style.(make(~flex_direction=Column, ()))>
      title
      subtitle
    </J.Box>
    <J.Box style=Style.(make(~flex_direction=Row, ~gap=1, ()))>
      ...badges
    </J.Box>
  </J.Box>;
};

let view = model =>
  with_render_theme(
    theme_for_name(model.settings.theme),
    () => {
      let rendered = render_model(model);
      let panel = active_panel(rendered, model.interaction);
      let active_tab = model.interaction.active_tab;
      let tab_nodes =
        List.map(tab => tab_node(tab == active_tab, tab), tab_order);
      let scroll_children =
        if (model.interaction.active_tab == Logs) {
          log_line_nodes(panel.lines);
        } else {
          content_line_nodes(panel.lines);
        };
      let children = [
        header_node(rendered, active_tab, model.snapshot.mode),
        <J.Row
          style=Style.(
            make(
              ~height=Cells(1),
              ~align_items=Align_center,
              ~padding=spacing_xy(~x=2, ~y=0),
              ~bg=theme_color(Theme.Bg_surface),
              (),
            )
          )>
          <J.Row gap=2> ...tab_nodes </J.Row>
        </J.Row>,
        <J.Panel
          title={panel.title}
          tone={tab_tone(active_tab)}
          design={current_design()}
          style=Style.(
            make(
              ~flex_grow=1.,
              ~flex_shrink=1.,
              ~min_height=Cells(0),
              ~bg=theme_color(Theme.Bg_surface),
              (),
            )
          )>
          <J.ScrollBox
            style=Style.(
              make(
                ~flex_grow=1.,
                ~flex_shrink=1.,
                ~min_height=Cells(0),
                ~flex_direction=Column,
                ~bg=theme_color(Theme.Bg_surface),
                (),
              )
            )>
            ...scroll_children
          </J.ScrollBox>
        </J.Panel>,
        footer_node(rendered),
      ];

      let children =
        switch (model.interaction.settings_modal) {
        | Some(modal) =>
          children @ [settings_modal_node(model.settings, modal)]
        | None when model.interaction.help_visible =>
          children @ [help_modal_node()]
        | None => children
        };

      <J.Box
        style=Style.(
          make(
            ~width=Percent(1.),
            ~height=Percent(1.),
            ~flex_direction=Column,
            ~padding=spacing_xy(~x=1, ~y=0),
            ~gap=1,
            ~bg=theme_color(Theme.Bg_base),
            ~fg=theme_color(Theme.Fg_default),
            (),
          )
        )>
        ...children
      </J.Box>;
    },
  );

let init = (runtime, ()) => (
  initial_model(
    ~logs=runtime.initial_logs,
    ~web_handoff=runtime.web_handoff,
    ~settings=runtime.settings,
    runtime.initial_state,
  ),
  (),
);

let update = (runtime, msg, model) =>
  switch (msg) {
  | Snapshot_received(state) =>
    let snapshot = Projection.of_runtime_state(state);
    let interaction = clamp_interaction(snapshot, model.interaction);
    (
      {
        ...model,
        snapshot,
        status_label: status_label(snapshot.mode),
        status_message: None,
        interaction,
      },
      false,
    );
  | Key_press(key) =>
    let transition =
      apply_key(
        ~web_handoff=model.web_handoff,
        ~local_surfaces=runtime.local_surfaces,
        ~save_settings=runtime.save_settings,
        key,
        model,
      );

    List.iter(runtime.safe_aid, transition.safe_aids);
    (transition.model, transition.quit);
  | Resize({ columns, rows }) => (
      {
        ...model,
        terminal_size:
          Some({
            columns,
            rows,
          }),
      },
      false,
    )
  };

let ui_key_of_tui_key = (key: Key.event) =>
  switch (key.name) {
  | "return" => Some(Enter_key)
  | "backspace"
  | "delete" => Some(Backspace_key)
  | "escape" => Some(Escape_key)
  | "up" => Some(Up_key)
  | "down" => Some(Down_key)
  | "left" => Some(Left_key)
  | "right" => Some(Right_key)
  | "tab" => Some(Tab_key)
  | "space" => Some(Space_key)
  | "pageup" => Some(Page_up_key)
  | "pagedown" => Some(Page_down_key)
  | name when !key.ctrl && !key.alt && String.length(name) == 1 =>
    Some(Character(name.[0]))
  | _ => None
  };

type live_state = {
  mutex: Mutex.t,
  mutable model,
  mutable quit: bool,
};

let create_live_state = model => {
  mutex: Mutex.create(),
  model,
  quit: false,
};

let with_live_state = (live, f) => {
  Mutex.lock(live.mutex);
  Fun.protect(~finally=() => Mutex.unlock(live.mutex), () => f(live));
};

let update_live = (runtime, live, msg) =>
  with_live_state(
    live,
    live => {
      let (model, quit) = update(runtime, msg, live.model);
      live.model = model;
      live.quit = live.quit || quit;
    },
  );

let append_log_live = (live, line) =>
  with_live_state(live, live =>
    live.model = append_log_line(live.model, line)
  );

let close_noerr = fd =>
  try(Unix.close(fd)) {
  | _ => ()
  };

let emit_log_line = (append, line) => {
  let line = Projection.sanitize(line);
  if (line != "") {
    append(line);
  };
};

let read_fd_lines = (fd, append) => {
  let bytes = Bytes.create(4096);
  let pending = Buffer.create(4096);
  let flush_pending = () =>
    if (Buffer.length(pending) > 0) {
      emit_log_line(append, Buffer.contents(pending));
      Buffer.clear(pending);
    };

  let rec read_loop = () =>
    switch (Unix.read(fd, bytes, 0, Bytes.length(bytes))) {
    | 0 => flush_pending()
    | count =>
      for (index in 0 to count - 1) {
        switch (Bytes.get(bytes, index)) {
        | '\n' =>
          emit_log_line(append, Buffer.contents(pending));
          Buffer.clear(pending);
        | '\r' =>
          if (Buffer.length(pending) > 0) {
            Buffer.add_char(pending, ' ');
          }
        | c => Buffer.add_char(pending, c)
        };
      };
      read_loop();
    | exception (
                  [@implicit_arity]
                  Unix.Unix_error(Unix.EBADF | Unix.EINVAL, _, _)
                ) =>
      flush_pending()
    | exception _ => flush_pending()
    };

  Fun.protect(~finally=() => close_noerr(fd), read_loop);
};

let with_stderr_capture = (append, f) => {
  let original = Unix.dup(Unix.stderr);
  let (read_fd, write_fd) = Unix.pipe();
  let _reader = Thread.create(() => read_fd_lines(read_fd, append), ());

  let capture_active = ref(false);
  Fun.protect(
    ~finally=
      () => {
        if (capture_active^) {
          try(Unix.dup2(original, Unix.stderr)) {
          | _ => ()
          };
        };
        close_noerr(original);
        close_noerr(write_fd);
        close_noerr(read_fd);
      },
    () => {
      Unix.dup2(write_fd, Unix.stderr);
      capture_active := true;
      close_noerr(write_fd);
      f();
    },
  );
};

let current_terminal_size = () => {
  let viewport = Terminal.viewport();
  {
    columns: viewport.Viewport.width,
    rows: viewport.height,
  };
};

let render_once = (runtime, live, renderer) => {
  let size = current_terminal_size();
  update_live(runtime, live, Resize(size));
  let model = with_live_state(live, live => live.model);
  Renderer.resize(renderer, ~width=size.columns, ~height=size.rows);
  Renderer.set_root(renderer, view(model));
  Renderer.render(renderer);
};

let print_non_interactive = model =>
  render_model(model) |> rendered_lines |> List.iter(print_endline);

let run = runtime => {
  let (initial_model, _) = init(runtime, ());
  if (!Terminal.is_interactive()) {
    print_non_interactive(initial_model);
  } else {
    let live = create_live_state(initial_model);
    let renderer = Renderer.create(view(initial_model));
    let fd = Unix.descr_of_in_channel(stdin);
    Fun.protect(
      ~finally=Terminal.leave_alternate,
      () => {
        Terminal.enter_alternate();
        with_stderr_capture(
          line => append_log_live(live, line),
          () => {
            ignore(
              Thread.create(
                () =>
                  runtime.subscribe(state =>
                    update_live(runtime, live, Snapshot_received(state))
                  ),
                (),
              ),
            );
            Terminal.with_raw(fd, () =>
              while (!with_live_state(live, live => live.quit)) {
                render_once(runtime, live, renderer);
                switch (Unix.select([fd], [], [], 0.1)) {
                | ([], _, _) => ()
                | _ =>
                  switch (Key.read(fd)) {
                  | Some(key) when key.ctrl && key.name == "c" =>
                    with_live_state(live, live => live.quit = true)
                  | Some(key) =>
                    Option.iter(
                      ui_key =>
                        update_live(runtime, live, Key_press(ui_key)),
                      ui_key_of_tui_key(key),
                    )
                  | None => ()
                  }
                };
              }
            );
          },
        );
      },
    );
  };
};
