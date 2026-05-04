type issueItem = {
  identifier: string,
  title: string,
  state: string,
  url: string,
  description: string,
  error: string,
}

type snapshot = {
  running: string,
  retrying: string,
  tokens: string,
  generatedAt: string,
  readinessGaps: string,
  lastError: string,
  statusOrder: array<string>,
  issues: array<issueItem>,
}

@send external arrayPush: (array<'a>, 'a) => int = "push"
@send external arrayFilter: (array<'a>, 'a => bool) => array<'a> = "filter"
@send external toLowerCase: string => string = "toLowerCase"

let sameState = (left, right) => left->toLowerCase == right->toLowerCase

let arrayIncludesState = (states, state) => {
  let found = ref(false)
  for i in 0 to Array.length(states) - 1 {
    switch states[i] {
    | Some(existing) =>
      if sameState(existing, state) {
        found := true
      }
    | None => ()
    }
  }
  found.contents
}

let issueStateColumns = issues => {
  let states = []
  for i in 0 to Array.length(issues) - 1 {
    switch issues[i] {
    | Some(issue) =>
      if !arrayIncludesState(states, issue.state) {
        ignore(arrayPush(states, issue.state))
      }
    | None => ()
    }
  }
  states
}

let orderedIssueStateColumns = (statusOrder, issues) => {
  let states = []
  statusOrder->Array.forEach(state => {
    if !arrayIncludesState(states, state) {
      ignore(arrayPush(states, state))
    }
  })
  issues
  ->issueStateColumns
  ->Array.forEach(state => {
    if !arrayIncludesState(states, state) {
      ignore(arrayPush(states, state))
    }
  })
  states
}

let metricPanel = (label, value, tone, detail) =>
  <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950/80">
    <HeroUI.CardContent className="p-4">
      <div className="text-[11px] font-medium uppercase tracking-normal text-neutral-500">
        {React.string(label)}
      </div>
      <div className={"mt-3 text-3xl font-semibold " ++ tone}> {React.string(value)} </div>
      <div className="mt-2 text-xs text-neutral-500"> {React.string(detail)} </div>
    </HeroUI.CardContent>
  </HeroUI.Card>

let banner = (tone, label, message) => {
  let classes = switch tone {
  | "error" => "border-red-900 bg-red-950/70 text-red-100"
  | "warning" => "border-amber-800 bg-amber-950/70 text-amber-100"
  | _ => "border-neutral-800 bg-neutral-950 text-neutral-100"
  }
  <div className={"rounded border px-4 py-3 text-sm " ++ classes}>
    <div className="text-[11px] font-semibold uppercase tracking-normal opacity-70">
      {React.string(label)}
    </div>
    <div className="mt-1 leading-6"> {React.string(message)} </div>
  </div>
}

let issueCard = issue =>
  <article key=issue.identifier className="border-b border-neutral-800 px-3 py-3 last:border-b-0">
    <div className="flex items-center gap-2">
      <HeroUI.Chip
        size="sm"
        variant="flat"
        className="h-5 rounded border border-neutral-700 bg-neutral-900 px-2 font-mono text-[11px] text-neutral-300">
        {React.string(issue.identifier)}
      </HeroUI.Chip>
      <span className="text-[11px] uppercase tracking-normal text-neutral-600">
        {React.string(issue.state)}
      </span>
    </div>
    <h3 className="mt-2 text-sm font-semibold leading-5 text-neutral-100">
      {switch issue.url {
      | "" => React.string(issue.title)
      | url =>
        <a className="transition-colors hover:text-teal-200" href=url target="_blank" rel="noreferrer">
          {React.string(issue.title)}
        </a>
      }}
    </h3>
    <p className="mt-2 line-clamp-3 text-sm leading-6 text-neutral-400">
      {React.string(issue.description)}
    </p>
    {switch issue.error {
    | "" => React.null
    | message =>
      <div className="mt-3 rounded border border-red-900 bg-red-950/70 px-3 py-2 text-xs leading-5 text-red-100">
        {React.string(message)}
      </div>
    }}
  </article>

let emptyOrchestrator = error =>
  <>
    {switch error {
    | Some(message) => banner("error", "Backend unavailable", message)
    | None => React.null
    }}
    <div className="grid gap-4 lg:grid-cols-3">
      {metricPanel("Running", "-", "text-neutral-100", "No Runtime State snapshot yet")}
      {metricPanel("Retrying", "-", "text-neutral-100", "No Runtime State snapshot yet")}
      {metricPanel("Total tokens", "-", "text-neutral-100", "No Runtime State snapshot yet")}
    </div>
    <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950">
      <HeroUI.CardContent className="p-6 text-sm text-neutral-400">
        {React.string("Loading runtime state...")}
      </HeroUI.CardContent>
    </HeroUI.Card>
  </>

let orchestratorView = (snapshot, error) =>
  <div className="space-y-5">
    <div>
      <h1 className="text-2xl font-semibold tracking-normal text-neutral-50">
        {React.string("Web Dashboard Refactor")}
      </h1>
      <p className="mt-1 text-sm text-neutral-500">
        {React.string("Orchestrator view backed by the existing Runtime State snapshot.")}
      </p>
    </div>
    {switch snapshot {
    | None => emptyOrchestrator(error)
    | Some(data) =>
      <>
        <div className="grid gap-4 lg:grid-cols-3">
          {metricPanel("Running", data.running, "text-teal-200", "Active Task Branch work")}
          {metricPanel("Retrying", data.retrying, "text-amber-200", "Attention-needed retry loop")}
          {metricPanel("Total tokens", data.tokens, "text-emerald-200", "Accumulated Codex usage")}
        </div>
        {switch error {
        | Some(message) => banner("error", "Live Dashboard Connection", message)
        | None => React.null
        }}
        {switch data.readinessGaps {
        | "" => React.null
        | value => banner("warning", "Readiness Gaps", value)
        }}
        {switch data.lastError {
        | "" => React.null
        | value => banner("error", "Runtime State Error", value)
        }}
        <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950">
          <HeroUI.CardHeader className="flex items-center justify-between border-b border-neutral-800 px-4 py-3">
            <div>
              <div className="text-sm font-semibold text-neutral-100"> {React.string("Project board")} </div>
              <div className="mt-1 text-xs text-neutral-500">
                {React.string("Columns follow Runtime State status order and issue states.")}
              </div>
            </div>
            <HeroUI.Chip
              size="sm"
              variant="flat"
              className="rounded border border-teal-800 bg-teal-950/70 px-3 text-teal-100">
              {React.string(Array.length(data.issues)->Int.toString ++ " tracked")}
            </HeroUI.Chip>
          </HeroUI.CardHeader>
          {switch Array.length(data.issues) == 0 && Array.length(data.statusOrder) == 0 {
          | true =>
            <HeroUI.CardContent className="p-4 text-sm text-neutral-400">
              {React.string("No project issues were returned by the latest snapshot.")}
            </HeroUI.CardContent>
          | false =>
            <HeroUI.CardContent className="overflow-x-auto p-4">
              <div className="grid min-w-[860px] auto-cols-[minmax(260px,1fr)] grid-flow-col gap-4">
                {orderedIssueStateColumns(data.statusOrder, data.issues)
                ->Array.map(state => {
                  let stateIssues = arrayFilter(data.issues, issue => sameState(issue.state, state))
                  <section key=state className="min-h-64 rounded border border-neutral-800 bg-black">
                    <div className="flex items-center justify-between border-b border-neutral-800 px-3 py-2.5">
                      <h2 className="text-sm font-semibold text-neutral-100"> {React.string(state)} </h2>
                      <span className="rounded-full border border-neutral-700 px-2 py-0.5 text-xs text-neutral-400">
                        {React.string(stateIssues->Array.length->Int.toString)}
                      </span>
                    </div>
                    <div> {stateIssues->Array.map(issueCard)->React.array} </div>
                  </section>
                })
                ->React.array}
              </div>
            </HeroUI.CardContent>
          }}
        </HeroUI.Card>
      </>
    }}
  </div>

let configurationView = (~audioEnabled, ~onAudioToggle) =>
  <div className="space-y-5">
    <div>
      <h1 className="text-2xl font-semibold tracking-normal text-neutral-50">
        {React.string("Configuration")}
      </h1>
      <p className="mt-1 text-sm text-neutral-500">
        {React.string("Browser-local Audio Notification Configuration.")}
      </p>
    </div>
    <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950">
      <HeroUI.CardHeader className="border-b border-neutral-800 px-4 py-3">
        <div>
          <div className="text-sm font-semibold text-neutral-100">
            {React.string("Audio notifications")}
          </div>
          <div className="mt-1 text-xs text-neutral-500">
            {React.string("Stored in this browser only; Runtime Settings are unchanged.")}
          </div>
        </div>
      </HeroUI.CardHeader>
      <HeroUI.CardContent className="grid gap-4 p-4 md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
        <div>
          <div className="text-sm font-medium text-neutral-100">
            {React.string("Notify when tracked work changes")}
          </div>
          <p className="mt-1 max-w-2xl text-sm leading-6 text-neutral-500">
            {React.string("The dashboard can play a local browser sound when active work enters a notable state.")}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <HeroUI.Switch isSelected=audioEnabled onChange={enabled => onAudioToggle(enabled)}>
            {React.string(if audioEnabled {
              "Audio on"
            } else {
              "Audio off"
            })}
          </HeroUI.Switch>
        </div>
      </HeroUI.CardContent>
    </HeroUI.Card>
  </div>

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

@react.component
let make = (
  ~snapshot: option<snapshot>,
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
            <ReactRouter.Route path="/" element={orchestratorView(snapshot, error)} />
            <ReactRouter.Route
              path="/configuration"
              element={configurationView(~audioEnabled, ~onAudioToggle)}
            />
            <ReactRouter.Route path="*" element={<ReactRouter.Navigate to="/" replace=true />} />
          </ReactRouter.Routes>
        </div>
      </main>
    </div>
  </section>
}
