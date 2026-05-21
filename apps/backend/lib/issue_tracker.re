type poll_error =
  | Rate_limited(string, int)
  | Failed(string);

type lookup_diagnostic =
  | Missing_issue
  | Missing_project_membership(int)
  | Closed_issue;

type lookup_result = {
  identifier: string,
  issue: option(Issue.t),
  diagnostics: list(lookup_diagnostic),
};

type admission_decision = {
  eligible: bool,
  reason: string,
};

type t = {
  kind: string,
  ready_status: string,
  fetch_candidates: unit => result(list(Issue.t), poll_error),
  fetch_by_identifiers:
    list(string) => result(list(option(Issue.t)), string),
  fetch_by_identifiers_detailed:
    list(string) => result(list(lookup_result), string),
  update_status: (Issue.t, string) => result(unit, string),
  readiness_gaps: unit => list(Runtime_state.readiness_gap),
  normalize_identifier: string => result(string, string),
  first_admission: Issue.t => admission_decision,
  is_active: string => bool,
  is_terminal: string => bool,
};

let digits_only = text =>
  text != ""
  && String.for_all(
       fun
       | '0' .. '9' => true
       | _ => false,
       text,
     );

let github_issue_number = identifier => {
  let trimmed = Util.trim(identifier);
  let body =
    switch (Util.drop_prefix(~prefix="#", trimmed)) {
    | Some(suffix) => suffix
    | None => trimmed
    };

  if (digits_only(body)) {
    switch (int_of_string_opt(body)) {
    | Some(number) when number > 0 => Ok(number)
    | _ =>
      Error(Printf.sprintf("invalid GitHub issue identifier %S", identifier))
    };
  } else {
    Error(
      Printf.sprintf(
        "invalid GitHub issue identifier %S; expected an issue identifier like 20 or #20",
        identifier,
      ),
    );
  };
};

let github_identifier = number => "#" ++ string_of_int(number);

let github_normalize_identifier = raw =>
  github_issue_number(raw) |> Result.map(github_identifier);

let github_issue_numbers = identifiers => {
  let rec loop = acc =>
    fun
    | [] => Ok(List.rev(acc))
    | [identifier, ...rest] =>
      switch (github_issue_number(identifier)) {
      | Error(_) as error => error
      | Ok(number) => loop([number, ...acc], rest)
      };

  loop([], identifiers);
};

let runtime_gap_of_config_gap = (gap: Config.readiness_gap) => {
  Runtime_state.requirement: gap.requirement,
  remediation: gap.remediation,
};

let active_state_first_admission =
    (~ready_status, ~is_active, ~is_terminal, issue: Issue.t) => {
  let status = Util.trim(issue.Issue.state);
  if (is_terminal(status)) {
    {
      eligible: false,
      reason:
        Printf.sprintf(
          "Tracker state %S is terminal; configured Symphony-ready Status is %S.",
          status,
          ready_status,
        ),
    };
  } else if (is_active(status)) {
    {
      eligible: true,
      reason:
        Printf.sprintf(
          "Tracker state %S is eligible under the adapter admission contract; configured Symphony-ready Status is %S.",
          status,
          ready_status,
        ),
    };
  } else {
    {
      eligible: false,
      reason:
        Printf.sprintf(
          "Tracker state %S is not active; configured Symphony-ready Status is %S.",
          status,
          ready_status,
        ),
    };
  };
};

let ready_status_first_admission =
    (~ready_status, ~is_terminal, issue: Issue.t) => {
  let status = Util.trim(issue.Issue.state);
  let ready_status = Util.trim(ready_status);
  if (is_terminal(status)) {
    {
      eligible: false,
      reason:
        Printf.sprintf(
          "Tracker state %S is terminal; configured Symphony-ready Status is %S.",
          status,
          ready_status,
        ),
    };
  } else if (status == ready_status) {
    {
      eligible: true,
      reason:
        Printf.sprintf(
          "Tracker state %S matches configured Symphony-ready Status.",
          status,
        ),
    };
  } else {
    {
      eligible: false,
      reason:
        Printf.sprintf(
          "Tracker state %S does not match configured Symphony-ready Status %S.",
          status,
          ready_status,
        ),
    };
  };
};

let configured_first_admission =
    (~ready_status, ~ready_status_explicit, ~is_active, ~is_terminal) =>
  if (ready_status_explicit) {
    ready_status_first_admission(~ready_status, ~is_terminal);
  } else {
    active_state_first_admission(~ready_status, ~is_active, ~is_terminal);
  };

let github_poll_result = f =>
  try(Ok(f())) {
  | Github_tracker.Tracker_rate_limited(message, retry_after_ms) =>
    Error(Rate_limited(message, retry_after_ms))
  | Github_tracker.Tracker_error(message) => Error(Failed(message))
  | exn => Error(Failed(Printexc.to_string(exn)))
  };

let github_lookup_result = (~config: Config.tracker, identifier) =>
  fun
  | None => {
      identifier,
      issue: None,
      diagnostics: [Missing_issue],
    }
  | Some({ Github_tracker.issue, project_status: None, closed }) => {
      let diagnostics = [
        Missing_project_membership(config.project_number),
        ...if (closed) {
             [Closed_issue];
           } else {
             [];
           },
      ];

      {
        identifier,
        issue: Some(issue),
        diagnostics,
      };
    }
  | Some({ Github_tracker.issue, project_status: Some(_), closed }) => {
      let diagnostics =
        if (closed) {
          [Closed_issue];
        } else {
          [];
        };
      {
        identifier,
        issue: Some(issue),
        diagnostics,
      };
    };

let github =
    (
      ~fetch_candidates=Github_tracker.fetch_candidate_issues,
      ~fetch_by_numbers=Github_tracker.fetch_project_issues_by_numbers,
      ~update_status=Github_tracker.update_issue_status,
      ~readiness_gaps=Github_tracker.remote_readiness_gaps,
      config: Config.t,
    ) => {
  let tracker = Github_tracker.make(config.tracker);
  let fetch_candidates = () =>
    github_poll_result(() => fetch_candidates(tracker));
  let fetch_by_identifiers_detailed = identifiers =>
    switch (github_issue_numbers(identifiers)) {
    | Error(_) as error => error
    | Ok(numbers) =>
      try({
        let rows = fetch_by_numbers(tracker, numbers);
        Ok(
          List.map2(
            (number, _raw_identifier) => {
              let canonical = github_identifier(number);
              let row = List.assoc_opt(number, rows) |> Option.join;
              github_lookup_result(~config=config.tracker, canonical, row);
            },
            numbers,
            identifiers,
          ),
        );
      }) {
      | Github_tracker.Tracker_error(message) => Error(message)
      | Github_tracker.Tracker_rate_limited(message, _) => Error(message)
      | exn => Error(Printexc.to_string(exn))
      }
    };

  let fetch_by_identifiers = identifiers =>
    fetch_by_identifiers_detailed(identifiers)
    |> Result.map(
         List.map(result =>
           switch (result.diagnostics) {
           | [] => result.issue
           | [Closed_issue] => result.issue
           | _ => None
           }
         ),
       );

  let is_active = status =>
    Github_tracker.status_is_active(
      ~active_states=config.tracker.active_states,
      status,
    );
  let is_terminal = status =>
    Github_tracker.status_is_terminal(~config=config.tracker, status);
  {
    kind: "github",
    ready_status: config.tracker.ready_status,
    fetch_candidates,
    fetch_by_identifiers,
    fetch_by_identifiers_detailed,
    update_status: (issue, status) => update_status(tracker, issue, status),
    readiness_gaps: () =>
      readiness_gaps(config) |> List.map(runtime_gap_of_config_gap),
    normalize_identifier: github_normalize_identifier,
    first_admission:
      configured_first_admission(
        ~ready_status=config.tracker.ready_status,
        ~ready_status_explicit=config.tracker.ready_status_explicit,
        ~is_active,
        ~is_terminal,
      ),
    is_active,
    is_terminal,
  };
};

let minibeads = (~runner=Minibeads_tracker.default_runner, config: Config.t) => {
  let normalize_one = raw => {
    let identifier = Util.trim(raw) |> String.lowercase_ascii;
    switch (Util.drop_prefix(~prefix="mb-", identifier)) {
    | Some(number) when digits_only(number) =>
      switch (int_of_string_opt(number)) {
      | Some(parsed) when parsed > 0 => Ok("mb-" ++ string_of_int(parsed))
      | _ =>
        Error(Printf.sprintf("invalid minibeads issue identifier %S", raw))
      }
    | _ =>
      Error(
        Printf.sprintf(
          "invalid minibeads issue identifier %S; expected an issue identifier like mb-20",
          raw,
        ),
      )
    };
  };

  let fetch_by_identifiers = identifiers => {
    let rec normalize = acc =>
      fun
      | [] => Ok(List.rev(acc))
      | [identifier, ...rest] =>
        switch (normalize_one(identifier)) {
        | Error(_) as error => error
        | Ok(identifier) => normalize([identifier, ...acc], rest)
        };

    switch (normalize([], identifiers)) {
    | Error(_) as error => error
    | Ok(identifiers) =>
      Minibeads_tracker.fetch_by_identifiers(~runner, config, identifiers)
    };
  };

  let fetch_by_identifiers_detailed = identifiers =>
    switch (fetch_by_identifiers(identifiers)) {
    | Error(_) as error => error
    | Ok(issues) =>
      Ok(
        List.map2(
          (raw, issue) => {
            let identifier =
              switch (issue) {
              | Some(issue) => issue.Issue.identifier
              | None =>
                switch (normalize_one(raw)) {
                | Ok(identifier) => identifier
                | Error(_) => raw
                }
              };

            {
              identifier,
              issue,
              diagnostics:
                if (Option.is_none(issue)) {
                  [Missing_issue];
                } else {
                  [];
                },
            };
          },
          identifiers,
          issues,
        ),
      )
    };

  let is_active = Minibeads_tracker.is_active_status(config.tracker);
  let is_terminal = Minibeads_tracker.is_terminal_status(config.tracker);
  {
    kind: "minibeads",
    ready_status: config.tracker.ready_status,
    fetch_candidates: () =>
      switch (Minibeads_tracker.fetch_candidates(~runner, config)) {
      | Ok(_) as ok => ok
      | Error(message) => Error(Failed(message))
      },
    fetch_by_identifiers,
    fetch_by_identifiers_detailed,
    update_status: Minibeads_tracker.update_status(~runner, config),
    readiness_gaps: () => Minibeads_tracker.readiness_gaps(~runner, config),
    normalize_identifier: raw => {
      let identifier = Util.trim(raw) |> String.lowercase_ascii;
      switch (Util.drop_prefix(~prefix="mb-", identifier)) {
      | Some(number) when digits_only(number) =>
        switch (int_of_string_opt(number)) {
        | Some(parsed) when parsed > 0 => Ok("mb-" ++ string_of_int(parsed))
        | _ =>
          Error(Printf.sprintf("invalid minibeads issue identifier %S", raw))
        }
      | _ =>
        Error(
          Printf.sprintf(
            "invalid minibeads issue identifier %S; expected an issue identifier like mb-20",
            raw,
          ),
        )
      };
    },
    first_admission:
      active_state_first_admission(
        ~ready_status=config.tracker.ready_status,
        ~is_active,
        ~is_terminal,
      ),
    is_active,
    is_terminal,
  };
};

let compozy_identifier = raw => {
  let identifier = Util.trim(raw);
  switch (Util.drop_prefix(~prefix="compozy:", identifier)) {
  | Some(slug) when Util.trim(slug) != "" && !String.contains(slug, '/') =>
    Ok("compozy:" ++ Util.trim(slug))
  | None
      when
        identifier != ""
        && !String.contains(identifier, '/')
        && !String.contains(identifier, ':') =>
    Ok("compozy:" ++ identifier)
  | _ =>
    Error(
      Printf.sprintf(
        "invalid Compozy PRD-run identifier %S; expected an identifier like task-name or compozy:task-name",
        raw,
      ),
    )
  };
};

let string_equal_ci = (left, right) =>
  String.lowercase_ascii(left) == String.lowercase_ascii(right);

let status_in = (values, status) =>
  List.exists(string_equal_ci(status), values);

let compozy_status_is_active = (config, status) =>
  status_in(["pending", "in_progress"], status)
  || status_in(config.Config.tracker.active_states, status);

let compozy_status_is_terminal = (config, status) =>
  status_in(["completed", "failed", "skipped"], status)
  || status_in(config.Config.tracker.terminal_states, status);

let compozy_status_selects_stage = (config, status) =>
  config.Config.stage_agents.enabled
  && List.exists(
       (stage: Config.stage_agent) =>
         List.exists(string_equal_ci(status), stage.states),
       config.stage_agents.stages,
     );

let compozy_run_is_candidate =
    (
      config,
      run: Compozy_tasks_tracker.prd_run,
      lifecycle: Compozy_lifecycle.t,
    ) =>
  Compozy_tasks_tracker.runnable_prd_run(run)
  || Compozy_tasks_tracker.completed_prd_run(run)
  && compozy_status_selects_stage(config, lifecycle.dispatch_state);

let compozy_not_runnable_reason =
    (
      config,
      run: Compozy_tasks_tracker.prd_run,
      lifecycle: Compozy_lifecycle.t,
    ) =>
  switch (Option.map(Util.trim, run.not_runnable_reason)) {
  | Some(reason) when reason != "" => reason
  | _
      when
        Compozy_tasks_tracker.completed_prd_run(run)
        && !compozy_status_selects_stage(config, lifecycle.dispatch_state) =>
    Printf.sprintf(
      "completed Compozy PRD Run dispatch state %S does not select a Stage Agent",
      lifecycle.dispatch_state,
    )
  | _ => "no runnable Compozy Task Step is available"
  };

let legacy_compozy_ready_summary_absent = error =>
  Util.starts_with(~prefix="missing _tasks.md", error)
  || Util.starts_with(
       ~prefix="missing run-level Symphony-ready Status",
       error,
     );

let compozy_issue_of_prd_run = (run, lifecycle: Compozy_lifecycle.t) => {
  let issue = Compozy_tasks_tracker.issue_of_prd_run(run);
  {
    ...issue,
    Issue.state: lifecycle.dispatch_state,
  };
};

let compozy_load_lifecycle = (config, run) => {
  let lifecycle =
    switch (Compozy_lifecycle.load_or_backfill_reconciled(config, run)) {
    | Ok(lifecycle) => Some(lifecycle)
    | Error(_) =>
      /* Lifecycle metadata is Runtime Home cache derived from Compozy Task Steps. If one
         JSON file is corrupt or partially written, repair that run from task files instead
         of failing every tracker poll. */
      switch (Compozy_lifecycle.backfill(config, run)) {
      | Ok(lifecycle) => Some(lifecycle)
      | Error(_) => None
      }
    };

  Option.map(lifecycle => (run, lifecycle), lifecycle);
};

let compozy_lookup_result = (runs, raw) => {
  let identifier =
    switch (compozy_identifier(raw)) {
    | Ok(identifier) => identifier
    | Error(_) => raw
    };
  switch (
    List.find_opt(
      ((run: Compozy_tasks_tracker.prd_run, _)) => run.id == identifier,
      runs,
    )
  ) {
  | Some((run, lifecycle)) => {
      identifier,
      issue: Some(compozy_issue_of_prd_run(run, lifecycle)),
      diagnostics: [],
    }
  | None => {
      identifier,
      issue: None,
      diagnostics: [Missing_issue],
    }
  };
};

let compozy = config => {
  let fetch_runs = () =>
    switch (
      Compozy_tasks_tracker.discover_prd_runs(
        ~compozy_root=config.Config.tracker.compozy_root,
      )
    ) {
    | Ok(runs) =>
      let rec load = acc => (
        fun
        | [] => Ok(List.rev(acc))
        | [run, ...rest] =>
          switch (compozy_load_lifecycle(config, run)) {
          | Some(run) => load([run, ...acc], rest)
          | None => load(acc, rest)
          }
      );

      load([], runs);
    | Error(message) => Error(message)
    };

  let fetch_candidates = () =>
    switch (fetch_runs()) {
    | Error(message) => Error(Failed(message))
    | Ok(runs) =>
      Ok(
        runs
        |> List.filter(((run, lifecycle)) =>
             compozy_run_is_candidate(config, run, lifecycle)
           )
        |> List.map(((run, lifecycle)) =>
             compozy_issue_of_prd_run(run, lifecycle)
           ),
      )
    };

  let fetch_by_identifiers_detailed = identifiers => {
    let rec normalize = acc =>
      fun
      | [] => Ok(List.rev(acc))
      | [identifier, ...rest] =>
        switch (compozy_identifier(identifier)) {
        | Error(_) as error => error
        | Ok(identifier) => normalize([identifier, ...acc], rest)
        };

    switch (normalize([], identifiers)) {
    | Error(_) as error => error
    | Ok(identifiers) =>
      switch (fetch_runs()) {
      | Error(_) as error => error
      | Ok(runs) => Ok(List.map(compozy_lookup_result(runs), identifiers))
      }
    };
  };

  let fetch_by_identifiers = identifiers =>
    fetch_by_identifiers_detailed(identifiers)
    |> Result.map(
         List.map(result =>
           switch (result.diagnostics) {
           | [] => result.issue
           | _ => None
           }
         ),
       );

  let update_status = (issue, status) => {
    let raw_identifier =
      switch (Util.trim(issue.Issue.identifier)) {
      | "" => issue.Issue.id
      | identifier => identifier
      };

    switch (compozy_identifier(raw_identifier)) {
    | Error(_) as error => error
    | Ok(identifier) =>
      switch (fetch_runs()) {
      | Error(_) as error => error
      | Ok(runs) =>
        switch (
          List.find_opt(
            ((run: Compozy_tasks_tracker.prd_run, _)) =>
              run.id == identifier,
            runs,
          )
        ) {
        | None =>
          Error(
            Printf.sprintf("Compozy PRD run not found for %s", identifier),
          )
        | Some((run, _)) =>
          Compozy_lifecycle.update_dispatch_state(
            config,
            run,
            ~dispatch_state=status,
          )
          |> Result.map(_ => ())
        }
      }
    };
  };

  let is_active = compozy_status_is_active(config);
  let is_terminal = compozy_status_is_terminal(config);
  let runnable_admission = (~identifier, ~ready_detail, run, lifecycle) =>
    if (!compozy_run_is_candidate(config, run, lifecycle)) {
      {
        eligible: false,
        reason:
          Printf.sprintf(
            "%s, but %s is not runnable: %s.",
            ready_detail,
            identifier,
            compozy_not_runnable_reason(config, run, lifecycle),
          ),
      };
    } else if (is_terminal(lifecycle.dispatch_state)) {
      {
        eligible: false,
        reason:
          Printf.sprintf(
            "%s, but lifecycle dispatch state %S is terminal for %s.",
            ready_detail,
            lifecycle.dispatch_state,
            identifier,
          ),
      };
    } else if (!is_active(lifecycle.dispatch_state)) {
      {
        eligible: false,
        reason:
          Printf.sprintf(
            "%s, but lifecycle dispatch state %S is not dispatchable for %s.",
            ready_detail,
            lifecycle.dispatch_state,
            identifier,
          ),
      };
    } else {
      {
        eligible: true,
        reason:
          Printf.sprintf(
            "%s and %s satisfies existing runnable-run conditions.",
            ready_detail,
            identifier,
          ),
      };
    };

  let first_admission = issue => {
    let raw_identifier =
      switch (Util.trim(issue.Issue.identifier)) {
      | "" => issue.Issue.id
      | identifier => identifier
      };

    switch (compozy_identifier(raw_identifier)) {
    | Error(error) => {
        eligible: false,
        reason: error,
      }
    | Ok(identifier) =>
      switch (fetch_runs()) {
      | Error(error) => {
          eligible: false,
          reason:
            Printf.sprintf(
              "Could not load Compozy PRD Runs for %s: %s",
              identifier,
              error,
            ),
        }
      | Ok(runs) =>
        switch (
          List.find_opt(
            ((run: Compozy_tasks_tracker.prd_run, _)) =>
              run.id == identifier,
            runs,
          )
        ) {
        | None => {
            eligible: false,
            reason:
              Printf.sprintf("Compozy PRD Run %s was not found.", identifier),
          }
        | Some((run, lifecycle)) =>
          switch (
            Compozy_tasks_tracker.ready_summary_of_prd_run(
              ~compozy_root=config.Config.tracker.compozy_root,
              run,
            )
          ) {
          | Error(error) =>
            if (legacy_compozy_ready_summary_absent(error)) {
              runnable_admission(
                ~identifier,
                ~ready_detail=
                  Printf.sprintf(
                    "Compozy _tasks.md has no run-level Symphony-ready Status for %s; preserving legacy task-step admission",
                    identifier,
                  ),
                run,
                lifecycle,
              );
            } else {
              {
                eligible: false,
                reason:
                  Printf.sprintf(
                    "Compozy _tasks.md readiness parse failed for %s: %s",
                    identifier,
                    error,
                  ),
              };
            }
          | Ok(summary) =>
            let observed_ready_status =
              Util.trim(summary.Compozy_tasks_tracker.ready_status);
            let configured_ready_status =
              Util.trim(config.Config.tracker.ready_status);
            if (observed_ready_status != configured_ready_status) {
              {
                eligible: false,
                reason:
                  Printf.sprintf(
                    "Compozy _tasks.md status %S does not match configured Symphony-ready Status %S for %s.",
                    observed_ready_status,
                    configured_ready_status,
                    identifier,
                  ),
              };
            } else {
              runnable_admission(
                ~identifier,
                ~ready_detail=
                  Printf.sprintf(
                    "Compozy _tasks.md status %S matches configured Symphony-ready Status",
                    observed_ready_status,
                  ),
                run,
                lifecycle,
              );
            };
          }
        }
      }
    };
  };

  {
    kind: "compozy_tasks",
    ready_status: config.Config.tracker.ready_status,
    fetch_candidates,
    fetch_by_identifiers,
    fetch_by_identifiers_detailed,
    update_status,
    readiness_gaps: () =>
      Compozy_tasks_tracker.readiness_gaps(config)
      |> List.map((gap: Compozy_tasks_tracker.readiness_gap) =>
           {
             Runtime_state.requirement: gap.requirement,
             remediation: gap.remediation,
           }
         ),
    normalize_identifier: compozy_identifier,
    first_admission,
    is_active,
    is_terminal,
  };
};

let make = (config: Config.t) =>
  switch (config.tracker.kind) {
  | "github" => github(config)
  | "minibeads" => minibeads(config)
  | "compozy_tasks" => compozy(config)
  | kind =>
    invalid_arg(
      Printf.sprintf(
        "Issue tracker adapter is not implemented for tracker.kind=%S",
        kind,
      ),
    )
  };
