type issueItem = {
  identifier: string,
  title: string,
  state: string,
  description: string,
}

type snapshot = {
  running: string,
  retrying: string,
  tokens: string,
  generatedAt: string,
  lastError: string,
  issues: array<issueItem>,
}

@send external arrayPush: (array<'a>, 'a) => int = "push"
@send external arrayIncludes: (array<string>, string) => bool = "includes"
@send external arrayFilter: (array<'a>, 'a => bool) => array<'a> = "filter"

@react.component
let make = (~snapshot: option<snapshot>, ~error: option<string>) => {
  let metric = (label, value, tone) =>
    <article className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
      <div className="text-sm text-zinc-400"> {React.string(label)} </div>
      <div className={"mt-2 text-3xl font-semibold " ++ tone}> {React.string(value)} </div>
    </article>

  let issueStateColumns = issues => {
    let states = []
    for i in 0 to Array.length(issues) - 1 {
      switch issues[i] {
      | Some(issue) =>
        if !arrayIncludes(states, issue.state) {
          ignore(arrayPush(states, issue.state))
        }
      | None => ()
      }
    }
    states
  }

  let content = switch (snapshot, error) {
  | (_, Some(message)) =>
    <div className="rounded-lg border border-red-900 bg-red-950 p-5 text-red-100">
      <div className="text-sm font-semibold uppercase tracking-wide text-red-300">
        {React.string("Backend unavailable")}
      </div>
      <p className="mt-2 text-sm"> {React.string(message)} </p>
    </div>
  | (Some(data), None) =>
    <>
      <div className="grid gap-4 sm:grid-cols-3">
        {metric("Running", data.running, "text-sky-200")}
        {metric("Retrying", data.retrying, "text-amber-200")}
        {metric("Total tokens", data.tokens, "text-emerald-200")}
      </div>
      {switch data.lastError {
      | "" => React.null
      | value =>
        <div className="mt-5 rounded-lg border border-amber-800 bg-amber-950 p-4 text-sm text-amber-100">
          {React.string(value)}
        </div>
      }}
      <section className="mb-6 mt-5 max-w-xl rounded-lg border border-zinc-800 bg-zinc-900 px-4 py-3">
        <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end">
          <div>
            <div className="text-xs uppercase text-zinc-500"> {React.string("Generated")} </div>
            <div className="mt-1 text-sm text-zinc-200"> {React.string(data.generatedAt)} </div>
          </div>
          <div className="text-sm text-zinc-400">
            {React.string("State API: ")}
            <code className="text-sky-200"> {React.string("/api/v1/state")} </code>
          </div>
        </div>
      </section>
      <section className="mt-6 rounded-lg border border-zinc-800 bg-zinc-900">
        <div className="flex items-center justify-between border-b border-zinc-800 px-4 py-3">
          <div className="text-sm font-medium text-zinc-200"> {React.string("Project board")} </div>
          <div className="text-xs text-zinc-500"> {React.string(Array.length(data.issues)->Int.toString ++ " tracked")} </div>
        </div>
        {switch Array.length(data.issues) {
        | 0 =>
          <div className="p-4 text-sm text-zinc-400">
            {React.string("No project issues were returned by the latest poll.")}
          </div>
        | _ =>
          <div className="overflow-x-auto p-4">
            <div className="grid min-w-[760px] auto-cols-[minmax(240px,1fr)] grid-flow-col gap-4">
              {data.issues
              ->issueStateColumns
              ->Array.map(state => {
                let stateIssues = arrayFilter(data.issues, issue => issue.state == state)
                <section className="min-h-48 rounded-lg border border-zinc-800 bg-zinc-950">
                  <div className="flex items-center justify-between border-b border-zinc-800 px-3 py-2.5">
                    <h2 className="text-sm font-semibold text-zinc-100"> {React.string(state)} </h2>
                    <span className="rounded-md border border-zinc-700 px-2 py-0.5 text-xs text-zinc-400">
                      {React.string(stateIssues->Array.length->Int.toString)}
                    </span>
                  </div>
                  <div className="space-y-3 p-3">
                    {stateIssues
                    ->Array.map(issue =>
                      <article className="rounded-md border border-zinc-800 bg-zinc-900 p-3">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="rounded-md border border-sky-800 bg-sky-950 px-2 py-0.5 text-xs font-medium text-sky-200">
                            {React.string(issue.identifier)}
                          </span>
                          <span className="text-xs text-zinc-500"> {React.string("read-only")} </span>
                        </div>
                        <h3 className="mt-2 text-sm font-semibold leading-5 text-zinc-100">
                          {React.string(issue.title)}
                        </h3>
                        <p className="mt-2 line-clamp-4 text-sm leading-6 text-zinc-400">
                          {React.string(issue.description)}
                        </p>
                      </article>
                    )
                    ->React.array}
                  </div>
                </section>
              })
              ->React.array}
            </div>
          </div>
        }}
      </section>
    </>
  | (None, None) =>
    <>
      <div className="grid gap-4 sm:grid-cols-3">
        {metric("Running", "-", "text-zinc-100")}
        {metric("Retrying", "-", "text-zinc-100")}
        {metric("Tokens", "-", "text-zinc-100")}
      </div>
      <div className="mt-6 rounded-lg border border-zinc-800 bg-zinc-900 p-6 text-zinc-300">
        {React.string("Loading runtime state...")}
      </div>
    </>
  }

  <section className="min-h-screen bg-zinc-950 text-zinc-100">
    <header className="border-b border-zinc-800 bg-zinc-950/95">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-4">
        <div>
          <h1 className="text-xl font-semibold tracking-normal"> {React.string("Personal Symphony")} </h1>
          <p className="text-sm text-zinc-400">
            {React.string("GitHub Issues + Projects orchestration")}
          </p>
        </div>
        <span className="rounded-md border border-emerald-700/60 bg-emerald-950 px-3 py-1 text-xs font-medium text-emerald-200">
          {React.string("OCaml API")}
        </span>
      </div>
    </header>
    <div className="mx-auto max-w-6xl px-5 py-6"> {content} </div>
  </section>
}
