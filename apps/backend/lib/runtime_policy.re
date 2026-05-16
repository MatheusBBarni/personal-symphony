type action =
  | Serve_readiness_state
  | Run_orchestrator;

let action = (~mode, ~readiness_gaps: list(Runtime_state.readiness_gap)) =>
  switch (readiness_gaps) {
  | [_, ..._] => Serve_readiness_state
  | [] =>
    switch (mode) {
    | Cli_mode.Terminal_console | Cli_mode.Web_dashboard => Run_orchestrator
    }
  };
