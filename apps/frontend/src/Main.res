%%raw(`import "./styles.css";`)
%%raw(`
function shortDescription(value) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (!text) return "No description provided.";
  return text.length > 180 ? text.slice(0, 177) + "..." : text;
}
`)

type domElement
type root
type response
type jsError

type counts = {
  running: int,
  retrying: int,
}

type codexTotals = {total_tokens: int}

type readinessGap = {
  requirement: string,
  remediation: string,
}

type taskError = {
  issue_id: string,
  issue_identifier: string,
  error: option<string>,
}

type blockedTaskError = {
  issue_id: string,
  issue_identifier: string,
  error: string,
}

type runningIssue = {
  issue_id: string,
  issue_identifier: string,
  title: string,
  state: string,
  description: option<string>,
}

type runtimeState = {
  counts: counts,
  codex_totals: codexTotals,
  generated_at: string,
  last_error: option<string>,
  readiness_gaps: array<readinessGap>,
  issues: array<runningIssue>,
  running: array<runningIssue>,
  retrying: array<taskError>,
  issue_errors: array<blockedTaskError>,
}

@val @scope("document") external getElementById: string => Nullable.t<domElement> = "getElementById"
@module("react-dom/client") external createRoot: domElement => root = "createRoot"
@send external render: (root, React.element) => unit = "render"

@val
external fetch: (
  string,
  {"headers": {"Accept": string}},
) => promise<response> = "fetch"

@get external ok: response => bool = "ok"
@get external status: response => int = "status"
@send external json: response => promise<runtimeState> = "json"
@send external thenPromise: (promise<'value>, 'value => promise<'next>) => promise<'next> = "then"
@send external thenValue: (promise<'value>, 'value => 'next) => promise<'next> = "then"
@send external catchValue: (promise<'value>, 'error => 'value) => promise<'value> = "catch"
@new external makeError: string => jsError = "Error"
@get external message: 'error => Nullable.t<string> = "message"
@val @scope("Promise") external rejectError: jsError => promise<'value> = "reject"
@val external setInterval: (unit => unit, int) => int = "setInterval"
@val external shortDescription: string => string = "shortDescription"

let readinessText = state =>
  if Array.length(state.readiness_gaps) > 0 {
    "Readiness Gaps: " ++
    (state.readiness_gaps
    ->Array.map(gap => gap.requirement ++ ": " ++ gap.remediation)
    ->Array.join("; "))
  } else {
    ""
  }

let taskErrorForIssue = (state, issueId) => {
  switch state.issue_errors->Array.find(error => error.issue_id == issueId) {
  | Some(error) => error.error
  | None =>
    switch state.retrying->Array.find(error => error.issue_id == issueId) {
    | Some(error) =>
      switch error.error {
      | Some(message) => message
      | None => ""
      }
    | None => ""
    }
  }
}

let renderDashboard = (root, ~snapshot, ~error) =>
  root->render(<Dashboard snapshot error />)

let snapshotFromState = state => {
  Dashboard.running: state.counts.running->Int.toString,
  retrying: state.counts.retrying->Int.toString,
  tokens: state.codex_totals.total_tokens->Int.toString,
  generatedAt: state.generated_at,
  lastError: readinessText(state),
  issues: state.issues->Array.map(issue => {
    let description = switch issue.description {
    | Some(value) => value
    | None => ""
    }
    {
      Dashboard.identifier: issue.issue_identifier,
      title: issue.title,
      state: issue.state,
      description: description->shortDescription,
      error: taskErrorForIssue(state, issue.issue_id),
    }
  }),
}

let loadState = (root, latestSnapshot, isLoading) => {
  if isLoading.contents {
    ()
  } else {
    isLoading := true
  fetch("/api/v1/state", {"headers": {"Accept": "application/json"}})
  ->(
    promise =>
      thenPromise(
        promise,
        response => {
          if response->ok {
            response->json
          } else {
            rejectError(makeError("HTTP " ++ response->status->Int.toString))
          }
        },
      )
  )
  ->(
    promise =>
      thenValue(
        promise,
        state => {
          let snapshot = snapshotFromState(state)
          isLoading := false
          latestSnapshot := Some(snapshot)
          renderDashboard(root, ~snapshot=Some(snapshot), ~error=None)
          ()
        },
      )
  )
  ->(
    promise =>
      catchValue(
        promise,
        _error => {
          isLoading := false
          let message = switch _error->message->Nullable.toOption {
          | Some(message) => message
          | None => "Unable to load state"
          }
          renderDashboard(root, ~snapshot=latestSnapshot.contents, ~error=Some(message))
          ()
        },
      )
  )
  ->ignore
  }
}

switch getElementById("root")->Nullable.toOption {
| Some(element) =>
  let root = createRoot(element)
  let latestSnapshot = ref(None)
  let isLoading = ref(false)
  renderDashboard(root, ~snapshot=None, ~error=None)
  loadState(root, latestSnapshot, isLoading)
  setInterval(() => loadState(root, latestSnapshot, isLoading), 5000)->ignore
| None => ()
}
