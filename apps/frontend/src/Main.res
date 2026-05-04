%%raw(`import "@heroui/react/styles";`)
%%raw(`import "./styles.css";`)
%%raw(`
function shortDescription(value) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (!text) return "No description provided.";
  return text.length > 180 ? text.slice(0, 177) + "..." : text;
}
function arrayOrEmpty(value) {
  return Array.isArray(value) ? value : [];
}
`)

type domElement
type root

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
  url: option<string>,
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
  status_order: array<string>,
}

@val @scope("document") external getElementById: string => Nullable.t<domElement> = "getElementById"
@module("react-dom/client") external createRoot: domElement => root = "createRoot"
@send external render: (root, React.element) => unit = "render"

@val external shortDescription: string => string = "shortDescription"
@val external arrayOrEmpty: array<'value> => array<'value> = "arrayOrEmpty"
external audioNotificationState: runtimeState => AudioNotifications.runtimeState = "%identity"

let readinessText = state =>
  if Array.length(arrayOrEmpty(state.readiness_gaps)) > 0 {
    "Readiness Gaps: " ++
    (arrayOrEmpty(state.readiness_gaps)
    ->Array.map(gap => gap.requirement ++ ": " ++ gap.remediation)
    ->Array.join("; "))
  } else {
    ""
  }

let taskErrorForIssue = (state, issueId) => {
  switch arrayOrEmpty(state.issue_errors)->Array.find(error => error.issue_id == issueId) {
  | Some(error) => error.error
  | None =>
    switch arrayOrEmpty(state.retrying)->Array.find(error => error.issue_id == issueId) {
    | Some(error) =>
      switch error.error {
      | Some(message) => message
      | None => ""
      }
    | None => ""
    }
  }
}

let renderDashboard = (root, ~snapshot, ~error, ~audioEnabled, ~onAudioToggle) =>
  root->render(
    <ReactRouter.HashRouter>
      <Dashboard snapshot error audioEnabled onAudioToggle />
    </ReactRouter.HashRouter>,
  )

let snapshotFromState = state => {
  Dashboard.running: state.counts.running->Int.toString,
  retrying: state.counts.retrying->Int.toString,
  tokens: state.codex_totals.total_tokens->Int.toString,
  generatedAt: state.generated_at,
  readinessGaps: readinessText(state),
  lastError: switch state.last_error {
  | Some(value) => value
  | None => ""
  },
  statusOrder: arrayOrEmpty(state.status_order),
  issues: arrayOrEmpty(state.issues)->Array.map(issue => {
    let description = switch issue.description {
    | Some(value) => value
    | None => ""
    }
    {
      Dashboard.identifier: issue.issue_identifier,
      title: issue.title,
      state: issue.state,
      url: switch issue.url {
      | Some(value) => value
      | None => ""
      },
      description: description->shortDescription,
      error: taskErrorForIssue(state, issue.issue_id),
    }
  }),
}

switch getElementById("root")->Nullable.toOption {
| Some(element) =>
  let root = createRoot(element)
  let latestSnapshot = ref(None)
  let latestState = ref(None)
  let latestError = ref(None)
  let audioEnabled = ref(AudioNotifications.readAudioNotificationsEnabled())
  let rec rerender = () =>
    renderDashboard(
      root,
      ~snapshot=latestSnapshot.contents,
      ~error=latestError.contents,
      ~audioEnabled=audioEnabled.contents,
      ~onAudioToggle=enabled => {
        audioEnabled := enabled
        AudioNotifications.setAudioNotificationsEnabled(enabled)
        rerender()
      },
    )
  rerender()
  ignore(LiveState.connectLiveState(
    state => {
      let previousAudioState = switch latestState.contents {
      | Some(previous) => Some(audioNotificationState(previous))
      | None => None
      }
      AudioNotifications.maybeEmitAudioNotification(
        audioEnabled.contents,
        previousAudioState,
        audioNotificationState(state),
      )
      let snapshot = snapshotFromState(state)
      latestState := Some(state)
      latestSnapshot := Some(snapshot)
      latestError := None
      rerender()
    },
    message => {
      latestError := Some(message)
      rerender()
    },
  ))
| None => ()
}
