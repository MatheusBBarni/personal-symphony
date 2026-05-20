%%raw(`
function shortDescription(value) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (!text) return "No description provided.";
  return text.length > 180 ? text.slice(0, 177) + "..." : text;
}
function arrayOrEmpty(value) {
  return Array.isArray(value) ? value : [];
}
function stringOrEmpty(value) {
  return value === null || value === undefined ? "" : String(value);
}
function stringOrFallback(value, fallback) {
  const text = stringOrEmpty(value);
  return text ? text : fallback;
}
function prefixedString(value, prefix) {
  const text = stringOrEmpty(value);
  return text ? prefix + text : "";
}
function harnessIdentityText(name, kind) {
  const harnessName = stringOrEmpty(name);
  const harnessKind = stringOrEmpty(kind);
  if (harnessName && harnessKind) return harnessName + " (" + harnessKind + ")";
  return harnessName || harnessKind;
}
function goalUsageText(value) {
  if (!value) return "";
  const parts = [];
  if (value.status) parts.push("status " + value.status);
  if (value.time_used_seconds !== null && value.time_used_seconds !== undefined) {
    parts.push("time " + value.time_used_seconds + "s");
  }
  if (value.tokens_used !== null && value.tokens_used !== undefined) {
    parts.push("tokens " + value.tokens_used);
  }
  return parts.join(" | ");
}
function goalLoopBudgetText(value) {
  if (!value) return "";
  const parts = [];
  if (value.max_turns !== null && value.max_turns !== undefined) {
    parts.push("maxTurns " + value.max_turns);
  }
  if (value.max_runtime_ms !== null && value.max_runtime_ms !== undefined) {
    parts.push("maxRuntimeMs " + value.max_runtime_ms);
  }
  if (value.max_tokens !== null && value.max_tokens !== undefined) {
    parts.push("maxTokens " + value.max_tokens);
  }
  return parts.join(" | ");
}
function goalLoopText(value) {
  if (!value) return "";
  const parts = [];
  if (value.state) parts.push("state " + value.state);
  if (value.attempt_count !== null && value.attempt_count !== undefined) {
    parts.push("attempt " + value.attempt_count);
  }
  if (value.stop_outcome) parts.push("outcome " + value.stop_outcome);
  const budget = goalLoopBudgetText(value.budget);
  if (budget) parts.push("budget " + budget);
  if (value.latest_evidence) parts.push("evidence " + value.latest_evidence);
  if (value.stop_reason) parts.push("stop reason " + value.stop_reason);
  if (value.next_action) parts.push("next action " + value.next_action);
  return parts.join(" | ");
}
function contextStatusText(value) {
  if (!value || !value.state) return "";
  const label = String(value.state).replace(/_/g, " ");
  const summary = value.summary ? String(value.summary) : "";
  return summary ? label + ": " + summary : label;
}
`)

type counts = {
  running: int,
  retrying: int,
}

type usageTotals = {total_tokens: int}

type readinessGap = {
  requirement: string,
  remediation: string,
}

type goalUsage = {
  status: option<string>,
  time_used_seconds: option<float>,
  tokens_used: option<int>,
}

type goalLoopBudget = {
  max_turns: option<int>,
  max_runtime_ms: option<int>,
  max_tokens: option<int>,
}

type goalLoop = {
  issue_id: string,
  issue_identifier: string,
  run_id: string,
  goal: string,
  state: string,
  stage_agent: option<string>,
  harness_name: option<string>,
  harness_kind: option<string>,
  attempt_count: int,
  budget: goalLoopBudget,
  latest_evidence: option<string>,
  stop_outcome: option<string>,
  stop_reason: option<string>,
  next_action: option<string>,
  diagnostics_path: option<string>,
  updated_at: string,
}

type contextStatus = {
  state: string,
  summary: option<string>,
  diagnostics_path: option<string>,
}

type taskError = {
  issue_id: string,
  issue_identifier: string,
  error: option<string>,
  goal_usage: option<goalUsage>,
  context_status: option<contextStatus>,
}

type blockedTaskError = {
  issue_id: string,
  issue_identifier: string,
  error: string,
  goal_usage: option<goalUsage>,
}

type orderedQueueEntry = {
  issue_identifier: string,
  title: option<string>,
  state: string,
  skip_reason: option<string>,
}

type orderedQueue = {entries: array<orderedQueueEntry>}

type intakeEvaluation = {
  issue_identifier: string,
  eligible: bool,
  state: option<string>,
  reason: option<string>,
}

type compozyProgress = {
  run_id: string,
  slug: string,
  current_step: option<string>,
  completed: int,
  failed: int,
  skipped: int,
  total: int,
  lifecycle_state: option<string>,
  dispatch_state: option<string>,
  stage_agent: option<string>,
  pr_readiness: option<string>,
  reason: option<string>,
  handoff_status: option<string>,
}

type startupReconciliation = {
  issue_identifier: option<string>,
  task_branch: option<string>,
  category: string,
  message: string,
}

type runningIssue = {
  issue_id: string,
  issue_identifier: string,
  title: string,
  state: string,
  url: option<string>,
  description: option<string>,
  goal_usage: option<goalUsage>,
  context_status: option<contextStatus>,
  harness_name: option<string>,
  harness_kind: option<string>,
  sandbox_enabled: option<bool>,
  sandbox_provider: option<string>,
  sandbox_reuse_outcome: option<string>,
}

type runtimeState = {
  workspace_repository_name: option<string>,
  tracker_kind: string,
  counts: counts,
  usage_totals: usageTotals,
  generated_at: string,
  last_error: option<string>,
  readiness_gaps: array<readinessGap>,
  startup_reconciliation: array<startupReconciliation>,
  issues: array<runningIssue>,
  running: array<runningIssue>,
  retrying: array<taskError>,
  issue_errors: array<blockedTaskError>,
  goal_loops: array<goalLoop>,
  status_order: array<string>,
  ordered_queue: option<orderedQueue>,
  intake_evaluations: array<intakeEvaluation>,
  compozy_progress: option<compozyProgress>,
}

@val external shortDescription: string => string = "shortDescription"
@val external arrayOrEmpty: array<'value> => array<'value> = "arrayOrEmpty"
@val external stringOrEmpty: option<string> => string = "stringOrEmpty"
@val external stringOrFallback: (option<string>, string) => string = "stringOrFallback"
@val external prefixedString: (option<string>, string) => string = "prefixedString"
@val external harnessIdentityText: (option<string>, option<string>) => string =
  "harnessIdentityText"
@val external goalUsageText: option<goalUsage> => string = "goalUsageText"
@val external contextStatusText: option<contextStatus> => string = "contextStatusText"
@send external toLowerCase: string => string = "toLowerCase"
@val external goalLoopText: option<goalLoop> => string = "goalLoopText"

let readinessText = state =>
  if Array.length(arrayOrEmpty(state.readiness_gaps)) > 0 {
    "Readiness Gaps: " ++
    (arrayOrEmpty(state.readiness_gaps)
    ->Array.map(gap => gap.requirement ++ ": " ++ gap.remediation)
    ->Array.join("; "))
  } else {
    ""
  }

let startupReconciliationText = state =>
  if Array.length(arrayOrEmpty(state.startup_reconciliation)) > 0 {
    arrayOrEmpty(state.startup_reconciliation)
    ->Array.map(row => {
      let identifier = stringOrFallback(row.issue_identifier, "startup")
      let branch = prefixedString(row.task_branch, " ")
      identifier ++ branch ++ " " ++ row.category ++ ": " ++ row.message
    })
    ->Array.join("; ")
  } else {
    ""
  }

let taskErrorForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.issue_errors)->Array.find(error => error.issue_id == issueId) {
  | Some(error) => error.error
  | None =>
    switch arrayOrEmpty(state.retrying)->Array.find(error => error.issue_id == issueId) {
    | Some(error) => stringOrEmpty(error.error)
    | None => ""
    }
  }
}

let goalUsageForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.running)->Array.find(issue => issue.issue_id == issueId) {
  | Some(issue) => goalUsageText(issue.goal_usage)
  | None =>
    switch arrayOrEmpty(state.issue_errors)->Array.find(error => error.issue_id == issueId) {
    | Some(error) => goalUsageText(error.goal_usage)
    | None =>
      switch arrayOrEmpty(state.retrying)->Array.find(error => error.issue_id == issueId) {
      | Some(error) => goalUsageText(error.goal_usage)
      | None => ""
      }
    }
  }
}

let goalLoopForIssue = (state, issueId) =>
  arrayOrEmpty(state.goal_loops)->Array.find(loop => loop.issue_id == issueId)

let goalLoopTextForIssue = (state, issueId) =>
  switch goalLoopForIssue(state, issueId) {
  | Some(loop) => goalLoopText(Some(loop))
  | None => ""
  }

let goalLoopStateForIssue = (state, issueId) =>
  switch goalLoopForIssue(state, issueId) {
  | Some(loop) => stringOrEmpty(Some(loop.state))
  | None => ""
  }

let contextStatusForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.running)->Array.find(issue => issue.issue_id == issueId) {
  | Some(issue) => contextStatusText(issue.context_status)
  | None =>
    switch arrayOrEmpty(state.retrying)->Array.find(error => error.issue_id == issueId) {
    | Some(error) => contextStatusText(error.context_status)
    | None => ""
    }
  }
}

let harnessIdentityForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.running)->Array.find(issue => issue.issue_id == issueId) {
  | Some(issue) => harnessIdentityText(issue.harness_name, issue.harness_kind)
  | None => ""
  }
}

let sandboxForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.running)->Array.find(issue => issue.issue_id == issueId) {
  | Some(issue) =>
    switch issue.sandbox_enabled {
    | Some(true) =>
      let provider = stringOrFallback(issue.sandbox_provider, "sandbox")
      let reuseOutcome = stringOrEmpty(issue.sandbox_reuse_outcome)
      if reuseOutcome == "" {
        provider
      } else {
        provider ++ " " ++ reuseOutcome
      }
    | Some(false) | None => ""
    }
  | None => ""
  }
}

let orderedQueueEntries = state =>
  switch state.ordered_queue {
  | Some(queue) =>
    arrayOrEmpty(queue.entries)->Array.map(entry => {
      Dashboard.identifier: entry.issue_identifier,
      title: stringOrEmpty(entry.title),
      state: entry.state,
      skipReason: stringOrEmpty(entry.skip_reason),
    })
  | None => []
  }

let intakeEvaluationForIssue = (state, issueIdentifier) =>
  arrayOrEmpty(state.intake_evaluations)->Array.find(
    evaluation => evaluation.issue_identifier == issueIdentifier,
  )

let intakeStateLabel = (evaluation: option<intakeEvaluation>) =>
  switch evaluation {
  | None => ""
  | Some(evaluation) =>
    let fallback = if evaluation.eligible {
      "ready"
    } else {
      "not_ready"
    }
    switch stringOrFallback(evaluation.state, fallback)->toLowerCase {
    | "ready" => "Ready for intake"
    | "queue_blocked" => "Queue blocked"
    | "parse_blocked" => "Parse blocked"
    | "admitted" => "Already admitted"
    | "not_ready" => "Not ready"
    | _ when evaluation.eligible => "Ready for intake"
    | _ => "Not ready"
    }
  }

let intakeReasonText = (evaluation: option<intakeEvaluation>) =>
  switch evaluation {
  | None => ""
  | Some(evaluation) => stringOrEmpty(evaluation.reason)
  }

let compozyProgressForDashboard = state =>
  switch state.compozy_progress {
  | Some(progress) =>
    Some({
      Dashboard.runId: progress.run_id,
      slug: progress.slug,
      currentStep: stringOrFallback(progress.current_step, "No active step"),
      completed: progress.completed->Int.toString,
      failed: progress.failed->Int.toString,
      skipped: progress.skipped->Int.toString,
      total: progress.total->Int.toString,
      lifecycleState: stringOrEmpty(progress.lifecycle_state),
      dispatchState: stringOrEmpty(progress.dispatch_state),
      stageAgent: stringOrEmpty(progress.stage_agent),
      prReadiness: stringOrEmpty(progress.pr_readiness),
      reason: stringOrEmpty(progress.reason),
      handoffStatus: stringOrEmpty(progress.handoff_status),
    })
  | None => None
  }

let snapshotFromState = state => {
  Dashboard.workspaceRepositoryName: stringOrEmpty(state.workspace_repository_name),
  trackerKind: RuntimeState.trackerKindOrDefault(state.tracker_kind),
  Dashboard.running: state.counts.running->Int.toString,
  retrying: state.counts.retrying->Int.toString,
  tokens: state.usage_totals.total_tokens->Int.toString,
  generatedAt: state.generated_at,
  readinessGaps: readinessText(state),
  startupReconciliation: startupReconciliationText(state),
  lastError: stringOrEmpty(state.last_error),
  statusOrder: arrayOrEmpty(state.status_order),
  orderedQueue: orderedQueueEntries(state),
  compozyProgress: compozyProgressForDashboard(state),
  issues: arrayOrEmpty(state.issues)->Array.map(issue => {
    let intakeEvaluation = intakeEvaluationForIssue(state, issue.issue_identifier)
    {
      Dashboard.identifier: issue.issue_identifier,
      title: issue.title,
      state: issue.state,
      url: stringOrEmpty(issue.url),
      description: issue.description->stringOrEmpty->shortDescription,
      error: taskErrorForIssue(state, issue.issue_id),
      goalUsage: goalUsageForIssue(state, issue.issue_id),
      goalLoop: goalLoopTextForIssue(state, issue.issue_id),
      goalLoopState: goalLoopStateForIssue(state, issue.issue_id),
      contextStatus: contextStatusForIssue(state, issue.issue_id),
      harnessIdentity: harnessIdentityForIssue(state, issue.issue_id),
      intakeState: intakeStateLabel(intakeEvaluation),
      intakeReason: intakeReasonText(intakeEvaluation),
      sandbox: sandboxForIssue(state, issue.issue_id),
    }
  }),
}
