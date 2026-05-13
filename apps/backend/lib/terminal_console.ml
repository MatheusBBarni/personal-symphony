let optional_line label = function
  | Some value when Util.trim value <> "" -> Some (label, value)
  | _ -> None

let compozy_progress_lines (progress : Runtime_state.compozy_progress) =
  [
    Some ("Run", progress.run_id);
    Some ("Slug", progress.slug);
    optional_line "Lifecycle" progress.lifecycle_state;
    optional_line "Dispatch state" progress.dispatch_state;
    optional_line "Stage agent" progress.stage_agent;
    optional_line "PR readiness" progress.pr_readiness;
    optional_line "Handoff" progress.handoff_status;
    optional_line "Reason" progress.reason;
    Some ("Current step", Option.value progress.current_step ~default:"none");
    Some
      ( "Steps",
        Printf.sprintf "%d completed, %d failed, %d skipped, %d total" progress.completed progress.failed progress.skipped
          progress.total );
  ]
  |> List.filter_map Fun.id
