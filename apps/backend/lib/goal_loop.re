type budget = {
  max_turns: option(int),
  max_runtime_ms: option(int),
  max_tokens: option(int),
};

type t = {
  issue_id: string,
  issue_identifier: string,
  run_id: string,
  goal: string,
  state: string,
  stage_agent: option(string),
  harness_name: option(string),
  harness_kind: option(string),
  attempt_count: int,
  budget,
  latest_evidence: option(string),
  stop_outcome: option(string),
  stop_reason: option(string),
  next_action: option(string),
  diagnostics_path: option(string),
  updated_at: string,
};

let running = "running";
let retrying = "retrying";
let goal_met = "goal_met";
let needs_attention = "needs_attention";
let budget_exhausted = "budget_exhausted";

let max_summary_bytes = 512;

let bounded = text => {
  let text = Util.trim(text);
  if (String.length(text) <= max_summary_bytes) {
    text;
  } else {
    String.sub(text, 0, max_summary_bytes) |> Util.trim;
  };
};

let terminal_state = state =>
  state == goal_met || state == needs_attention || state == budget_exhausted;

let create =
    (
      issue_id,
      issue_identifier,
      run_id,
      goal,
      stage_agent,
      harness_name,
      harness_kind,
      attempt_count,
      budget,
      updated_at,
    ) => {
  issue_id,
  issue_identifier,
  run_id,
  goal: bounded(goal),
  state: running,
  stage_agent,
  harness_name,
  harness_kind,
  attempt_count,
  budget,
  latest_evidence: Some("Agent dispatched."),
  stop_outcome: None,
  stop_reason: None,
  next_action: Some("Wait for agent activity."),
  diagnostics_path: None,
  updated_at,
};

let record_activity = (loop, attempt_count, latest_evidence, next_action, updated_at) =>
  if (terminal_state(loop.state)) {
    loop;
  } else {
    {
      ...loop,
      state: running,
      attempt_count,
      latest_evidence: Some(bounded(latest_evidence)),
      stop_outcome: None,
      stop_reason: None,
      next_action: Some(bounded(next_action)),
      updated_at,
    };
  };

let schedule_retry = (loop, attempt_count, reason, updated_at) =>
  if (terminal_state(loop.state)) {
    loop;
  } else {
    {
      ...loop,
      state: retrying,
      attempt_count,
      latest_evidence: Some(bounded(reason)),
      stop_outcome: None,
      stop_reason: None,
      next_action: Some("Retry scheduled for the next agent attempt."),
      updated_at,
    };
  };

let stop_needs_attention = (loop, reason, updated_at) => {
  ...loop,
  state: needs_attention,
  latest_evidence: Some(bounded(reason)),
  stop_outcome: Some(needs_attention),
  stop_reason: Some(bounded(reason)),
  next_action: Some("Operator attention is required before the loop can continue."),
  updated_at,
};

let stop_budget_exhausted = (loop, reason, updated_at) => {
  ...loop,
  state: budget_exhausted,
  latest_evidence: Some(bounded(reason)),
  stop_outcome: Some(budget_exhausted),
  stop_reason: Some(bounded(reason)),
  next_action: Some("Review the budget exhaustion before continuing the task."),
  updated_at,
};
