type action = Serve_readiness_state | Run_orchestrator

let action ~mode ~(readiness_gaps : Runtime_state.readiness_gap list) =
  match readiness_gaps with
  | _ :: _ -> Serve_readiness_state
  | [] -> (
      match mode with
      | Cli_mode.Terminal_console | Cli_mode.Web_dashboard -> Run_orchestrator)
