type selector = { raw : string; number : int; identifier : string }

type integration = Merged | Already_integrated

type outcome = {
  issue : Issue.t;
  branch : string;
  workspace : Workspace.t;
  integration : integration;
  status_update : string option;
  cleanup_error : string option;
}

type report = { outcomes : outcome list; merged : int; already_integrated : int; cleanup_failures : int }

type fetch_issues = int list -> (int * Github_tracker.project_issue option) list
type set_status = Issue.t -> string -> (unit, string) result

let split_comma text =
  text |> String.split_on_char ',' |> List.map Util.trim |> List.filter (fun part -> part <> "")

let digits_only text =
  text <> ""
  && String.for_all
       (function
         | '0' .. '9' -> true
         | _ -> false)
       text

let normalize_one raw =
  let trimmed = Util.trim raw in
  let body =
    if String.length trimmed > 0 && trimmed.[0] = '#' then String.sub trimmed 1 (String.length trimmed - 1)
    else trimmed
  in
  if digits_only body then
    match int_of_string_opt body with
    | Some number when number > 0 -> Ok { raw = trimmed; number; identifier = "#" ^ string_of_int number }
    | _ -> Error (Printf.sprintf "invalid Manual Task Merge selector %S" raw)
  else Error (Printf.sprintf "invalid Manual Task Merge selector %S; expected an issue identifier like 20 or #20" raw)

let normalize_selectors args =
  let raw_selectors = List.concat_map split_comma args in
  if raw_selectors = [] then Error [ "Manual Task Merge requires at least one issue identifier" ]
  else
    let seen = Hashtbl.create 8 in
    let rec loop acc errors = function
      | [] -> if errors = [] then Ok (List.rev acc) else Error (List.rev errors)
      | raw :: rest -> (
          match normalize_one raw with
          | Error error -> loop acc (error :: errors) rest
          | Ok selector ->
              if Hashtbl.mem seen selector.number then
                loop acc
                  (Printf.sprintf "duplicate Manual Task Merge selector %s" selector.identifier :: errors)
                  rest
              else (
                Hashtbl.add seen selector.number ();
                loop (selector :: acc) errors rest))
    in
    loop [] [] raw_selectors

let command_ok ~cwd command =
  match Orchestrator.run_shell_capture ~cwd command with Ok _ -> true | Error _ -> false

let rev_parse ~cwd refname =
  Orchestrator.run_shell_capture ~cwd (Printf.sprintf "git rev-parse %s" (Util.shell_quote refname))
  |> Result.map Util.trim

let is_ancestor ~cwd ~ancestor ~descendant =
  command_ok ~cwd
    (Printf.sprintf "git merge-base --is-ancestor %s %s" (Util.shell_quote ancestor) (Util.shell_quote descendant))

let cleanup config issue workspace =
  let errors = ref [] in
  (if config.Config.git.cleanup.remove_worktree_after_merge then
    match
      Orchestrator.run_shell_capture ~cwd:config.Config.repository_root
        (Printf.sprintf "git worktree remove %s" (Util.shell_quote workspace.Workspace.path))
    with
    | Ok _ -> ()
    | Error error -> errors := ("worktree cleanup failed: " ^ error) :: !errors);
  (if not config.Config.git.cleanup.keep_task_branch then
    match
      Orchestrator.run_shell_capture ~cwd:config.Config.repository_root
        (Printf.sprintf "git branch -d %s" (Util.shell_quote (Orchestrator.task_branch config issue)))
    with
    | Ok _ -> ()
    | Error error -> errors := ("task branch cleanup failed: " ^ error) :: !errors);
  match List.rev !errors with [] -> None | errors -> Some (String.concat "; " errors)

let review_success_status config issue =
  match Orchestrator.stage_for_issue config issue with
  | Some stage -> stage.Config.success_status
  | None -> None

type preflight = {
  selector : selector;
  issue : Issue.t;
  branch : string;
  workspace : Workspace.t;
  already_integrated : bool;
}

let preflight_one config ~projected_tip row selector =
  match row with
  | None -> Error (Printf.sprintf "%s is missing from the Workspace Repository issue tracker" selector.identifier)
  | Some { Github_tracker.project_status = None; _ } ->
      Error
        (Printf.sprintf "%s is absent from GitHub Project #%d" selector.identifier config.Config.tracker.project_number)
  | Some { issue; _ } ->
      let branch = Orchestrator.task_branch config issue in
      let workspace = Workspace.create_for_issue ~root:config.Config.workspace.root issue.Issue.identifier in
      let terminal = Github_tracker.status_is_terminal ~config:config.Config.tracker issue.Issue.state in
      if not (Orchestrator.git_ref_exists config.repository_root branch) then
        Error (Printf.sprintf "%s expected Task Branch %s does not exist" selector.identifier branch)
      else
        match Orchestrator.worktree_branch workspace.path with
        | None -> Error (Printf.sprintf "%s expected Agent Worktree at %s" selector.identifier workspace.path)
        | Some existing when existing <> branch ->
            Error (Printf.sprintf "%s Agent Worktree uses %s but expected %s" selector.identifier existing branch)
        | Some _ -> (
            match Orchestrator.has_worktree_changes workspace.path with
            | Error error -> Error (Printf.sprintf "%s Agent Worktree status failed at %s: %s" selector.identifier workspace.path error)
            | Ok true -> Error (Printf.sprintf "%s Agent Worktree must be clean: %s" selector.identifier workspace.path)
            | Ok false ->
                let already_integrated =
                  is_ancestor ~cwd:config.repository_root ~ancestor:branch ~descendant:projected_tip
                in
                if already_integrated then Ok ({ selector; issue; branch; workspace; already_integrated }, projected_tip)
                else if terminal then
                  Error
                    (Printf.sprintf "%s is terminal in project state %S but %s is not on the Loop-Start Branch"
                       selector.identifier issue.state branch)
                else if is_ancestor ~cwd:config.repository_root ~ancestor:projected_tip ~descendant:branch then (
                  match rev_parse ~cwd:config.repository_root branch with
                  | Ok next_tip -> Ok ({ selector; issue; branch; workspace; already_integrated }, next_tip)
                  | Error error ->
                      Error (Printf.sprintf "%s Task Branch tip could not be resolved: %s" selector.identifier error))
                else
                  Error
                    (Printf.sprintf "%s Task Branch %s cannot fast-forward from projected Loop-Start Branch tip"
                       selector.identifier branch))

let preflight config ~fetch_issues selectors =
  if not (Orchestrator.is_git_repository config.Config.repository_root) then Error [ "Manual Task Merge requires a Git Workspace Repository" ]
  else
    match Orchestrator.has_worktree_changes config.repository_root with
    | Error error -> Error [ "Loop-Start Worktree status failed at " ^ config.repository_root ^ ": " ^ error ]
    | Ok true -> Error [ "Loop-Start Worktree must be clean: " ^ config.repository_root ]
    | Ok false -> (
        let fetched = fetch_issues (List.map (fun selector -> selector.number) selectors) in
        let row_for number = List.assoc_opt number fetched |> Option.join in
        match rev_parse ~cwd:config.repository_root "HEAD" with
        | Error error -> Error [ "Loop-Start Branch tip could not be resolved: " ^ error ]
        | Ok head ->
            let rec loop projected acc errors = function
              | [] -> if errors = [] then Ok (List.rev acc) else Error (List.rev errors)
              | selector :: rest -> (
                  match preflight_one config ~projected_tip:projected (row_for selector.number) selector with
                  | Ok (item, next_tip) -> loop next_tip (item :: acc) errors rest
                  | Error error -> loop projected acc (error :: errors) rest)
            in
            loop head [] [] selectors)

let integrate_one config ~set_status item =
  let integration =
    if item.already_integrated then Ok Already_integrated
    else
      match
        Orchestrator.run_shell_capture ~cwd:config.Config.repository_root
          (Printf.sprintf "git merge --ff-only %s" (Util.shell_quote item.branch))
      with
      | Ok _ -> Ok Merged
      | Error error -> Error error
  in
  match integration with
  | Error error -> Error (Printf.sprintf "%s merge failed after preflight: %s" item.selector.identifier error)
  | Ok integration ->
      let status_update =
        match review_success_status config item.issue with
        | None -> None
        | Some status -> (
            match set_status item.issue status with
            | Ok () -> Some status
            | Error error -> raise (Failure (Printf.sprintf "%s tracker status update failed: %s" item.selector.identifier error)))
      in
      let cleanup_error = cleanup config item.issue item.workspace in
      Ok { issue = item.issue; branch = item.branch; workspace = item.workspace; integration; status_update; cleanup_error }

let run ~fetch_issues ~set_status config args =
  match normalize_selectors args with
  | Error errors -> Error errors
  | Ok selectors -> (
      match preflight config ~fetch_issues selectors with
      | Error errors -> Error errors
      | Ok items -> (
          try
            let outcomes =
              List.map
                (fun item ->
                  match integrate_one config ~set_status item with Ok outcome -> outcome | Error error -> raise (Failure error))
                items
            in
            let merged =
              List.fold_left
                (fun count outcome -> match outcome.integration with Merged -> count + 1 | Already_integrated -> count)
                0 outcomes
            in
            let already_integrated = List.length outcomes - merged in
            let cleanup_failures =
              outcomes |> List.filter (fun outcome -> Option.is_some outcome.cleanup_error) |> List.length
            in
            Ok { outcomes; merged; already_integrated; cleanup_failures }
          with Failure error -> Error [ error ]))
