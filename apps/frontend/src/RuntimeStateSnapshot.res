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
  status_order: array<string>,
  ordered_queue: option<orderedQueue>,
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
  issues: arrayOrEmpty(state.issues)->Array.map(issue => {
    {
      Dashboard.identifier: issue.issue_identifier,
      title: issue.title,
      state: issue.state,
      url: stringOrEmpty(issue.url),
      description: issue.description->stringOrEmpty->shortDescription,
      error: taskErrorForIssue(state, issue.issue_id),
      goalUsage: goalUsageForIssue(state, issue.issue_id),
      contextStatus: contextStatusForIssue(state, issue.issue_id),
      harnessIdentity: harnessIdentityForIssue(state, issue.issue_id),
    }
  }),
}
