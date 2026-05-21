let queue_parse_gaps = fun
| [] => []
| problems =>
  problems
  |> List.map((problem: Ordered_queue.parse_problem) => {
       Config.requirement:
         "orderedQueue."
         ++ (problem.value == "" ? "<empty>" : problem.value),
       remediation: problem.reason,
     });

let queue_validation_gaps = (config, queue) => {
  let tracker = Issue_tracker.make(config);
  Ordered_queue.validation_gaps(tracker, queue)
  |> List.map((gap: Ordered_queue.validation_gap) => {
       Config.requirement: gap.requirement,
       remediation: gap.remediation,
     });
};

let config_gap_of_runtime_gap = (gap: Runtime_state.readiness_gap) => {
  Config.requirement: gap.requirement,
  remediation: gap.remediation,
};

let selected_tracker_readiness_gaps = config =>
  try({
    let tracker = Issue_tracker.make(config);
    tracker.readiness_gaps()
    |> List.map(config_gap_of_runtime_gap);
  }) {
  | exn =>
    [
      {
        Config.requirement: "tracker.adapter",
        remediation:
          "Issue Tracker readiness failed: " ++ Printexc.to_string(exn),
      },
    ];
  };

let state = (~ordered_queue=?, ~queue_parse_problems=[], config) => {
  let local_gaps = Config.readiness_gaps(config);
  let queue_gaps = queue_parse_gaps(queue_parse_problems);
  let resumed_ordered_queue_state =
    Option.bind(ordered_queue, Orchestrator.resume_ordered_queue_state(config));
  let gaps =
    switch (local_gaps @ queue_gaps) {
    | [] =>
      let tracker_gaps = selected_tracker_readiness_gaps(config);
      switch ((tracker_gaps, ordered_queue)) {
      | ([], Some(_)) when Option.is_some(resumed_ordered_queue_state) => []
      | ([], Some(queue)) =>
        try(queue_validation_gaps(config, queue)) {
        | exn =>
          [
            {
              Config.requirement: "orderedQueue.validation",
              remediation:
                "Ordered Queue validation failed: "
                ++ Printexc.to_string(exn),
            },
          ];
        }
      | (gaps, _) => gaps
      };
    | gaps => gaps
    };
  let last_error =
    switch (gaps) {
    | [] => None
    | [gap, ..._] => Some(gap.requirement ++ ": " ++ gap.remediation)
    };
  let readiness_gaps =
    List.map(
      (gap: Config.readiness_gap) => {
        Runtime_state.requirement: gap.requirement,
        remediation: gap.remediation,
      },
      gaps,
    );
  let ordered_queue_state =
    switch (ordered_queue) {
    | None => None
    | Some(queue) =>
      Some(
        Option.value(
          resumed_ordered_queue_state,
          ~default=Orchestrator.ordered_queue_state(queue),
        ),
      )
    };
  Runtime_state.empty(
    ~last_error?,
    ~tracker_kind=config.tracker.kind,
    ~status_order=Config.project_status_order(config),
    ~ordered_queue=?ordered_queue_state,
    ~compozy_progress=?Runtime_state.initial_compozy_progress(config),
    ~compozy_progresses=Runtime_state.initial_compozy_progresses(config),
    ~readiness_gaps,
    (),
  );
};
