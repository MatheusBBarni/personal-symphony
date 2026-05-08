%%raw(`import "@heroui/react/styles";`)
%%raw(`import "./styles.css";`)
%%raw(`import productPackage from "../../../package.json";`)
%%raw(`
const symphonyPackageVersion = productPackage.version;
`)

type domElement
type root

@val @scope("document") external getElementById: string => Nullable.t<domElement> = "getElementById"
@module("react-dom/client") external createRoot: domElement => root = "createRoot"
@send external render: (root, React.element) => unit = "render"

@val external symphonyPackageVersion: string = "symphonyPackageVersion"
external audioNotificationState: RuntimeStateSnapshot.runtimeState => AudioNotifications.runtimeState =
  "%identity"

let navItem = (href, label, isActive, icon) =>
  <a
    href=href
    className={
      "flex items-center gap-3 rounded px-3 py-2 text-sm font-medium transition-colors " ++
      if isActive {
        "bg-teal-950/80 text-teal-100"
      } else {
        "text-neutral-400 hover:bg-neutral-900 hover:text-neutral-100"
      }
    }>
    {icon}
    {React.string(label)}
  </a>

let headerRepositoryName = (snapshot: option<Dashboard.snapshot>) =>
  switch snapshot {
  | Some(data) => data.workspaceRepositoryName
  | None => ""
  }

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
            <div className="flex items-center gap-3">
              <img
                src="/symphony-icon.svg"
                alt=""
                className="size-10 shrink-0 rounded border border-teal-900/60 bg-teal-500/10"
              />
              <div className="min-w-0">
                <div className="text-lg font-semibold tracking-normal text-neutral-50">
                  {React.string("Symphony")}
                </div>
                <div className="mt-1 text-xs text-neutral-500">
                  {React.string("v" ++ symphonyPackageVersion)}
                </div>
              </div>
            </div>
          </div>
          <nav className="mt-5 grid grid-cols-2 gap-2 lg:grid-cols-1">
            {navItem(
              "#/",
              "Orchestrator",
              !isConfiguration,
              <Iconoir.KanbanBoard className="size-5 shrink-0" ariaHidden=true />,
            )}
            {navItem(
              "#/configuration",
              "Configuration",
              isConfiguration,
              <Iconoir.Settings className="size-5 shrink-0" ariaHidden=true />,
            )}
          </nav>
        </aside>
        <main className="min-w-0">
          <header className="border-b border-neutral-800 bg-neutral-950/95 px-5 py-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-3 text-xs text-neutral-500">
                {switch headerRepositoryName(snapshot) {
                | "" => React.null
                | name => <span className="font-medium text-neutral-200"> {React.string(name)} </span>
                }}
                <span>
                  <span className="uppercase"> {React.string("Generated")} </span>
                  <span className="ml-2 text-neutral-200">
                    {React.string(switch snapshot {
                    | Some(data) => data.generatedAt
                    | None => "-"
                    })}
                  </span>
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-3 text-xs text-neutral-500">
                <HeroUI.Chip
                  size="sm"
                  variant="flat"
                  className="rounded border border-emerald-800 bg-emerald-950/70 px-3 text-emerald-100">
                  {React.string("Live OCaml API")}
                </HeroUI.Chip>
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
      let snapshot = RuntimeStateSnapshot.snapshotFromState(state)
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
