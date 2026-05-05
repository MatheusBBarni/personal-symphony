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

type goalUsage = {
  status: option<string>,
  time_used_seconds: option<float>,
  tokens_used: option<int>,
}

type taskError = {
  issue_id: string,
  issue_identifier: string,
  error: option<string>,
  goal_usage: option<goalUsage>,
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

type runningIssue = {
  issue_id: string,
  issue_identifier: string,
  title: string,
  state: string,
  url: option<string>,
  description: option<string>,
  goal_usage: option<goalUsage>,
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
  ordered_queue: option<orderedQueue>,
}

@val @scope("document") external getElementById: string => Nullable.t<domElement> = "getElementById"
@module("react-dom/client") external createRoot: domElement => root = "createRoot"
@send external render: (root, React.element) => unit = "render"

@val external shortDescription: string => string = "shortDescription"
@val external arrayOrEmpty: array<'value> => array<'value> = "arrayOrEmpty"
@val external goalUsageText: option<goalUsage> => string = "goalUsageText"
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

let orderedQueueEntries = state =>
  switch state.ordered_queue {
  | Some(queue) =>
    arrayOrEmpty(queue.entries)->Array.map(entry => {
      Dashboard.identifier: entry.issue_identifier,
      title: switch entry.title {
      | Some(value) => value
      | None => ""
      },
      state: entry.state,
      skipReason: switch entry.skip_reason {
      | Some(value) => value
      | None => ""
      },
    })
  | None => []
  }

let navItem = (href, label, isActive) =>
  <a
    href=href
    className={
      "block rounded px-3 py-2 text-sm transition-colors " ++
      if isActive {
        "bg-teal-950/80 text-teal-100"
      } else {
        "text-neutral-400 hover:bg-neutral-900 hover:text-neutral-100"
      }
    }>
    {React.string(label)}
  </a>

module App = {
  @react.component
  let make = (
    ~snapshot: option<Dashboard.snapshot>,
    ~error: option<string>,
    ~audioEnabled: bool,
    ~onAudioToggle: bool => unit,
  ) => {
    let location = ReactRouter.useLocation()
    let isConfiguration = location.pathname == "/configuration"

    <section className="min-h-screen bg-[#0b0b0b] text-neutral-100">
      <div className="grid min-h-screen lg:grid-cols-[240px_minmax(0,1fr)]">
        <aside className="border-b border-neutral-800 bg-neutral-950 px-4 py-4 lg:border-b-0 lg:border-r">
          <div className="flex items-center justify-between gap-4 lg:block">
            <div>
              <div className="text-lg font-semibold tracking-normal text-neutral-50">
                {React.string("Symphony")}
              </div>
              <div className="mt-1 text-xs text-neutral-500">
                {React.string("Workspace Repository control")}
              </div>
            </div>
            <HeroUI.Chip
              size="sm"
              variant="flat"
              className="rounded border border-emerald-800 bg-emerald-950/70 px-3 text-emerald-100 lg:mt-4">
              {React.string("Live OCaml API")}
            </HeroUI.Chip>
          </div>
          <nav className="mt-5 grid grid-cols-2 gap-2 lg:grid-cols-1">
            {navItem("#/", "Orchestrator", !isConfiguration)}
            {navItem("#/configuration", "Configuration", isConfiguration)}
          </nav>
        </aside>
        <main className="min-w-0">
          <header className="border-b border-neutral-800 bg-neutral-950/95 px-5 py-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="text-xs text-neutral-500">
                <span className="uppercase"> {React.string("Generated")} </span>
                <span className="ml-2 text-neutral-200">
                  {React.string(switch snapshot {
                  | Some(data) => data.generatedAt
                  | None => "-"
                  })}
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-3 text-xs text-neutral-500">
                <span>
                  {React.string("Live state: ")}
                  <code className="text-teal-200"> {React.string("/api/v1/state/live")} </code>
                </span>
                <HeroUI.Button
                  type_="button"
                  variant="bordered"
                  size="sm"
                  onClick={_ => onAudioToggle(!audioEnabled)}
                  className={
                    "rounded border px-3 py-1 text-xs font-medium " ++
                    if audioEnabled {
                      "border-teal-700 bg-teal-950/60 text-teal-100"
                    } else {
                      "border-neutral-700 bg-neutral-900 text-neutral-300"
                    }
                  }>
                  {React.string(if audioEnabled {
                    "Audio on"
                  } else {
                    "Audio off"
                  })}
                </HeroUI.Button>
              </div>
            </div>
          </header>
          <div className="px-5 py-6">
            <ReactRouter.Routes>
              <ReactRouter.Route path="/" element={<Dashboard snapshot error />} />
              <ReactRouter.Route
                path="/configuration"
                element={<Configuration audioEnabled onAudioToggle />}
              />
              <ReactRouter.Route path="*" element={<ReactRouter.Navigate to="/" replace=true />} />
            </ReactRouter.Routes>
          </div>
        </main>
      </div>
    </section>
  }
}

let renderDashboard = (root, ~snapshot, ~error, ~audioEnabled, ~onAudioToggle) =>
  root->render(
    <ReactRouter.HashRouter>
      <App snapshot error audioEnabled onAudioToggle />
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
  orderedQueue: orderedQueueEntries(state),
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
      goalUsage: goalUsageForIssue(state, issue.issue_id),
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
