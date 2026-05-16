type entry = {issue_identifier: string};
type t = {entries: list(entry)};
type resolved_entry = {queue_identifier: string, canonical_identifier: string};
type parse_problem = {value: string, reason: string};
type resolution_problem = {queue_identifier: string, reason: string};
type validation_gap = {requirement: string, remediation: string};

let digits_only = text =>
  text !== ""
  && String.for_all(
       x =>
         switch (x) {
         | '0' .. '9' => true
         | _ => false
         },
       text,
     );

let normalize_compozy_entry = value =>
  switch (Util.drop_prefix(~prefix="compozy:", value)) {
  | Some(task_name) =>
    let task_name = Util.trim(task_name);
    if (task_name == "") {
      Error({
        value,
        reason: "expected a Compozy PRD-run identifier like compozy:example-feature",
      });
    } else if (String.contains(task_name, '/') || String.contains(task_name, ':')) {
      Error({
        value,
        reason:
          "expected a Compozy PRD-run identifier like compozy:example-feature without path separators",
      });
    } else {
      Ok({issue_identifier: "compozy:" ++ task_name});
    };
  | None =>
    Error({
      value,
      reason: "expected a Compozy PRD-run identifier like compozy:example-feature",
    });
  };

let normalize_entry = raw => {
  let value = Util.trim(raw);
  if (value == "") {
    Error({value, reason: "empty queue entry"});
  } else if (Util.starts_with(~prefix="compozy:", value)) {
    normalize_compozy_entry(value);
  } else if (String.contains(value, '/') || String.contains(value, ':')) {
    Error({
      value,
      reason: "issue URLs and cross-repository references are not supported",
    });
  } else {
    switch (Util.drop_prefix(~prefix="mb-", value)) {
    | Some(number_text) =>
      if (digits_only(number_text)) {
        switch (int_of_string_opt(number_text)) {
        | Some(issue_number) when issue_number > 0 =>
          Ok({issue_identifier: "mb-" ++ string_of_int(issue_number)})
        | _ => Error({value, reason: "expected a minibeads issue identifier like mb-20"})
        };
      } else {
        Error({value, reason: "expected a minibeads issue identifier like mb-20"});
      };
    | None =>
      let number_text =
        switch (Util.drop_prefix(~prefix="#", value)) {
        | Some(suffix) => suffix
        | None => value
        };
      switch (int_of_string_opt(number_text)) {
      | Some(issue_number) when issue_number > 0 =>
        Ok({issue_identifier: "#" ++ string_of_int(issue_number)})
      | _ => Ok({issue_identifier: value})
      };
    };
  };
};

let parse = text => {
  let parts = String.split_on_char(',', text);
  let (entries, problems) =
    parts
    |> List.fold_left(
         ((entries, problems)) =>
           part =>
             switch (normalize_entry(part)) {
             | Ok(entry) => ([entry, ...entries], problems)
             | Error(problem) => (entries, [problem, ...problems])
             },
         ([], []),
       );
  let entries = List.rev(entries);
  let problems = List.rev(problems);
  let seen = Hashtbl.create(16);
  let duplicates =
    entries
    |> List.filter_map(entry => {
         let count =
           Option.value(Hashtbl.find_opt(seen, entry.issue_identifier), ~default=0) + 1;
         Hashtbl.replace(seen, entry.issue_identifier, count);
         if (count == 2) {
           Some({value: entry.issue_identifier, reason: "duplicate issue identifier"});
         } else {
           None;
         };
       });
  switch (problems @ duplicates) {
  | [] => Ok({entries: entries})
  | problems => Error(problems)
  };
};

let identifiers = queue =>
  List.map(entry => entry.issue_identifier, queue.entries);

let same_sequence = (left, right) => identifiers(left) == identifiers(right);

let resolve = (tracker: Issue_tracker.t, queue) => {
  let (resolved, problems) =
    queue.entries
    |> List.fold_left(
         ((resolved, problems)) =>
           ((entry: entry)) =>
             switch (tracker.normalize_identifier(entry.issue_identifier)) {
             | Ok(canonical_identifier) =>
               (
                 [{queue_identifier: entry.issue_identifier, canonical_identifier}, ...resolved],
                 problems,
               )
             | Error(reason) =>
               (resolved, [{queue_identifier: entry.issue_identifier, reason}, ...problems])
             },
         ([], []),
       );
  let resolved = List.rev(resolved);
  let problems = List.rev(problems);
  let seen = Hashtbl.create(16);
  let duplicate_problems =
    resolved
    |> List.filter_map(entry => {
         let count =
           Option.value(Hashtbl.find_opt(seen, entry.canonical_identifier), ~default=0) + 1;
         Hashtbl.replace(seen, entry.canonical_identifier, count);
         if (count == 2) {
           Some({
             queue_identifier: entry.queue_identifier,
             reason:
               "duplicate issue identifier after tracker normalization: "
               ++ entry.canonical_identifier,
           });
         } else {
           None;
         };
       });
  let compozy_style_problem =
    if (tracker.kind == "compozy_tasks") {
      let has_canonical =
        queue.entries
        |> List.exists(entry =>
             Util.starts_with(~prefix="compozy:", entry.issue_identifier)
           );
      let has_bare =
        queue.entries
        |> List.exists(entry =>
             !Util.starts_with(~prefix="compozy:", entry.issue_identifier)
           );
      if (has_canonical && has_bare) {
        [
          {
            queue_identifier: "compozy",
            reason:
              "mixed bare and canonical Compozy queue identifiers are not supported; use either bare slugs or compozy:<slug> selectors",
          },
        ];
      } else {
        [];
      };
    } else {
      [];
    };
  switch (problems @ duplicate_problems @ compozy_style_problem) {
  | [] => Ok(resolved)
  | problems => Error(problems)
  };
};

let resolved_identifiers = entries =>
  List.map(entry => entry.canonical_identifier, entries);

let queue_identifier_for_canonical = (resolved, canonical_identifier) =>
  resolved
  |> List.find_map((entry: resolved_entry) =>
       entry.canonical_identifier == canonical_identifier
         ? Some(entry.queue_identifier)
         : None
     )
  |> Option.value(~default=canonical_identifier);

let validation_gaps = (tracker: Issue_tracker.t, queue) =>
  switch (resolve(tracker, queue)) {
  | Error(problems) =>
    problems
    |> List.map(problem => {
         {
           requirement: "orderedQueue." ++ problem.queue_identifier,
           remediation: "Ordered Queue validation failed: " ++ problem.reason,
         };
       })
  | Ok(resolved) =>
    switch (tracker.fetch_by_identifiers_detailed(resolved_identifiers(resolved))) {
    | Error(message) =>
      [
        {
          requirement: "orderedQueue.validation",
          remediation: "Ordered Queue validation failed: " ++ message,
        },
      ]
    | Ok(results) =>
      results
      |> List.filter_map((result: Issue_tracker.lookup_result) => {
           let queue_identifier =
             queue_identifier_for_canonical(resolved, result.identifier);
           let issue_gap = issue =>
             if (tracker.is_terminal(issue.Issue.state)) {
               Some({
                 requirement: "orderedQueue." ++ queue_identifier,
                 remediation:
                   Printf.sprintf("Issue is terminal in tracker state %S.", issue.state),
               });
             } else if (!tracker.is_active(issue.Issue.state)) {
               Some({
                 requirement: "orderedQueue." ++ queue_identifier,
                 remediation:
                   Printf.sprintf(
                     "Issue is not dispatchable in tracker state %S.",
                     issue.state,
                   ),
               });
             } else {
               None;
             };
           switch (result.diagnostics) {
           | [Issue_tracker.Missing_issue, ..._] =>
             Some({
               requirement: "orderedQueue." ++ queue_identifier,
               remediation:
                 "Issue is missing from the selected Issue Tracker.",
             })
           | [Issue_tracker.Missing_project_membership(project_number), ..._] =>
             Some({
               requirement: "orderedQueue." ++ queue_identifier,
               remediation:
                 Printf.sprintf(
                   "Issue is absent from GitHub Project #%d.",
                   project_number,
                 ),
             })
           | [Issue_tracker.Closed_issue, ..._] =>
             Some({
               requirement: "orderedQueue." ++ queue_identifier,
               remediation: "Issue is closed in the selected Issue Tracker.",
             })
           | [] =>
             switch (result.issue) {
             | Some(issue) => issue_gap(issue)
             | None =>
               Some({
                 requirement: "orderedQueue." ++ queue_identifier,
                 remediation:
                   "Issue is missing from the selected Issue Tracker.",
               })
             }
           };
         })
    };
  };
