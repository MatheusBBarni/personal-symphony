type selector = {
  raw: string,
  identifier: string,
};

type integration =
  | Merged
  | Already_integrated;

type outcome = {
  issue: Issue.t,
  branch: string,
  workspace: Workspace.t,
  integration,
  status_update: option(string),
  cleanup_error: option(string),
};

type report = {
  outcomes: list(outcome),
  merged: int,
  already_integrated: int,
  cleanup_failures: int,
};

let split_comma = text =>
  text
  |> String.split_on_char(',')
  |> List.map(Util.trim)
  |> List.filter(part => part != "");

let digits_only = text =>
  text != ""
  && String.for_all(
       fun
       | '0' .. '9' => true
       | _ => false,
       text,
     );

let normalize_numeric_selector = (raw, trimmed) => {
  let body =
    if (String.length(trimmed) > 0 && trimmed.[0] == '#') {
      String.sub(trimmed, 1, String.length(trimmed) - 1);
    } else {
      trimmed;
    };

  if (digits_only(body)) {
    switch (int_of_string_opt(body)) {
    | Some(number) when number > 0 =>
      Ok({
        raw: trimmed,
        identifier: "#" ++ string_of_int(number),
      })
    | _ =>
      Error(Printf.sprintf("invalid Manual Task Merge selector %S", raw))
    };
  } else {
    Error(
      Printf.sprintf(
        "invalid Manual Task Merge selector %S; expected an issue identifier like 20, #20, or mb-20",
        raw,
      ),
    );
  };
};

let normalize_minibeads_selector = (raw, trimmed) =>
  switch (Util.drop_prefix(~prefix="mb-", trimmed)) {
  | Some(number_text) when digits_only(number_text) =>
    switch (int_of_string_opt(number_text)) {
    | Some(number) when number > 0 =>
      Ok({
        raw: trimmed,
        identifier: "mb-" ++ string_of_int(number),
      })
    | _ =>
      Error(Printf.sprintf("invalid Manual Task Merge selector %S", raw))
    }
  | _ =>
    Error(
      Printf.sprintf(
        "invalid Manual Task Merge selector %S; expected a minibeads issue identifier like mb-20",
        raw,
      ),
    )
  };

let normalize_compozy_selector = (raw, trimmed) =>
  switch (Util.drop_prefix(~prefix="compozy:", trimmed)) {
  | Some(task_name) =>
    let task_name = Util.trim(task_name);
    if (task_name == "") {
      Error(
        Printf.sprintf(
          "invalid Manual Task Merge selector %S; expected a Compozy PRD-run identifier like compozy:example-feature",
          raw,
        ),
      );
    } else if (String.contains(task_name, '/')
               || String.contains(task_name, ':')) {
      Error(
        Printf.sprintf(
          "invalid Manual Task Merge selector %S; expected a Compozy PRD-run identifier like compozy:example-feature without path separators",
          raw,
        ),
      );
    } else {
      Ok({
        raw: trimmed,
        identifier: "compozy:" ++ task_name,
      });
    };
  | None =>
    Error(
      Printf.sprintf(
        "invalid Manual Task Merge selector %S; expected a Compozy PRD-run identifier like compozy:example-feature",
        raw,
      ),
    )
  };

let normalize_one = raw => {
  let trimmed = Util.trim(raw);
  if (trimmed == "") {
    Error(Printf.sprintf("invalid Manual Task Merge selector %S", raw));
  } else if (Util.starts_with(~prefix="compozy:", trimmed)) {
    normalize_compozy_selector(raw, trimmed);
  } else if (String.contains(trimmed, '/') || String.contains(trimmed, ':')) {
    Error(
      Printf.sprintf(
        "invalid Manual Task Merge selector %S; issue URLs and cross-repository references are not supported",
        raw,
      ),
    );
  } else {
    switch (Util.drop_prefix(~prefix="mb-", trimmed)) {
    | Some(_) => normalize_minibeads_selector(raw, trimmed)
    | None => normalize_numeric_selector(raw, trimmed)
    };
  };
};

let normalize_selectors = args => {
  let raw_selectors = List.concat_map(split_comma, args);
  if (raw_selectors == []) {
    Error(["Manual Task Merge requires at least one issue identifier"]);
  } else {
    let seen = Hashtbl.create(8);
    let rec loop = (acc, errors) =>
      fun
      | [] =>
        if (errors == []) {
          Ok(List.rev(acc));
        } else {
          Error(List.rev(errors));
        }
      | [raw, ...rest] =>
        switch (normalize_one(raw)) {
        | Error(error) => loop(acc, [error, ...errors], rest)
        | Ok(selector) =>
          if (Hashtbl.mem(seen, selector.identifier)) {
            loop(
              acc,
              [
                Printf.sprintf(
                  "duplicate Manual Task Merge selector %s",
                  selector.identifier,
                ),
                ...errors,
              ],
              rest,
            );
          } else {
            Hashtbl.add(seen, selector.identifier, ());
            loop([selector, ...acc], errors, rest);
          }
        };

    loop([], [], raw_selectors);
  };
};

let command_ok = (~cwd, command) =>
  switch (Orchestrator.run_shell_capture(~cwd, command)) {
  | Ok(_) => true
  | Error(_) => false
  };

let rev_parse = (~cwd, refname) =>
  Orchestrator.run_shell_capture(
    ~cwd,
    Printf.sprintf("git rev-parse %s", Util.shell_quote(refname)),
  )
  |> Result.map(Util.trim);

let is_ancestor = (~cwd, ~ancestor, ~descendant) =>
  command_ok(
    ~cwd,
    Printf.sprintf(
      "git merge-base --is-ancestor %s %s",
      Util.shell_quote(ancestor),
      Util.shell_quote(descendant),
    ),
  );

let cleanup = (config, issue, workspace) => {
  let errors = ref([]);
  if (config.Config.git.cleanup.remove_worktree_after_merge) {
    switch (
      Orchestrator.run_shell_capture(
        ~cwd=config.Config.repository_root,
        Printf.sprintf(
          "git worktree remove %s",
          Util.shell_quote(workspace.Workspace.path),
        ),
      )
    ) {
    | Ok(_) => ()
    | Error(error) =>
      errors := ["worktree cleanup failed: " ++ error, ...errors^]
    };
  };
  if (!config.Config.git.cleanup.keep_task_branch) {
    switch (
      Orchestrator.run_shell_capture(
        ~cwd=config.Config.repository_root,
        Printf.sprintf(
          "git branch -d %s",
          Util.shell_quote(Orchestrator.task_branch(config, issue)),
        ),
      )
    ) {
    | Ok(_) => ()
    | Error(error) =>
      errors := ["task branch cleanup failed: " ++ error, ...errors^]
    };
  };
  switch (List.rev(errors^)) {
  | [] => None
  | errors => Some(String.concat("; ", errors))
  };
};

let review_success_status = (config, issue) =>
  switch (Orchestrator.stage_for_issue(config, issue)) {
  | Some(stage) => stage.Config.success_status
  | None => None
  };

type preflight = {
  selector,
  issue: Issue.t,
  branch: string,
  workspace: Workspace.t,
  already_integrated: bool,
};

let lookup_error = (result: Issue_tracker.lookup_result) =>
  if (List.mem(Issue_tracker.Missing_issue, result.diagnostics)
      || Option.is_none(result.issue)) {
    Some(
      Printf.sprintf(
        "%s is missing from the Workspace Repository issue tracker",
        result.identifier,
      ),
    );
  } else {
    result.diagnostics
    |> List.find_map(
         fun
         | Issue_tracker.Missing_project_membership(project_number) =>
           Some(
             Printf.sprintf(
               "%s is absent from GitHub Project #%d",
               result.identifier,
               project_number,
             ),
           )
         | Issue_tracker.Missing_issue
         | Issue_tracker.Closed_issue => None,
       );
  };

let preflight_one =
    (
      config,
      tracker: Issue_tracker.t,
      ~projected_tip,
      result: Issue_tracker.lookup_result,
      selector,
    ) =>
  switch (lookup_error(result)) {
  | Some(error) => Error(error)
  | None =>
    switch (result.issue) {
    | None =>
      Error(
        Printf.sprintf(
          "%s is missing from the Workspace Repository issue tracker",
          selector.identifier,
        ),
      )
    | Some(issue) =>
      let branch = Orchestrator.task_branch(config, issue);
      let workspace =
        Workspace.create_for_issue(
          ~root=config.Config.workspace.root,
          issue.Issue.identifier,
        );
      let terminal = tracker.is_terminal(issue.Issue.state);
      if (!Orchestrator.git_ref_exists(config.repository_root, branch)) {
        Error(
          Printf.sprintf(
            "%s expected Task Branch %s does not exist",
            selector.identifier,
            branch,
          ),
        );
      } else {
        switch (Orchestrator.worktree_branch(workspace.path)) {
        | None =>
          Error(
            Printf.sprintf(
              "%s expected Agent Worktree at %s",
              selector.identifier,
              workspace.path,
            ),
          )
        | Some(existing) when existing != branch =>
          Error(
            Printf.sprintf(
              "%s Agent Worktree uses %s but expected %s",
              selector.identifier,
              existing,
              branch,
            ),
          )
        | Some(_) =>
          switch (Orchestrator.has_worktree_changes(workspace.path)) {
          | Error(error) =>
            Error(
              Printf.sprintf(
                "%s Agent Worktree status failed at %s: %s",
                selector.identifier,
                workspace.path,
                error,
              ),
            )
          | Ok(true) =>
            Error(
              Printf.sprintf(
                "%s Agent Worktree must be clean: %s",
                selector.identifier,
                workspace.path,
              ),
            )
          | Ok(false) =>
            let already_integrated =
              is_ancestor(
                ~cwd=config.repository_root,
                ~ancestor=branch,
                ~descendant=projected_tip,
              );

            if (already_integrated) {
              Ok((
                {
                  selector,
                  issue,
                  branch,
                  workspace,
                  already_integrated,
                },
                projected_tip,
              ));
            } else {
              switch (
                Orchestrator.unauthorized_protected_task_branch_changes(
                  config,
                  issue,
                  ~base_ref=projected_tip,
                  ~head_ref=branch,
                )
              ) {
              | Error(error) =>
                Error(Printf.sprintf("%s %s", selector.identifier, error))
              | Ok () =>
                let allow_terminal_merge =
                  tracker.kind == "compozy_tasks"
                  && String.lowercase_ascii(issue.Issue.state) == "completed";

                if (terminal && !allow_terminal_merge) {
                  Error(
                    Printf.sprintf(
                      "%s is terminal in tracker state %S but %s is not on the Loop-Start Branch",
                      selector.identifier,
                      issue.state,
                      branch,
                    ),
                  );
                } else if (is_ancestor(
                             ~cwd=config.repository_root,
                             ~ancestor=projected_tip,
                             ~descendant=branch,
                           )) {
                  switch (rev_parse(~cwd=config.repository_root, branch)) {
                  | Ok(next_tip) =>
                    Ok((
                      {
                        selector,
                        issue,
                        branch,
                        workspace,
                        already_integrated,
                      },
                      next_tip,
                    ))
                  | Error(error) =>
                    Error(
                      Printf.sprintf(
                        "%s Task Branch tip could not be resolved: %s",
                        selector.identifier,
                        error,
                      ),
                    )
                  };
                } else {
                  Error(
                    Printf.sprintf(
                      "%s Task Branch %s cannot fast-forward from projected Loop-Start Branch tip",
                      selector.identifier,
                      branch,
                    ),
                  );
                };
              };
            };
          }
        };
      };
    }
  };

let preflight = (config, tracker: Issue_tracker.t, selectors) =>
  if (!Orchestrator.is_git_repository(config.Config.repository_root)) {
    Error(["Manual Task Merge requires a Git Workspace Repository"]);
  } else {
    switch (Orchestrator.has_worktree_changes(config.repository_root)) {
    | Error(error) =>
      Error([
        "Loop-Start Worktree status failed at "
        ++ config.repository_root
        ++ ": "
        ++ error,
      ])
    | Ok(true) =>
      Error(["Loop-Start Worktree must be clean: " ++ config.repository_root])
    | Ok(false) =>
      switch (
        tracker.fetch_by_identifiers_detailed(
          List.map(selector => selector.identifier, selectors),
        )
      ) {
      | Error(error) =>
        Error(["Manual Task Merge tracker lookup failed: " ++ error])
      | Ok(results) =>
        if (List.length(results) != List.length(selectors)) {
          Error([
            "Manual Task Merge tracker lookup returned an unexpected result count",
          ]);
        } else {
          switch (rev_parse(~cwd=config.repository_root, "HEAD")) {
          | Error(error) =>
            Error(["Loop-Start Branch tip could not be resolved: " ++ error])
          | Ok(head) =>
            let rec loop = (projected, acc, errors, pairs) =>
              switch (pairs) {
              | [] =>
                if (errors == []) {
                  Ok(List.rev(acc));
                } else {
                  Error(List.rev(errors));
                }
              | [(selector, result), ...rest] =>
                switch (
                  preflight_one(
                    config,
                    tracker,
                    ~projected_tip=projected,
                    result,
                    selector,
                  )
                ) {
                | Ok((item, next_tip)) =>
                  loop(next_tip, [item, ...acc], errors, rest)
                | Error(error) =>
                  loop(projected, acc, [error, ...errors], rest)
                }
              };

            loop(head, [], [], List.combine(selectors, results));
          };
        }
      }
    };
  };

let integrate_one = (config, tracker: Issue_tracker.t, item) => {
  let integration =
    if (item.already_integrated) {
      Ok(Already_integrated);
    } else {
      switch (
        Orchestrator.run_shell_capture(
          ~cwd=config.Config.repository_root,
          Printf.sprintf(
            "git merge --ff-only %s",
            Util.shell_quote(item.branch),
          ),
        )
      ) {
      | Ok(_) => Ok(Merged)
      | Error(error) => Error(error)
      };
    };

  switch (integration) {
  | Error(error) =>
    Error(
      Printf.sprintf(
        "%s merge failed after preflight: %s",
        item.selector.identifier,
        error,
      ),
    )
  | Ok(integration) =>
    let status_update =
      switch (review_success_status(config, item.issue)) {
      | None => None
      | Some(status) =>
        switch (tracker.update_status(item.issue, status)) {
        | Ok () => Some(status)
        | Error(error) =>
          raise(
            Failure(
              Printf.sprintf(
                "%s tracker status update failed: %s",
                item.selector.identifier,
                error,
              ),
            ),
          )
        }
      };

    let cleanup_error = cleanup(config, item.issue, item.workspace);
    Ok({
      issue: item.issue,
      branch: item.branch,
      workspace: item.workspace,
      integration,
      status_update,
      cleanup_error,
    });
  };
};

let run = (~tracker: Issue_tracker.t, config, args) =>
  switch (normalize_selectors(args)) {
  | Error(errors) => Error(errors)
  | Ok(selectors) =>
    switch (preflight(config, tracker, selectors)) {
    | Error(errors) => Error(errors)
    | Ok(items) =>
      try({
        let outcomes =
          List.map(
            item =>
              switch (integrate_one(config, tracker, item)) {
              | Ok(outcome) => outcome
              | Error(error) => raise(Failure(error))
              },
            items,
          );

        let merged =
          List.fold_left(
            (count, outcome) =>
              switch (outcome.integration) {
              | Merged => count + 1
              | Already_integrated => count
              },
            0,
            outcomes,
          );

        let already_integrated = List.length(outcomes) - merged;
        let cleanup_failures =
          outcomes
          |> List.filter(outcome => Option.is_some(outcome.cleanup_error))
          |> List.length;

        Ok({
          outcomes,
          merged,
          already_integrated,
          cleanup_failures,
        });
      }) {
      | Failure(error) => Error([error])
      }
    }
  };
