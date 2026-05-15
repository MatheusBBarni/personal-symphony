let queue_parse_gaps = function
  | [] -> []
  | problems ->
      problems
      |> List.map (fun (problem : Ordered_queue.parse_problem) ->
             {
               Config.requirement = "orderedQueue." ^ (if problem.value = "" then "<empty>" else problem.value);
               remediation = problem.reason;
             })

let queue_validation_gaps config queue =
  let tracker = Issue_tracker.make config in
  Ordered_queue.validation_gaps tracker queue
  |> List.map (fun (gap : Ordered_queue.validation_gap) ->
         { Config.requirement = gap.requirement; remediation = gap.remediation })

let config_gap_of_runtime_gap (gap : Runtime_state.readiness_gap) =
  { Config.requirement = gap.requirement; remediation = gap.remediation }

let selected_tracker_readiness_gaps config =
  try
    let tracker = Issue_tracker.make config in
    tracker.readiness_gaps () |> List.map config_gap_of_runtime_gap
  with exn ->
    [
      {
        Config.requirement = "tracker.adapter";
        remediation = "Issue Tracker readiness failed: " ^ Printexc.to_string exn;
      };
    ]

let state ?ordered_queue ?(queue_parse_problems = []) config =
  let local_gaps = Config.readiness_gaps config in
  let queue_gaps = queue_parse_gaps queue_parse_problems in
  let resumed_ordered_queue_state = Option.bind ordered_queue (Orchestrator.resume_ordered_queue_state config) in
  let gaps =
    match local_gaps @ queue_gaps with
    | [] -> (
        let tracker_gaps = selected_tracker_readiness_gaps config in
        match (tracker_gaps, ordered_queue) with
        | [], Some _ when Option.is_some resumed_ordered_queue_state -> []
        | [], Some queue -> (
            try queue_validation_gaps config queue
            with exn ->
              [
                {
                  Config.requirement = "orderedQueue.validation";
                  remediation = "Ordered Queue validation failed: " ^ Printexc.to_string exn;
                };
              ])
        | gaps, _ -> gaps)
    | gaps -> gaps
  in
  let last_error =
    match gaps with
    | [] -> None
    | gap :: _ -> Some (gap.requirement ^ ": " ^ gap.remediation)
  in
  let readiness_gaps =
    List.map
      (fun (gap : Config.readiness_gap) ->
        { Runtime_state.requirement = gap.requirement; remediation = gap.remediation })
      gaps
  in
  let ordered_queue_state =
    match ordered_queue with
    | None -> None
    | Some queue -> Some (Option.value resumed_ordered_queue_state ~default:(Orchestrator.ordered_queue_state queue))
  in
  Runtime_state.empty ?last_error ~tracker_kind:config.tracker.kind ~status_order:(Config.project_status_order config)
    ?ordered_queue:ordered_queue_state
    ?compozy_progress:(Runtime_state.initial_compozy_progress config)
    ~readiness_gaps ()
