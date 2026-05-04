%%raw(`import "./styles.css";`)

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

type runtimeState = {
  counts: counts,
  codex_totals: codexTotals,
  generated_at: string,
  last_error: option<string>,
  readiness_gaps: array<readinessGap>,
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

let readinessText = state =>
  if Array.length(state.readiness_gaps) > 0 {
    "Readiness Gaps: " ++
    (state.readiness_gaps
    ->Array.map(gap => gap.requirement ++ ": " ++ gap.remediation)
    ->Array.join("; "))
  } else {
    switch state.last_error {
    | Some(message) => message
    | None => ""
    }
  }

let renderDashboard = (root, ~snapshot, ~error) =>
  root->render(<Dashboard snapshot error />)

let loadState = root => {
  renderDashboard(root, ~snapshot=None, ~error=None)

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
          renderDashboard(
            root,
            ~snapshot=Some({
              running: state.counts.running->Int.toString,
              retrying: state.counts.retrying->Int.toString,
              tokens: state.codex_totals.total_tokens->Int.toString,
              generatedAt: state.generated_at,
              lastError: readinessText(state),
            }),
            ~error=None,
          )
          ()
        },
      )
  )
  ->(
    promise =>
      catchValue(
        promise,
        _error => {
          let message = switch _error->message->Nullable.toOption {
          | Some(message) => message
          | None => "Unable to load state"
          }
          renderDashboard(root, ~snapshot=None, ~error=Some(message))
          ()
        },
      )
  )
  ->ignore
}

switch getElementById("root")->Nullable.toOption {
| Some(element) =>
  let root = createRoot(element)
  loadState(root)
  setInterval(() => loadState(root), 5000)->ignore
| None => ()
}
