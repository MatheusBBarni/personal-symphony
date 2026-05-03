type snapshot = {
  running: string,
  retrying: string,
  tokens: string,
  generatedAt: string,
  lastError: string,
}

@react.component
let make = (~snapshot: option<snapshot>, ~error: option<string>) => {
  let metric = (label, value, tone) =>
    <article className="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
      <div className="text-sm text-zinc-400"> {React.string(label)} </div>
      <div className={"mt-2 text-3xl font-semibold " ++ tone}> {React.string(value)} </div>
    </article>

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
      <section className="mt-6 rounded-lg border border-zinc-800 bg-zinc-900">
        <div className="border-b border-zinc-800 px-4 py-3 text-sm font-medium text-zinc-200">
          {React.string("Runtime Snapshot")}
        </div>
        <div className="grid gap-4 p-4 md:grid-cols-2">
          <div className="rounded-md bg-zinc-950 p-4">
            <div className="text-xs uppercase text-zinc-500"> {React.string("Generated")} </div>
            <div className="mt-1 text-sm text-zinc-200"> {React.string(data.generatedAt)} </div>
          </div>
          <div className="rounded-md bg-zinc-950 p-4">
            <div className="text-xs uppercase text-zinc-500"> {React.string("Tracker")} </div>
            <div className="mt-1 text-sm text-zinc-200">
              {React.string("GitHub Issues and GitHub Projects")}
            </div>
          </div>
        </div>
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
