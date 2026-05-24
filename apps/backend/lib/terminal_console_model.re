type safe_aid =
  | Refresh_view
  | Show_web_handoff
  | Show_path(string);

type goal_usage = {
  status: option(string),
  time_used_seconds: option(float),
  tokens_used: option(int),
  text: option(string),
};

type context_status = {
  state: string,
  summary: string,
  diagnostics_path: option(string),
  text: string,
};

type inspect_detail = {
  label: string,
  value: string,
};

type goal_loop = {
  goal: string,
  state: string,
  stage_agent: option(string),
  harness_name: option(string),
  harness_kind: option(string),
  attempt_count: int,
  budget: option(string),
  latest_evidence: option(string),
  stop_outcome: option(string),
  stop_reason: option(string),
  next_action: option(string),
  diagnostics_path: option(string),
  updated_at: string,
  text: string,
};

type task_row = {
  id: string,
  title: string,
  state: string,
  detail: option(string),
  error: option(string),
  goal_usage: option(goal_usage),
  goal_loop: option(goal_loop),
  context_status: option(context_status),
  inspect_details: list(inspect_detail),
};

type readiness_row = {
  id: string,
  requirement: string,
  remediation: string,
  inspect_details: list(inspect_detail),
};

type compozy_progress = {
  run_id: string,
  slug: string,
  current_step: option(string),
  next_step: option(string),
  completed: int,
  failed: int,
  skipped: int,
  total: int,
  summary: string,
};

type t = {
  generated_at: string,
  mode: string,
  summary: list(string),
  active: list(task_row),
  readiness: list(readiness_row),
  queue_present: bool,
  queue: list(task_row),
  compozy: option(compozy_progress),
  compozy_progresses: list(compozy_progress),
  safe_aids: list(safe_aid),
  last_error: option(string),
};

let is_csi_final = c => {
  let code = Char.code(c);
  code >= 0x40 && code <= 0x7e;
};

let strip_terminal_sequences = text => {
  let len = String.length(text);
  let buffer = Buffer.create(len);
  let rec skip_csi = index =>
    if (index >= len) {
      len;
    } else if (is_csi_final(text.[index])) {
      index + 1;
    } else {
      skip_csi(index + 1);
    };

  let rec skip_osc = index =>
    if (index >= len) {
      len;
    } else {
      switch (text.[index]) {
      | '\007' => index + 1
      | '\027' when index + 1 < len && text.[index + 1] == '\\' => index + 2
      | _ => skip_osc(index + 1)
      };
    };

  let rec loop = index =>
    if (index < len) {
      switch (text.[index]) {
      | '\027' when index + 1 < len && text.[index + 1] == '[' =>
        loop(skip_csi(index + 2))
      | '\027' when index + 1 < len && text.[index + 1] == ']' =>
        loop(skip_osc(index + 2))
      | '\027' => loop(min(len, index + 2))
      | '\n'
      | '\r'
      | '\t' =>
        Buffer.add_char(buffer, ' ');
        loop(index + 1);
      | c when Char.code(c) < 0x20 || Char.code(c) == 0x7f =>
        loop(index + 1)
      | c =>
        Buffer.add_char(buffer, c);
        loop(index + 1);
      };
    };

  loop(0);
  Buffer.contents(buffer);
};

let starts_with = (text, index, prefix) => {
  let prefix_len = String.length(prefix);
  index
  + prefix_len <= String.length(text)
  && String.sub(text, index, prefix_len) == prefix;
};

let secret_value_boundary =
  fun
  | ' '
  | '\n'
  | '\r'
  | '\t'
  | ';' => true
  | _ => false;

let redact_secret_assignments = text => {
  let secret_names = ["GITHUB_TOKEN", "GH_TOKEN"];
  let len = String.length(text);
  let buffer = Buffer.create(len);
  let secret_at = index =>
    switch (
      List.find_opt(name => starts_with(text, index, name), secret_names)
    ) {
    | Some(name) =>
      let next = index + String.length(name);
      if (next < len && text.[next] == '=') {
        Some((name, next));
      } else {
        None;
      };
    | None => None
    };

  let rec skip_value = index =>
    if (index >= len) {
      index;
    } else if (secret_value_boundary(text.[index])) {
      index;
    } else {
      skip_value(index + 1);
    };

  let rec loop = index =>
    if (index < len) {
      switch (secret_at(index)) {
      | Some((name, eq_index)) =>
        Buffer.add_string(buffer, name);
        Buffer.add_string(buffer, "=[redacted]");
        loop(skip_value(eq_index + 1));
      | None =>
        Buffer.add_char(buffer, text.[index]);
        loop(index + 1);
      };
    };

  loop(0);
  Buffer.contents(buffer);
};

let sanitize = text =>
  text |> strip_terminal_sequences |> redact_secret_assignments |> Util.trim;

let inspect_value_max_length = 240;
let inspect_detail_limit = 12;

let truncate_inspect_value = text =>
  if (String.length(text) <= inspect_value_max_length) {
    text;
  } else {
    String.sub(text, 0, inspect_value_max_length - 3) ++ "...";
  };

let sanitize_option =
  fun
  | None => None
  | Some(text) => {
      let sanitized = sanitize(text);
      if (sanitized == "") {
        None;
      } else {
        Some(sanitized);
      };
    };

let inspect_detail = (label, value) =>
  switch (sanitize_option(value)) {
  | Some(value) =>
    Some({
      label: sanitize(label),
      value: truncate_inspect_value(value),
    })
  | None => None
  };

let take = (count, values) => {
  let rec loop = (remaining, kept, values) =>
    switch (remaining, values) {
    | (0, _)
    | (_, []) => List.rev(kept)
    | (remaining, [value, ...rest]) =>
      loop(remaining - 1, [value, ...kept], rest)
    };

  loop(count, [], values);
};

let bounded_inspect_details = details =>
  details |> List.filter_map(Fun.id) |> take(inspect_detail_limit);

let goal_usage_text = (usage: Runtime_state.goal_usage) => {
  let parts =
    []
    |> (
      parts =>
        switch (sanitize_option(usage.status)) {
        | Some(status) => ["status " ++ status, ...parts]
        | None => parts
        }
    )
    |> (
      parts =>
        switch (usage.time_used_seconds) {
        | Some(seconds) => [Printf.sprintf("time %.0fs", seconds), ...parts]
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

  switch (List.rev(parts)) {
  | [] => None
  | parts => Some(String.concat(" | ", parts))
  };
};

let goal_usage = (usage: option(Runtime_state.goal_usage)) =>
  Option.map(
    (usage: Runtime_state.goal_usage) =>
      {
        status: sanitize_option(usage.status),
        time_used_seconds: usage.time_used_seconds,
        tokens_used: usage.tokens_used,
        text: goal_usage_text(usage),
      },
    usage,
  );

let context_status = (status: Runtime_state.context_status) => {
  let state = sanitize(status.state);
  let summary = sanitize(status.summary);
  let text =
    if (summary == "") {
      state;
    } else {
      state ++ ": " ++ summary;
    };
  {
    state,
    summary,
    diagnostics_path: sanitize_option(status.diagnostics_path),
    text,
  };
};

let maybe_context_status = (state, issue_id) =>
  Option.map(
    context_status,
    List.assoc_opt(issue_id, state.Runtime_state.context_statuses),
  );

let issue_title = (state, issue_id, fallback) =>
  switch (
    List.find_opt(
      (issue: Issue.t) => issue.id == issue_id,
      state.Runtime_state.issues,
    )
  ) {
  | Some(issue) => issue.title
  | None => fallback
  };

let issue_branch = (state, issue_id) =>
  switch (
    List.find_opt(
      (issue: Issue.t) => issue.id == issue_id,
      state.Runtime_state.issues,
    )
  ) {
  | Some(issue) => sanitize_option(issue.branch_name)
  | None => None
  };

let append_option = (label, value, parts) =>
  switch (sanitize_option(value)) {
  | Some(value) => [label ++ value, ...parts]
  | None => parts
  };

let detail_text = parts =>
  switch (List.rev(List.filter(value => value != "", parts))) {
  | [] => None
  | parts => Some(String.concat(" | ", parts))
  };

let goal_loop_budget_text = (budget: Runtime_state.goal_loop_budget) => {
  let parts =
    []
    |> (
      parts =>
        switch (budget.max_turns) {
        | Some(turns) => [Printf.sprintf("maxTurns %d", turns), ...parts]
        | None => parts
        }
    )
    |> (
      parts =>
        switch (budget.max_runtime_ms) {
        | Some(runtime) => [
            Printf.sprintf("maxRuntimeMs %d", runtime),
            ...parts,
          ]
        | None => parts
        }
    )
    |> (
      parts =>
        switch (budget.max_tokens) {
        | Some(tokens) => [Printf.sprintf("maxTokens %d", tokens), ...parts]
        | None => parts
        }
    );

  switch (List.rev(parts)) {
  | [] => None
  | parts => Some(String.concat(" | ", parts))
  };
};

let project_goal_loop = (loop: Runtime_state.goal_loop) => {
  let goal = sanitize(loop.goal);
  let state = sanitize(loop.state);
  let stage_agent = sanitize_option(loop.stage_agent);
  let harness_name = sanitize_option(loop.harness_name);
  let harness_kind = sanitize_option(loop.harness_kind);
  let latest_evidence = sanitize_option(loop.latest_evidence);
  let stop_outcome = sanitize_option(loop.stop_outcome);
  let stop_reason = sanitize_option(loop.stop_reason);
  let next_action = sanitize_option(loop.next_action);
  let diagnostics_path = sanitize_option(loop.diagnostics_path);
  let updated_at = sanitize(loop.updated_at);
  let budget = goal_loop_budget_text(loop.budget);
  let text =
    [
      Some("state " ++ state),
      Some(Printf.sprintf("attempt %d", loop.attempt_count)),
      Option.map(outcome => "outcome " ++ outcome, stop_outcome),
      Option.map(evidence => "evidence " ++ evidence, latest_evidence),
      Option.map(action => "next action " ++ action, next_action),
    ]
    |> List.filter_map(Fun.id)
    |> String.concat(" | ");

  {
    goal,
    state,
    stage_agent,
    harness_name,
    harness_kind,
    attempt_count: loop.attempt_count,
    budget,
    latest_evidence,
    stop_outcome,
    stop_reason,
    next_action,
    diagnostics_path,
    updated_at,
    text,
  };
};

let maybe_goal_loop = (state, issue_id) =>
  Option.map(
    project_goal_loop,
    Runtime_state.goal_loop_for_issue(state, issue_id),
  );

let task_state_blocked = state =>
  switch (String.lowercase_ascii(state)) {
  | "failed"
  | "skipped"
  | "budget_exhausted" => true
  | _ => false
  };

let task_state_needs_attention = state =>
  switch (String.lowercase_ascii(state)) {
  | "attention"
  | "needs_attention" => true
  | _ => false
  };

let row_task_label = (row: task_row) =>
  if (row.title == "") {
    row.id;
  } else {
    row.id ++ " " ++ row.title;
  };

let task_row_inspect_details = (row: task_row) => {
  let blocker =
    switch (row.goal_loop) {
    | Some(loop) => loop.stop_reason
    | None =>
      if (task_state_blocked(row.state)) {
        row.detail;
      } else {
        None;
      }
    };

  let status_detail_uses_row_detail =
    task_state_blocked(row.state) || task_state_needs_attention(row.state);

  bounded_inspect_details([
    inspect_detail("Status", Some(row.state)),
    inspect_detail("Blocker", blocker),
    inspect_detail("Current error", row.error),
    inspect_detail(
      "Remediation",
      switch (row.goal_loop) {
      | Some(loop) => loop.next_action
      | None => None
      },
    ),
    inspect_detail(
      "Attention",
      if (task_state_needs_attention(row.state)) {
        row.detail;
      } else {
        None;
      },
    ),
    inspect_detail(
      "Context Status",
      switch (row.context_status) {
      | Some(context) => Some(context.text)
      | None => None
      },
    ),
    inspect_detail("Task", Some(row_task_label(row))),
    inspect_detail(
      "Provenance",
      if (status_detail_uses_row_detail) {
        None;
      } else {
        row.detail;
      },
    ),
    inspect_detail(
      "Goal Loop",
      switch (row.goal_loop) {
      | Some(loop) => Some(loop.text)
      | None => None
      },
    ),
    inspect_detail(
      "Goal Usage",
      switch (row.goal_usage) {
      | Some(usage) => usage.text
      | None => None
      },
    ),
    inspect_detail(
      "Progress Evidence",
      switch (row.goal_loop) {
      | Some(loop) => loop.latest_evidence
      | None => None
      },
    ),
    inspect_detail(
      "Diagnostics",
      switch (row.goal_loop) {
      | Some(loop) => loop.diagnostics_path
      | None => None
      },
    ),
  ]);
};

let with_task_inspect_details = (row: task_row) => {
  ...row,
  inspect_details: task_row_inspect_details(row),
};

let readiness_inspect_details = (row: readiness_row) =>
  bounded_inspect_details([
    inspect_detail("Status", Some("readiness_blocked")),
    inspect_detail("Blocker", Some(row.requirement)),
    inspect_detail("Remediation", Some(row.remediation)),
  ]);

let with_readiness_inspect_details = (row: readiness_row) => {
  ...row,
  inspect_details: readiness_inspect_details(row),
};

let running_row = (state, row: Runtime_state.running) => {
  let context =
    Runtime_state.context_status_for_issue(state, row.issue.id)
    |> context_status;
  let detail =
    []
    |> append_option("issue state ", Some(row.issue.state))
    |> append_option("stage agent ", row.stage_agent)
    |> append_option("harness ", row.harness_name)
    |> append_option("harness kind ", row.harness_kind)
    |> append_option("branch ", row.issue.branch_name)
    |> append_option("last event ", row.last_event)
    |> append_option("last message ", row.last_message)
    |> (
      parts =>
        if (row.stage_states == []) {
          parts;
        } else {
          [
            "stage states "
            ++ (
              row.stage_states |> List.map(sanitize) |> String.concat(", ")
            ),
            ...parts,
          ];
        }
    );

  {
    id: sanitize(row.issue.identifier),
    title: sanitize(row.issue.title),
    state: "running",
    detail: detail_text(detail),
    error: None,
    goal_usage: goal_usage(row.goal_usage),
    goal_loop: maybe_goal_loop(state, row.issue.id),
    context_status: Some(context),
    inspect_details: [],
  }
  |> with_task_inspect_details;
};

let retrying_row = (state, row: Runtime_state.retrying) => {
  let title = issue_title(state, row.issue_id, row.issue_identifier);
  let branch = issue_branch(state, row.issue_id);
  let detail =
    [
      Printf.sprintf("attempt %d", row.attempt),
      "due " ++ sanitize(row.due_at),
    ]
    |> append_option("branch ", branch);

  {
    id: sanitize(row.issue_identifier),
    title: sanitize(title),
    state: "retrying",
    detail: detail_text(detail),
    error: sanitize_option(row.error),
    goal_usage: goal_usage(row.goal_usage),
    goal_loop: maybe_goal_loop(state, row.issue_id),
    context_status:
      Some(
        Runtime_state.context_status_for_issue(state, row.issue_id)
        |> context_status,
      ),
    inspect_details: [],
  }
  |> with_task_inspect_details;
};

let attention_row = (state, row: Runtime_state.issue_error) => {
  id: sanitize(row.issue_identifier),
  title: sanitize(issue_title(state, row.issue_id, row.issue_identifier)),
  state: "attention",
  detail: Some("Task Needs Attention"),
  error: Some(sanitize(row.error)),
  goal_usage: goal_usage(row.goal_usage),
  goal_loop: maybe_goal_loop(state, row.issue_id),
  context_status: maybe_context_status(state, row.issue_id),
  inspect_details: [],
}
|> with_task_inspect_details;

let goal_loop_needs_attention_state = state =>
  switch (String.lowercase_ascii(state)) {
  | "needs_attention"
  | "budget_exhausted" => true
  | _ => false
  };

let goal_loop_row = (state, loop: Runtime_state.goal_loop) => {
  let projected = project_goal_loop(loop);
  let detail =
    []
    |> append_option("goal ", Some(projected.goal))
    |> append_option("updated ", Some(projected.updated_at));

  {
    id: sanitize(loop.issue_identifier),
    title: sanitize(issue_title(state, loop.issue_id, loop.goal)),
    state: projected.state,
    detail: detail_text(detail),
    error:
      if (goal_loop_needs_attention_state(projected.state)) {
        projected.stop_reason;
      } else {
        None;
      },
    goal_usage: None,
    goal_loop: Some(projected),
    context_status: maybe_context_status(state, loop.issue_id),
    inspect_details: [],
  }
  |> with_task_inspect_details;
};

let readiness_row = (index, gap: Runtime_state.readiness_gap) => {
  let requirement = sanitize(gap.requirement);
  let remediation = sanitize(gap.remediation);
  {
    id: Printf.sprintf("readiness:%d:%s:%s", index, requirement, remediation),
    requirement: requirement,
    remediation: remediation,
    inspect_details: [],
  }
  |> with_readiness_inspect_details;
};

let queue_row = (entry: Runtime_state.ordered_queue_entry) => {
  let reason = sanitize_option(entry.skip_reason);
  let detail =
    switch (String.lowercase_ascii(entry.state), reason) {
    | (_, None) => None
    | ("failed", Some(reason)) => Some("failure reason " ++ reason)
    | ("attention", Some(reason)) => Some("attention reason " ++ reason)
    | ("skipped", Some(reason)) => Some("skip reason " ++ reason)
    | (_, Some(reason)) => Some("reason " ++ reason)
    };

  {
    id: sanitize(entry.issue_identifier),
    title:
      sanitize(Option.value(entry.title, ~default=entry.issue_identifier)),
    state: sanitize(entry.state),
    detail,
    error: reason,
    goal_usage: None,
    goal_loop: None,
    context_status: None,
    inspect_details: [],
  }
  |> with_task_inspect_details;
};

let compozy_progress = (progress: Runtime_state.compozy_progress) => {
  let current_step = sanitize_option(progress.current_step);
  let step = Option.value(current_step, ~default="No active step");
  let slug = sanitize(progress.slug);
  {
    run_id: sanitize(progress.run_id),
    slug,
    current_step,
    next_step: sanitize_option(progress.next_step),
    completed: progress.completed,
    failed: progress.failed,
    skipped: progress.skipped,
    total: progress.total,
    summary: {
      let next =
        switch (sanitize_option(progress.next_step)) {
        | Some(next) => " -> " ++ next
        | None => ""
        };
      Printf.sprintf(
        "%s: %s%s (%d completed, %d failed, %d skipped, %d total)",
        slug,
        step,
        next,
        progress.completed,
        progress.failed,
        progress.skipped,
        progress.total,
      );
    },
  };
};

let first_pending_queue_entry = state =>
  switch (state.Runtime_state.ordered_queue) {
  | None => None
  | Some(queue) =>
    List.find_opt(
      (entry: Runtime_state.ordered_queue_entry) =>
        String.lowercase_ascii(entry.state) == "pending",
      queue.entries,
    )
  };

let queue_has_pending = state =>
  Option.is_some(first_pending_queue_entry(state));

let queue_has_attention = state =>
  switch (state.Runtime_state.ordered_queue) {
  | None => false
  | Some(queue) =>
    List.exists(
      (entry: Runtime_state.ordered_queue_entry) =>
        switch (String.lowercase_ascii(entry.state)) {
        | "attention"
        | "failed" => true
        | _ => false
        },
      queue.entries,
    )
  };

let goal_loops_have_attention = state =>
  List.exists(
    (loop: Runtime_state.goal_loop) =>
      goal_loop_needs_attention_state(loop.state),
    state.Runtime_state.goal_loops,
  );

let goal_loops_have_state = (expected, state) =>
  List.exists(
    (loop: Runtime_state.goal_loop) =>
      String.lowercase_ascii(loop.state) == expected,
    state.Runtime_state.goal_loops,
  );

let display_mode = state =>
  if (state.Runtime_state.issue_errors != []
      || goal_loops_have_attention(state)) {
    "attention";
  } else if (queue_has_attention(state)) {
    "attention";
  } else if (state.retrying != []) {
    "retrying";
  } else if (goal_loops_have_state("retrying", state)) {
    "retrying";
  } else if (state.running != []) {
    "running";
  } else if (goal_loops_have_state("running", state)) {
    "running";
  } else if (state.readiness_gaps != []) {
    "readiness_blocked";
  } else if (queue_has_pending(state)) {
    "ready";
  } else {
    "idle";
  };

let summary = (state, mode, compozy: option(compozy_progress)) => {
  let lines = [
    "Mode: " ++ mode,
    "Tracker: " ++ sanitize(state.Runtime_state.tracker_kind),
    Printf.sprintf("Running: %d", List.length(state.running)),
    Printf.sprintf("Retrying: %d", List.length(state.retrying)),
    Printf.sprintf("Total tokens: %d", state.usage_totals.total_tokens),
  ];

  let lines =
    switch (sanitize_option(state.workspace_repository_name)) {
    | Some(name) => ["Workspace Repository: " ++ name, ...lines]
    | None => lines
    };

  let lines =
    if (state.readiness_gaps == []) {
      lines;
    } else {
      lines
      @ [
        Printf.sprintf(
          "Readiness Gaps: %d",
          List.length(state.readiness_gaps),
        ),
      ];
    };

  let lines =
    switch (first_pending_queue_entry(state)) {
    | Some(entry) =>
      let title = sanitize(Option.value(entry.title, ~default=""));
      let line =
        if (title == "") {
          "Next work: " ++ sanitize(entry.issue_identifier);
        } else {
          Printf.sprintf(
            "Next work: %s %s",
            sanitize(entry.issue_identifier),
            title,
          );
        };

      lines @ [line];
    | None => lines
    };

  let lines =
    switch (compozy) {
    | Some(progress) => lines @ ["Compozy PRD Run: " ++ progress.summary]
    | None => lines
    };
  switch (sanitize_option(state.last_error)) {
  | Some(error) => lines @ ["Last error: " ++ error]
  | None => lines
  };
};

let add_unique = (value, values) =>
  if (List.exists(String.equal(value), values)) {
    values;
  } else {
    [value, ...values];
  };

let safe_path_aids = state => {
  let add_path = (path, paths) =>
    switch (sanitize_option(path)) {
    | Some(path) => add_unique(path, paths)
    | None => paths
    };

  let paths =
    List.fold_left(
      (paths, (_issue_id, status: Runtime_state.context_status)) =>
        add_path(status.diagnostics_path, paths),
      [],
      state.Runtime_state.context_statuses,
    );

  let paths =
    List.fold_left(
      (paths, diagnostic: Runtime_state.context_diagnostic) =>
        add_path(Some(diagnostic.diagnostic_path), paths),
      paths,
      state.context_diagnostics,
    );

  let paths =
    List.fold_left(
      (paths, loop: Runtime_state.goal_loop) =>
        add_path(loop.diagnostics_path, paths),
      paths,
      state.goal_loops,
    );

  let paths =
    List.fold_left(
      (paths, row: Runtime_state.startup_reconciliation) =>
        add_path(row.workspace_path, paths),
      paths,
      state.startup_reconciliation,
    );

  let paths =
    List.fold_left(
      (paths, row: Runtime_state.task_branch_integration) =>
        add_path(row.workspace_path, paths),
      paths,
      state.task_branch_integrations,
    );

  paths |> List.rev |> List.map(path => Show_path(path));
};

let safe_aids = state =>
  [Refresh_view, Show_web_handoff] @ safe_path_aids(state);

let of_runtime_state = state => {
  let mode = display_mode(state);
  let matched_goal_loop_issue_ids =
    List.map(
      (row: Runtime_state.running) => row.issue.id,
      state.Runtime_state.running,
    )
    @ List.map(
        (row: Runtime_state.retrying) => row.issue_id,
        state.retrying,
      )
    @ List.map(
        (row: Runtime_state.issue_error) => row.issue_id,
        state.issue_errors,
      );

  let unmatched_goal_loop_rows =
    state.Runtime_state.goal_loops
    |> List.filter((loop: Runtime_state.goal_loop) =>
         !
           List.exists(
             String.equal(loop.issue_id),
             matched_goal_loop_issue_ids,
           )
       )
    |> List.map(goal_loop_row(state));

  let active =
    List.map(running_row(state), state.Runtime_state.running)
    @ List.map(retrying_row(state), state.retrying)
    @ List.map(attention_row(state), state.issue_errors)
    @ unmatched_goal_loop_rows;

  let readiness = List.mapi(readiness_row, state.readiness_gaps);
  let queue =
    switch (state.ordered_queue) {
    | Some(queue) => List.map(queue_row, queue.entries)
    | None => []
    };

  let compozy = Option.map(compozy_progress, state.compozy_progress);
  let compozy_progresses =
    switch (List.map(compozy_progress, state.compozy_progresses)) {
    | [] => Option.to_list(compozy)
    | progresses => progresses
    };

  {
    generated_at: Util.now_iso8601(),
    mode,
    summary: summary(state, mode, compozy),
    active,
    readiness,
    queue_present: Option.is_some(state.ordered_queue),
    queue,
    compozy,
    compozy_progresses,
    safe_aids: safe_aids(state),
    last_error: sanitize_option(state.last_error),
  };
};
