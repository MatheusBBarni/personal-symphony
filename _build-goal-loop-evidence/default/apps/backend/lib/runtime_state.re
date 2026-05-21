type tokens = {
  input_tokens: int,
  output_tokens: int,
  total_tokens: int,
};
type goal_usage = {
  status: option(string),
  time_used_seconds: option(float),
  tokens_used: option(int),
};
type context_status = {
  state: string,
  summary: string,
  diagnostics_path: option(string),
};
type goal_loop_budget = {
  max_turns: option(int),
  max_runtime_ms: option(int),
  max_tokens: option(int),
};

type goal_loop = {
  issue_id: string,
  issue_identifier: string,
  run_id: string,
  goal: string,
  state: string,
  stage_agent: option(string),
  harness_name: option(string),
  harness_kind: option(string),
  attempt_count: int,
  budget: goal_loop_budget,
  latest_evidence: option(string),
  stop_outcome: option(string),
  stop_reason: option(string),
  next_action: option(string),
  diagnostics_path: option(string),
  updated_at: string,
};

type running = {
  issue: Issue.t,
  stage_agent: option(string),
  harness_name: option(string),
  harness_kind: option(string),
  sandbox_enabled: option(bool),
  sandbox_provider: option(string),
  sandbox_reuse_outcome: option(string),
  stage_states: list(string),
  session_id: option(string),
  turn_count: int,
  last_event: option(string),
  last_message: option(string),
  started_at: string,
  last_event_at: option(string),
  tokens,
  goal_usage: option(goal_usage),
};

type retrying = {
  issue_id: string,
  issue_identifier: string,
  attempt: int,
  due_at: string,
  error: option(string),
  goal_usage: option(goal_usage),
};
type issue_error = {
  issue_id: string,
  issue_identifier: string,
  error: string,
  goal_usage: option(goal_usage),
};
type readiness_gap = {
  requirement: string,
  remediation: string,
};
type ordered_queue_entry = {
  issue_identifier: string,
  title: option(string),
  state: string,
  skip_reason: option(string),
};
type ordered_queue = {entries: list(ordered_queue_entry)};
type intake_evaluation = {
  issue_identifier: string,
  eligible: bool,
  state: string,
  reason: option(string),
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
  lifecycle_state: option(string),
  dispatch_state: option(string),
  stage_agent: option(string),
  pr_readiness: option(string),
  reason: option(string),
  handoff_status: option(string),
};
type startup_reconciliation = {
  issue_id: option(string),
  issue_identifier: option(string),
  task_branch: option(string),
  workspace_path: option(string),
  category: string,
  message: string,
};
type task_branch_integration = {
  issue_id: string,
  issue_identifier: string,
  task_branch: string,
  workspace_path: option(string),
  result: string,
  direct_fast_forward: bool,
  task_branch_updated_from_loop_start: bool,
  attention: option(string),
  message: string,
};
type pull_request_handoff = {
  enabled: bool,
  mode: string,
  issue_identifier: option(string),
  head_branch: option(string),
  base_branch: option(string),
  status: string,
  url: option(string),
  error: option(string),
};

type context_diagnostic = {
  issue_id: string,
  issue_identifier: string,
  stage_agent: option(string),
  diagnostic_id: string,
  diagnostic_path: string,
  command_name: option(string),
  cwd_kind: option(string),
  timed_out: option(bool),
  exit_code: option(int),
  stdout_bytes: option(int),
  stderr_bytes: option(int),
  stdout_truncated: option(bool),
};

type t = {
  workspace_repository_name: option(string),
  tracker_kind: string,
  issues: list(Issue.t),
  running: list(running),
  retrying: list(retrying),
  issue_errors: list(issue_error),
  goal_loops: list(goal_loop),
  status_order: list(string),
  readiness_gaps: list(readiness_gap),
  context_statuses: list((string, context_status)),
  usage_totals: tokens,
  seconds_running: float,
  rate_limits: option(Yojson.Safe.t),
  pull_request: option(pull_request_handoff),
  pull_requests: list(pull_request_handoff),
  ordered_queue: option(ordered_queue),
  intake_evaluations: list(intake_evaluation),
  compozy_progress: option(compozy_progress),
  compozy_progresses: list(compozy_progress),
  startup_reconciliation: list(startup_reconciliation),
  task_branch_integrations: list(task_branch_integration),
  context_diagnostics: list(context_diagnostic),
  last_error: option(string),
};

let empty_goal_loop_budget = {
  max_turns: None,
  max_runtime_ms: None,
  max_tokens: None,
};

let empty =
    (
      ~workspace_repository_name=?,
      ~tracker_kind="github",
      ~readiness_gaps=[],
      ~status_order=[],
      ~ordered_queue=?,
      ~intake_evaluations=[],
      ~goal_loops=[],
      ~compozy_progress=?,
      ~compozy_progresses=[],
      ~last_error=?,
      (),
    ) => {
  let compozy_progresses =
    switch (compozy_progresses, compozy_progress) {
    | ([], Some(progress)) => [progress]
    | _ => compozy_progresses
    };

  {
    workspace_repository_name,
    tracker_kind,
    running: [],
    issues: [],
    retrying: [],
    issue_errors: [],
    goal_loops,
    status_order,
    readiness_gaps,
    context_statuses: [],
    usage_totals: {
      input_tokens: 0,
      output_tokens: 0,
      total_tokens: 0,
    },
    seconds_running: 0.,
    rate_limits: None,
    pull_request: None,
    pull_requests: [],
    ordered_queue,
    intake_evaluations,
    compozy_progress,
    compozy_progresses,
    startup_reconciliation: [],
    task_branch_integrations: [],
    context_diagnostics: [],
    last_error,
  };
};

let option_string =
  fun
  | Some(value) => `String(value)
  | None => `Null;
let option_int =
  fun
  | Some(value) => `Int(value)
  | None => `Null;

let tokens_to_yojson = tokens =>
  `Assoc([
    ("input_tokens", `Int(tokens.input_tokens)),
    ("output_tokens", `Int(tokens.output_tokens)),
    ("total_tokens", `Int(tokens.total_tokens)),
  ]);

let goal_usage_to_yojson = (usage: goal_usage) =>
  `Assoc([
    (
      "status",
      switch (usage.status) {
      | Some(value) => `String(value)
      | None => `Null
      },
    ),
    (
      "time_used_seconds",
      switch (usage.time_used_seconds) {
      | Some(value) => `Float(value)
      | None => `Null
      },
    ),
    (
      "tokens_used",
      switch (usage.tokens_used) {
      | Some(value) => `Int(value)
      | None => `Null
      },
    ),
  ]);

let make_context_status = (~diagnostics_path=?, ~state, ~summary, ()) => {
  state,
  summary,
  diagnostics_path,
};

let skipped_context_status =
  make_context_status(
    ~state="skipped",
    ~summary="Context behavior disabled or not applicable.",
    (),
  );

let set_context_status = (issue_id, context_status, state) => {
  ...state,
  context_statuses: [
    (issue_id, context_status),
    ...List.filter(
         ((existing_issue_id, _)) => existing_issue_id != issue_id,
         state.context_statuses,
       ),
  ],
};

let clear_context_status = (issue_id, state) => {
  ...state,
  context_statuses:
    List.filter(
      ((existing_issue_id, _)) => existing_issue_id != issue_id,
      state.context_statuses,
    ),
};

let context_status_for_issue = (state, issue_id) =>
  switch (List.assoc_opt(issue_id, state.context_statuses)) {
  | Some(context_status) => context_status
  | None => skipped_context_status
  };

let context_status_to_yojson = (status: context_status) =>
  `Assoc([
    ("state", `String(status.state)),
    ("summary", `String(status.summary)),
    (
      "diagnostics_path",
      switch (status.diagnostics_path) {
      | Some(path) => `String(path)
      | None => `Null
      },
    ),
  ]);

let goal_loop_budget_to_yojson = (budget: goal_loop_budget) =>
  `Assoc([
    ("max_turns", option_int(budget.max_turns)),
    ("max_runtime_ms", option_int(budget.max_runtime_ms)),
    ("max_tokens", option_int(budget.max_tokens)),
  ]);

let goal_loop_to_yojson = (loop: goal_loop) =>
  `Assoc([
    ("issue_id", `String(loop.issue_id)),
    ("issue_identifier", `String(loop.issue_identifier)),
    ("run_id", `String(loop.run_id)),
    ("goal", `String(loop.goal)),
    ("state", `String(loop.state)),
    ("stage_agent", option_string(loop.stage_agent)),
    ("harness_name", option_string(loop.harness_name)),
    ("harness_kind", option_string(loop.harness_kind)),
    ("attempt_count", `Int(loop.attempt_count)),
    ("budget", goal_loop_budget_to_yojson(loop.budget)),
    ("latest_evidence", option_string(loop.latest_evidence)),
    ("stop_outcome", option_string(loop.stop_outcome)),
    ("stop_reason", option_string(loop.stop_reason)),
    ("next_action", option_string(loop.next_action)),
    ("diagnostics_path", option_string(loop.diagnostics_path)),
    ("updated_at", `String(loop.updated_at)),
  ]);

let goal_loop_for_issue = (state, issue_id) =>
  List.find_opt(
    (loop: goal_loop) => loop.issue_id == issue_id,
    state.goal_loops,
  );

let issue_to_yojson = issue =>
  `Assoc([
    ("issue_id", `String(issue.Issue.id)),
    ("issue_identifier", `String(issue.identifier)),
    ("title", `String(issue.title)),
    (
      "description",
      switch (issue.description) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("comments", `List(List.map(Issue.comment_to_yojson, issue.comments))),
    (
      "url",
      switch (issue.url) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("state", `String(issue.state)),
    (
      "created_at",
      switch (issue.created_at) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "updated_at",
      switch (issue.updated_at) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
  ]);

let running_to_yojson = (state, row) =>
  `Assoc([
    ("issue_id", `String(row.issue.id)),
    ("issue_identifier", `String(row.issue.identifier)),
    ("title", `String(row.issue.title)),
    (
      "description",
      switch (row.issue.description) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "comments",
      `List(List.map(Issue.comment_to_yojson, row.issue.comments)),
    ),
    (
      "url",
      switch (row.issue.url) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("state", `String(row.issue.state)),
    (
      "stage_agent",
      switch (row.stage_agent) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "harness_name",
      switch (row.harness_name) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "harness_kind",
      switch (row.harness_kind) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "sandbox_enabled",
      switch (row.sandbox_enabled) {
      | Some(enabled) => `Bool(enabled)
      | None => `Null
      },
    ),
    (
      "sandbox_provider",
      switch (row.sandbox_provider) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "sandbox_reuse_outcome",
      switch (row.sandbox_reuse_outcome) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "stage_states",
      `List(List.map(state => `String(state), row.stage_states)),
    ),
    (
      "session_id",
      switch (row.session_id) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("turn_count", `Int(row.turn_count)),
    (
      "last_event",
      switch (row.last_event) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "last_message",
      switch (row.last_message) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("started_at", `String(row.started_at)),
    (
      "last_event_at",
      switch (row.last_event_at) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("tokens", tokens_to_yojson(row.tokens)),
    (
      "goal_usage",
      switch (row.goal_usage) {
      | Some(usage) => goal_usage_to_yojson(usage)
      | None => `Null
      },
    ),
    (
      "context_status",
      context_status_for_issue(state, row.issue.id)
      |> context_status_to_yojson,
    ),
  ]);

let retrying_to_yojson = (state, row: retrying) =>
  `Assoc([
    ("issue_id", `String(row.issue_id)),
    ("issue_identifier", `String(row.issue_identifier)),
    ("attempt", `Int(row.attempt)),
    ("due_at", `String(row.due_at)),
    (
      "error",
      switch (row.error) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "goal_usage",
      switch (row.goal_usage) {
      | Some(usage) => goal_usage_to_yojson(usage)
      | None => `Null
      },
    ),
    (
      "context_status",
      context_status_for_issue(state, row.issue_id)
      |> context_status_to_yojson,
    ),
  ]);

let issue_error_to_yojson = (row: issue_error) =>
  `Assoc([
    ("issue_id", `String(row.issue_id)),
    ("issue_identifier", `String(row.issue_identifier)),
    ("error", `String(row.error)),
    (
      "goal_usage",
      switch (row.goal_usage) {
      | Some(usage) => goal_usage_to_yojson(usage)
      | None => `Null
      },
    ),
  ]);

let readiness_gap_to_yojson = row =>
  `Assoc([
    ("requirement", `String(row.requirement)),
    ("remediation", `String(row.remediation)),
  ]);

let ordered_queue_entry_to_yojson = (row: ordered_queue_entry) =>
  `Assoc([
    ("issue_identifier", `String(row.issue_identifier)),
    (
      "title",
      switch (row.title) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("state", `String(row.state)),
    (
      "skip_reason",
      switch (row.skip_reason) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
  ]);

let ordered_queue_to_yojson = (row: ordered_queue) =>
  `Assoc([
    (
      "entries",
      `List(List.map(ordered_queue_entry_to_yojson, row.entries)),
    ),
  ]);

let intake_evaluation_to_yojson = (row: intake_evaluation) =>
  `Assoc([
    ("issue_identifier", `String(row.issue_identifier)),
    ("eligible", `Bool(row.eligible)),
    ("state", `String(row.state)),
    (
      "reason",
      switch (row.reason) {
      | Some(reason) => `String(reason)
      | None => `Null
      },
    ),
  ]);

let handoff_status_of_lifecycle = (lifecycle: Compozy_lifecycle.t) =>
  switch (lifecycle.pr_readiness) {
  | Compozy_lifecycle.Handoff_attempting
  | Compozy_lifecycle.Handoff_completed
  | Compozy_lifecycle.Handoff_failed =>
    Some(Compozy_lifecycle.pr_readiness_to_string(lifecycle.pr_readiness))
  | _ => None
  };

let pending_step_after = (current_step, steps) => {
  let current_index =
    Option.map(
      (step: Compozy_tasks_tracker.task_step) => step.index,
      current_step,
    );
  steps
  |> List.find_opt((step: Compozy_tasks_tracker.task_step) =>
       String.lowercase_ascii(step.status) == "pending"
       && (
         switch (current_index) {
         | Some(index) => step.index > index
         | None => true
         }
       )
     );
};

let compozy_progress_of_prd_run =
    (~lifecycle=?, run: Compozy_tasks_tracker.prd_run) => {
  let counts = run.counts;
  let next_step = pending_step_after(run.current_step, run.steps);
  {
    run_id: run.id,
    slug: run.slug,
    current_step:
      Option.map(
        (step: Compozy_tasks_tracker.task_step) => step.file,
        run.current_step,
      ),
    next_step:
      Option.map(
        (step: Compozy_tasks_tracker.task_step) => step.file,
        next_step,
      ),
    completed: counts.completed,
    failed: counts.failed,
    skipped: counts.skipped,
    total: counts.total,
    lifecycle_state:
      Option.map(
        lifecycle =>
          Compozy_lifecycle.lifecycle_state_to_string(
            lifecycle.Compozy_lifecycle.lifecycle_state,
          ),
        lifecycle,
      ),
    dispatch_state:
      Option.map(
        lifecycle => lifecycle.Compozy_lifecycle.dispatch_state,
        lifecycle,
      ),
    stage_agent:
      Option.bind(lifecycle, lifecycle =>
        lifecycle.Compozy_lifecycle.stage_agent
      ),
    pr_readiness:
      Option.map(
        lifecycle =>
          Compozy_lifecycle.pr_readiness_to_string(
            lifecycle.Compozy_lifecycle.pr_readiness,
          ),
        lifecycle,
      ),
    reason:
      Option.bind(lifecycle, lifecycle => lifecycle.Compozy_lifecycle.reason),
    handoff_status: Option.bind(lifecycle, handoff_status_of_lifecycle),
  };
};

let lifecycle_metadata_for_progress = (config, run) =>
  switch (Compozy_lifecycle.load_or_backfill_reconciled(config, run)) {
  | Ok(lifecycle) => Some(lifecycle)
  | _ => None
  };

let compozy_progress_of_prd_run_for_runtime = (config, run) =>
  compozy_progress_of_prd_run(
    ~lifecycle=?lifecycle_metadata_for_progress(config, run),
    run,
  );

let initial_compozy_progress = (config: Config.t) =>
  if (config.tracker.kind != "compozy_tasks") {
    None;
  } else {
    switch (
      Compozy_tasks_tracker.discover_prd_runs(
        ~compozy_root=config.tracker.compozy_root,
      )
    ) {
    | Error(_) => None
    | Ok([]) => None
    | Ok(runs) =>
      let selected =
        switch (List.find_opt(Compozy_tasks_tracker.runnable_prd_run, runs)) {
        | Some(run) => Some(run)
        | None =>
          List.find_opt((_: Compozy_tasks_tracker.prd_run) => true, runs)
        };

      Option.map(compozy_progress_of_prd_run_for_runtime(config), selected);
    };
  };

let initial_compozy_progresses = (config: Config.t) =>
  if (config.tracker.kind != "compozy_tasks") {
    [];
  } else {
    switch (
      Compozy_tasks_tracker.discover_prd_runs(
        ~compozy_root=config.tracker.compozy_root,
      )
    ) {
    | Error(_) => []
    | Ok(runs) =>
      List.map(compozy_progress_of_prd_run_for_runtime(config), runs)
    };
  };

let compozy_progress_to_yojson = (row: compozy_progress) => {
  let option_string =
    fun
    | Some(value) => `String(value)
    | None => `Null;
  `Assoc([
    ("run_id", `String(row.run_id)),
    ("slug", `String(row.slug)),
    ("current_step", option_string(row.current_step)),
    ("next_step", option_string(row.next_step)),
    ("completed", `Int(row.completed)),
    ("failed", `Int(row.failed)),
    ("skipped", `Int(row.skipped)),
    ("total", `Int(row.total)),
    ("lifecycle_state", option_string(row.lifecycle_state)),
    ("dispatch_state", option_string(row.dispatch_state)),
    ("stage_agent", option_string(row.stage_agent)),
    ("pr_readiness", option_string(row.pr_readiness)),
    ("reason", option_string(row.reason)),
    ("handoff_status", option_string(row.handoff_status)),
  ]);
};

let startup_reconciliation_to_yojson = (row: startup_reconciliation) =>
  `Assoc([
    (
      "issue_id",
      switch (row.issue_id) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "issue_identifier",
      switch (row.issue_identifier) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "task_branch",
      switch (row.task_branch) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "workspace_path",
      switch (row.workspace_path) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("category", `String(row.category)),
    ("message", `String(row.message)),
  ]);

let task_branch_integration_to_yojson = (row: task_branch_integration) =>
  `Assoc([
    ("issue_id", `String(row.issue_id)),
    ("issue_identifier", `String(row.issue_identifier)),
    ("task_branch", `String(row.task_branch)),
    (
      "workspace_path",
      switch (row.workspace_path) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("result", `String(row.result)),
    ("direct_fast_forward", `Bool(row.direct_fast_forward)),
    (
      "task_branch_updated_from_loop_start",
      `Bool(row.task_branch_updated_from_loop_start),
    ),
    (
      "attention",
      switch (row.attention) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("message", `String(row.message)),
  ]);

let json_member = name =>
  fun
  | `Assoc(fields) => List.assoc_opt(name, fields)
  | _ => None;

let json_string_member = (name, json) =>
  switch (json_member(name, json)) {
  | Some(`String(value)) when Util.trim(value) != "" => Some(value)
  | _ => None
  };

let json_int_member = (name, json) =>
  switch (json_member(name, json)) {
  | Some(`Int(value)) => Some(value)
  | _ => None
  };

let goal_loop_budget_of_yojson = json =>
  switch (json) {
  | `Assoc(_) => {
      max_turns: json_int_member("max_turns", json),
      max_runtime_ms: json_int_member("max_runtime_ms", json),
      max_tokens: json_int_member("max_tokens", json),
    }
  | _ => empty_goal_loop_budget
  };

let goal_loop_of_yojson = json =>
  switch (
    json_string_member("issue_id", json),
    json_string_member("issue_identifier", json),
    json_string_member("run_id", json),
    json_string_member("goal", json),
    json_string_member("state", json),
    json_string_member("updated_at", json),
  ) {
  | (
      Some(issue_id),
      Some(issue_identifier),
      Some(run_id),
      Some(goal),
      Some(state),
      Some(updated_at),
    ) =>
    let budget =
      switch (json_member("budget", json)) {
      | Some(budget) => goal_loop_budget_of_yojson(budget)
      | None => empty_goal_loop_budget
      };
    Some({
      issue_id,
      issue_identifier,
      run_id,
      goal,
      state,
      stage_agent: json_string_member("stage_agent", json),
      harness_name: json_string_member("harness_name", json),
      harness_kind: json_string_member("harness_kind", json),
      attempt_count:
        Option.value(json_int_member("attempt_count", json), ~default=0),
      budget,
      latest_evidence: json_string_member("latest_evidence", json),
      stop_outcome: json_string_member("stop_outcome", json),
      stop_reason: json_string_member("stop_reason", json),
      next_action: json_string_member("next_action", json),
      diagnostics_path: json_string_member("diagnostics_path", json),
      updated_at,
    });
  | _ => None
  };

let goal_loops_from_snapshot_yojson = json =>
  switch (json_member("goal_loops", json)) {
  | Some(`List(loops)) => List.filter_map(goal_loop_of_yojson, loops)
  | _ => []
  };

let ordered_queue_entry_of_yojson = json =>
  switch (json_string_member("issue_identifier", json)) {
  | None => None
  | Some(issue_identifier) =>
    Some({
      issue_identifier,
      title: json_string_member("title", json),
      state:
        Option.value(json_string_member("state", json), ~default="pending"),
      skip_reason: json_string_member("skip_reason", json),
    })
  };

let ordered_queue_of_yojson = json =>
  switch (json_member("entries", json)) {
  | Some(`List(entries)) =>
    Some({
      entries: List.filter_map(ordered_queue_entry_of_yojson, entries),
    })
  | _ => None
  };

let json_bool_member = (name, json) =>
  switch (json_member(name, json)) {
  | Some(`Bool(value)) => Some(value)
  | _ => None
  };

let intake_evaluation_of_yojson = json =>
  switch (json_string_member("issue_identifier", json)) {
  | None => None
  | Some(issue_identifier) =>
    Some({
      issue_identifier,
      eligible:
        Option.value(json_bool_member("eligible", json), ~default=false),
      state:
        Option.value(
          json_string_member("state", json),
          ~default=
            if (Option.value(
                  json_bool_member("eligible", json),
                  ~default=false,
                )) {
              "ready";
            } else {
              "not_ready";
            },
        ),
      reason: json_string_member("reason", json),
    })
  };

let intake_evaluations_from_snapshot_yojson = json =>
  switch (json_member("intake_evaluations", json)) {
  | Some(`List(evaluations)) =>
    List.filter_map(intake_evaluation_of_yojson, evaluations)
  | _ => []
  };

let compozy_progress_of_yojson = json =>
  switch (
    json_string_member("run_id", json),
    json_string_member("slug", json),
  ) {
  | (Some(run_id), Some(slug)) =>
    Some({
      run_id,
      slug,
      current_step: json_string_member("current_step", json),
      next_step: json_string_member("next_step", json),
      completed:
        Option.value(json_int_member("completed", json), ~default=0),
      failed: Option.value(json_int_member("failed", json), ~default=0),
      skipped: Option.value(json_int_member("skipped", json), ~default=0),
      total: Option.value(json_int_member("total", json), ~default=0),
      lifecycle_state: json_string_member("lifecycle_state", json),
      dispatch_state: json_string_member("dispatch_state", json),
      stage_agent: json_string_member("stage_agent", json),
      pr_readiness: json_string_member("pr_readiness", json),
      reason: json_string_member("reason", json),
      handoff_status: json_string_member("handoff_status", json),
    })
  | _ => None
  };

let compozy_progress_from_snapshot_yojson = json =>
  switch (json_member("compozy_progress", json)) {
  | Some(`Assoc(_) as progress) => compozy_progress_of_yojson(progress)
  | _ => None
  };

let compozy_progresses_from_snapshot_yojson = json =>
  switch (json_member("compozy_progresses", json)) {
  | Some(`List(progresses)) =>
    List.filter_map(compozy_progress_of_yojson, progresses)
  | _ =>
    switch (compozy_progress_from_snapshot_yojson(json)) {
    | Some(progress) => [progress]
    | None => []
    }
  };

let tracker_kind_from_snapshot_yojson = json =>
  Option.value(json_string_member("tracker_kind", json), ~default="github");

let pull_request_handoff_to_yojson = row =>
  `Assoc([
    ("enabled", `Bool(row.enabled)),
    ("mode", `String(row.mode)),
    (
      "issue_identifier",
      switch (row.issue_identifier) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "head_branch",
      switch (row.head_branch) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "base_branch",
      switch (row.base_branch) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("status", `String(row.status)),
    (
      "url",
      switch (row.url) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "error",
      switch (row.error) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
  ]);

let context_diagnostic_to_yojson = row =>
  `Assoc([
    ("issue_id", `String(row.issue_id)),
    ("issue_identifier", `String(row.issue_identifier)),
    (
      "stage_agent",
      switch (row.stage_agent) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("diagnostic_id", `String(row.diagnostic_id)),
    ("diagnostic_path", `String(row.diagnostic_path)),
    (
      "command_name",
      switch (row.command_name) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "cwd_kind",
      switch (row.cwd_kind) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    (
      "timed_out",
      switch (row.timed_out) {
      | Some(s) => `Bool(s)
      | None => `Null
      },
    ),
    (
      "exit_code",
      switch (row.exit_code) {
      | Some(s) => `Int(s)
      | None => `Null
      },
    ),
    (
      "stdout_bytes",
      switch (row.stdout_bytes) {
      | Some(s) => `Int(s)
      | None => `Null
      },
    ),
    (
      "stderr_bytes",
      switch (row.stderr_bytes) {
      | Some(s) => `Int(s)
      | None => `Null
      },
    ),
    (
      "stdout_truncated",
      switch (row.stdout_truncated) {
      | Some(s) => `Bool(s)
      | None => `Null
      },
    ),
  ]);

let to_yojson = state =>
  `Assoc([
    ("generated_at", `String(Util.now_iso8601())),
    (
      "workspace_repository_name",
      switch (state.workspace_repository_name) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
    ("tracker_kind", `String(state.tracker_kind)),
    (
      "counts",
      `Assoc([
        ("running", `Int(List.length(state.running))),
        ("retrying", `Int(List.length(state.retrying))),
      ]),
    ),
    ("issues", `List(List.map(issue_to_yojson, state.issues))),
    ("running", `List(List.map(running_to_yojson(state), state.running))),
    (
      "retrying",
      `List(List.map(retrying_to_yojson(state), state.retrying)),
    ),
    (
      "issue_errors",
      `List(List.map(issue_error_to_yojson, state.issue_errors)),
    ),
    ("goal_loops", `List(List.map(goal_loop_to_yojson, state.goal_loops))),
    (
      "status_order",
      `List(List.map(status => `String(status), state.status_order)),
    ),
    (
      "readiness_gaps",
      `List(List.map(readiness_gap_to_yojson, state.readiness_gaps)),
    ),
    (
      "usage_totals",
      `Assoc([
        ("input_tokens", `Int(state.usage_totals.input_tokens)),
        ("output_tokens", `Int(state.usage_totals.output_tokens)),
        ("total_tokens", `Int(state.usage_totals.total_tokens)),
        ("seconds_running", `Float(state.seconds_running)),
      ]),
    ),
    ("rate_limits", Option.value(state.rate_limits, ~default=`Null)),
    (
      "pull_request",
      switch (state.pull_request) {
      | Some(row) => pull_request_handoff_to_yojson(row)
      | None => `Null
      },
    ),
    (
      "pull_requests",
      `List(List.map(pull_request_handoff_to_yojson, state.pull_requests)),
    ),
    (
      "ordered_queue",
      switch (state.ordered_queue) {
      | Some(row) => ordered_queue_to_yojson(row)
      | None => `Null
      },
    ),
    (
      "intake_evaluations",
      `List(List.map(intake_evaluation_to_yojson, state.intake_evaluations)),
    ),
    (
      "compozy_progress",
      switch (state.compozy_progress) {
      | Some(row) => compozy_progress_to_yojson(row)
      | None => `Null
      },
    ),
    (
      "compozy_progresses",
      `List(List.map(compozy_progress_to_yojson, state.compozy_progresses)),
    ),
    (
      "startup_reconciliation",
      `List(
        List.map(
          startup_reconciliation_to_yojson,
          state.startup_reconciliation,
        ),
      ),
    ),
    (
      "task_branch_integrations",
      `List(
        List.map(
          task_branch_integration_to_yojson,
          state.task_branch_integrations,
        ),
      ),
    ),
    (
      "context_diagnostics",
      `List(
        List.map(context_diagnostic_to_yojson, state.context_diagnostics),
      ),
    ),
    (
      "last_error",
      switch (state.last_error) {
      | Some(s) => `String(s)
      | None => `Null
      },
    ),
  ]);
