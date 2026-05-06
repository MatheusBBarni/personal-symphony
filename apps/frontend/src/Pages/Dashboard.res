type issueItem = {
  identifier: string,
  title: string,
  state: string,
  url: string,
  description: string,
  error: string,
  goalUsage: string,
}

type queueEntry = {
  identifier: string,
  title: string,
  state: string,
  skipReason: string,
}

type snapshot = {
  running: string,
  retrying: string,
  tokens: string,
  generatedAt: string,
  readinessGaps: string,
  startupReconciliation: string,
  lastError: string,
  statusOrder: array<string>,
  issues: array<issueItem>,
  orderedQueue: array<queueEntry>,
}

@send external arrayPush: (array<'a>, 'a) => int = "push"
@send external arrayFilter: (array<'a>, 'a => bool) => array<'a> = "filter"
@send external toLowerCase: string => string = "toLowerCase"
@send external trim: string => string = "trim"
external nullableString: string => Nullable.t<string> = "%identity"

let sameState = (left, right) => left->toLowerCase == right->toLowerCase
let backlogState = "Backlog"

let normalizedRuntimeValue = value => {
  switch value->nullableString->Nullable.toOption {
  | None => None
  | Some(value) =>
    let normalized = value->trim
    switch normalized->toLowerCase {
    | "" | "null" | "undefined" => None
    | _ => Some(normalized)
    }
  }
}

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

let issueStateColumns = (issues: array<issueItem>) => {
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

let orderedIssueStateColumns = (statusOrder: array<string>, issues: array<issueItem>) => {
  let states = []
  let hasBacklog =
    arrayIncludesState(statusOrder, backlogState) ||
    arrayIncludesState(issues->issueStateColumns, backlogState)
  if hasBacklog {
    ignore(arrayPush(states, backlogState))
  }
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

let metricPanel = (label, value, tone, detail, icon) =>
  <HeroUI.Card className="rounded border border-neutral-800 bg-[#1b1b1b]">
    <HeroUI.CardContent className="p-4">
      <div className="flex items-start justify-between gap-4">
        <div className="text-[11px] font-medium uppercase tracking-normal text-neutral-500">
          {React.string(label)}
        </div>
        {icon}
      </div>
      <div className="mt-5 flex items-end gap-3">
        <div className={"text-3xl font-semibold leading-none " ++ tone}> {React.string(value)} </div>
        <div className="pb-1 text-xs text-neutral-500"> {React.string(detail)} </div>
      </div>
      <div className="mt-4 h-px bg-neutral-900" />
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

let renderBanner = (tone, label, message) =>
  switch normalizedRuntimeValue(message) {
  | None => React.null
  | Some(message) => banner(tone, label, message)
  }

let issueStateTone = state =>
  switch state->toLowerCase {
  | "backlog" => "border-sky-800 bg-sky-950/70 text-sky-200"
  | "todo" => "border-violet-800 bg-violet-950/70 text-violet-200"
  | "in progress" => "border-teal-800 bg-teal-950/70 text-teal-200"
  | "in review" => "border-amber-800 bg-amber-950/70 text-amber-200"
  | "done" | "completed" => "border-emerald-800 bg-emerald-950/70 text-emerald-200"
  | "blocked" | "human attention" => "border-red-900 bg-red-950/70 text-red-200"
  | _ => "border-neutral-700 bg-neutral-900 text-neutral-300"
  }

let issueCard = (issue: issueItem) =>
  <article
    key=issue.identifier
    className="m-3 rounded border border-neutral-800 bg-[#1d1d1d] px-4 py-4 shadow-sm">
    <div className="flex items-center justify-between gap-3">
      <HeroUI.Chip
        size="sm"
        variant="flat"
        className="h-6 rounded border border-neutral-700 bg-neutral-800 px-2 font-mono text-[11px] text-neutral-400">
        {React.string(issue.identifier)}
      </HeroUI.Chip>
      <span
        className={"max-w-[8rem] truncate rounded border px-2 py-0.5 text-[11px] font-semibold uppercase tracking-normal " ++
        issueStateTone(issue.state)}>
        {React.string(issue.state)}
      </span>
    </div>
    <h3 className="mt-5 text-base font-semibold leading-6 text-neutral-100">
      {switch issue.url {
      | "" => React.string(issue.title)
      | url =>
        <a className="transition-colors hover:text-teal-200" href=url target="_blank" rel="noreferrer">
          {React.string(issue.title)}
        </a>
      }}
    </h3>
    <p className="mt-5 line-clamp-3 text-sm leading-6 text-neutral-500">
      {React.string(issue.description)}
    </p>
    {switch issue.error {
    | "" => React.null
    | message =>
      <div className="mt-3 rounded border border-red-900 bg-red-950/70 px-3 py-2 text-xs leading-5 text-red-100">
        {React.string(message)}
      </div>
    }}
    {switch issue.goalUsage {
    | "" => React.null
    | value =>
      <div className="mt-3 rounded border border-neutral-800 bg-neutral-900 px-3 py-2 text-xs leading-5 text-neutral-300">
        <span className="font-medium text-neutral-100"> {React.string("Goal Usage")} </span>
        <span className="ml-2"> {React.string(value)} </span>
      </div>
    }}
  </article>

let queueStateTone = state =>
  switch state {
  | "completed" => "border-emerald-800 bg-emerald-950/70 text-emerald-100"
  | "running" => "border-teal-800 bg-teal-950/70 text-teal-100"
  | "retrying" => "border-amber-800 bg-amber-950/70 text-amber-100"
  | "skipped" => "border-red-900 bg-red-950/70 text-red-100"
  | _ => "border-neutral-700 bg-neutral-900 text-neutral-300"
  }

let queueEntryRow = (entry: queueEntry) =>
  <li key=entry.identifier className="flex items-start justify-between gap-3 border-b border-neutral-800 px-3 py-3 last:border-b-0">
    <div className="min-w-0">
      <div className="flex items-center gap-2">
        <span className="font-mono text-xs text-neutral-300"> {React.string(entry.identifier)} </span>
        <span className={"rounded border px-2 py-0.5 text-[11px] " ++ queueStateTone(entry.state)}>
          {React.string(entry.state)}
        </span>
      </div>
      <div className="mt-1 truncate text-sm text-neutral-100">
        {React.string(if entry.title == "" { "Pending issue details" } else { entry.title })}
      </div>
      {switch entry.skipReason {
      | "" => React.null
      | reason => <div className="mt-2 text-xs leading-5 text-red-200"> {React.string(reason)} </div>
      }}
    </div>
  </li>

let orderedQueuePanel = entries =>
  switch Array.length(entries) {
  | 0 => React.null
  | _ =>
    <HeroUI.AccordionRoot
      variant="bordered"
      hideSeparator=true
      className="rounded border border-neutral-800 bg-neutral-950 px-0">
      <HeroUI.AccordionItem id="ordered-queue" className="border-0">
        <HeroUI.AccordionHeading>
          <HeroUI.AccordionTrigger
            ariaLabel="Toggle ordered queue"
            className="w-full px-4 py-3 text-left text-neutral-100">
            <div className="grid w-full grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-center gap-3">
              <div />
              <div className="flex min-w-0 flex-col items-center justify-center gap-2">
                <div className="mb-1 text-center text-sm font-semibold text-neutral-100">
                  {React.string("Ordered Queue")}
                </div>
                <HeroUI.Chip
                  size="sm"
                  variant="flat"
                  className="rounded border border-neutral-700 bg-neutral-900 px-3 text-neutral-200">
                  {React.string(entries->Array.length->Int.toString ++ " entries")}
                </HeroUI.Chip>
              </div>
              <HeroUI.AccordionIndicator className="size-5 text-neutral-400 transition-transform data-[expanded=true]:rotate-180" />
            </div>
          </HeroUI.AccordionTrigger>
        </HeroUI.AccordionHeading>
        <HeroUI.AccordionPanel className="border-t border-neutral-800">
          <ol> {entries->Array.map(queueEntryRow)->React.array} </ol>
        </HeroUI.AccordionPanel>
      </HeroUI.AccordionItem>
    </HeroUI.AccordionRoot>
  }

let emptyOrchestrator = error =>
  <>
    {switch error {
    | Some(message) => banner("error", "Backend unavailable", message)
    | None => React.null
    }}
    <div className="grid gap-4 lg:grid-cols-3">
      {metricPanel(
        "Running",
        "-",
        "text-neutral-100",
        "No Runtime State snapshot yet",
        <Iconoir.Play className="size-5 text-teal-400" ariaHidden=true />,
      )}
      {metricPanel(
        "Retrying",
        "-",
        "text-neutral-100",
        "No Runtime State snapshot yet",
        <Iconoir.Refresh className="size-6 text-amber-400" ariaHidden=true />,
      )}
      {metricPanel(
        "Total tokens",
        "-",
        "text-neutral-100",
        "No Runtime State snapshot yet",
        <Iconoir.CoinsSwap className="size-6 text-emerald-400" ariaHidden=true />,
      )}
    </div>
    <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950">
      <HeroUI.CardContent className="p-6 text-sm text-neutral-400">
        {React.string("Loading runtime state...")}
      </HeroUI.CardContent>
    </HeroUI.Card>
  </>

@react.component
let make = (~snapshot: option<snapshot>, ~error: option<string>) =>
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
          {metricPanel(
            "Running",
            data.running,
            "text-neutral-100",
            "Active Agents",
            <Iconoir.Play className="size-5 text-teal-400" ariaHidden=true />,
          )}
          {metricPanel(
            "Retrying",
            data.retrying,
            "text-neutral-100",
            "Network Queue",
            <Iconoir.Refresh className="size-6 text-amber-400" ariaHidden=true />,
          )}
          {metricPanel(
            "Total tokens",
            data.tokens,
            "text-neutral-100",
            "Consumed (24h)",
            <Iconoir.CoinsSwap className="size-6 text-emerald-400" ariaHidden=true />,
          )}
        </div>
        {switch error {
        | Some(message) => banner("error", "Live Dashboard Connection", message)
        | None => React.null
        }}
        {renderBanner("warning", "Readiness Gaps", data.readinessGaps)}
        {renderBanner("warning", "Startup Reconciliation", data.startupReconciliation)}
        {renderBanner("error", "Runtime State Error", data.lastError)}
        {orderedQueuePanel(data.orderedQueue)}
        <HeroUI.Card className="rounded border border-neutral-800 bg-neutral-950">
          <HeroUI.CardHeader className="flex flex-col items-center justify-center border-b border-neutral-800 px-4 py-4 text-center">
            <div className="mb-2 text-sm font-semibold text-neutral-100">
              {React.string("Project board")}
            </div>
            <div className="mb-3 text-xs text-neutral-500">
              {React.string("Columns follow Runtime State status order and issue states.")}
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
