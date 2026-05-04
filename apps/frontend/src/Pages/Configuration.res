@react.component
let make = (~audioEnabled: bool, ~onAudioToggle: bool => unit) =>
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
