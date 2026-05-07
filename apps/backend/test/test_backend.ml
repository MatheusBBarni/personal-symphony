let with_temp_file content f =
  let path = Filename.temp_file "workflow" ".md" in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      let oc = open_out path in
      output_string oc content;
      close_out oc;
      f path)

let with_temp_dir prefix f =
  let root = Filename.concat (Filename.get_temp_dir_name ()) (prefix ^ string_of_int (Random.bits ())) in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.command ("rm -rf " ^ Util.shell_quote root)))
    (fun () ->
      Unix.mkdir root 0o755;
      f root)

let run_ok ?(cwd = ".") label command =
  match Orchestrator.run_shell_capture ~cwd command with
  | Ok output -> output
  | Error error -> Alcotest.fail (label ^ ": " ^ error)

let contains_substring text substring =
  let text_len = String.length text in
  let substring_len = String.length substring in
  let rec loop index =
    if substring_len = 0 then true
    else if index + substring_len > text_len then false
    else if String.sub text index substring_len = substring then true
    else loop (index + 1)
  in
  loop 0

let init_repo root branch =
  ignore (run_ok ~cwd:root "git init" (Printf.sprintf "git init -q -b %s" (Util.shell_quote branch)));
  ignore (run_ok ~cwd:root "git user email" "git config user.email test@example.com");
  ignore (run_ok ~cwd:root "git user name" "git config user.name Test");
  Util.write_file (Filename.concat root "README.md") "initial\n";
  ignore (run_ok ~cwd:root "initial commit" "git add README.md && git commit -q -m initial")

let ignore_runtime_home root =
  Util.write_file (Filename.concat root ".gitignore") ".symphony/\n";
  ignore (run_ok ~cwd:root "ignore runtime home" "git add .gitignore && git commit -q -m ignore-runtime-home")

let git_policy ?(auto_merge = false) ?(protected_trunk_branches = [ "main"; "master" ])
    ?(allowed_loop_start_branches = [])
    ?(merge_attention_status = "Human attention") ?(remove_worktree_after_merge = true) () =
  {
    Config.default_git with
    auto_merge;
    protected_trunk_branches;
    allowed_loop_start_branches;
    merge_attention_status;
    cleanup = { Config.remove_worktree_after_merge = remove_worktree_after_merge; keep_task_branch = true };
  }

let test_config_parses_git_policy_and_stage_push () =
  with_temp_dir "symphony-settings-git-" (fun root ->
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony/agents");
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "git": {
    "taskBranchPrefix": "agent/",
    "protectedTrunkBranches": ["main", "release"],
    "allowedLoopStartBranches": ["symphony/dogfood"],
    "autoMerge": false,
    "mergeAttentionStatus": "Needs merge",
    "cleanup": {"removeWorktreeAfterMerge": false, "keepTaskBranch": true}
  },
  "pullRequest": {
    "enabled": true,
    "mode": "task",
    "openOnReview": true,
    "baseBranch": "main",
    "title": "Symphony batch from <head_branch> into <base_branch>",
    "body": "Batch handoff for <head_branch>."
  },
  "paths": {
    "protected": {
      "patterns": [
        {"name": "cli-entrypoint", "pattern": "bin/symphony.js"},
        {"name": "package-scripts", "pattern": "scripts/package-*.js", "reason": "release-sensitive"}
      ],
      "authorization": {"issueSection": "Protected Path Authorization"}
    }
  },
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {
        "states": ["In progress"],
        "agent": "engineer",
        "maxConcurrentAgents": 2,
        "commit": {"enabled": true, "type": "feat", "message": "<type>: work", "push": true}
      },
      {
        "states": ["In review"],
        "agent": "reviewer",
        "commit": {
          "enabled": false,
          "type": "refactor",
          "message": "<type>: review",
          "classification": {
            "default": "docs",
            "labelMap": {"documentation": "docs", "bug": "fix"},
            "conflictBehavior": "human_attention"
          }
        }
      }
    ]
  }
}|};
      Util.write_file (Filename.concat root ".symphony/agents/engineer.md") "Engineer";
      Unix.putenv "GITHUB_TOKEN" "token";
      let config = Config.from_settings_file ~workspace_root:root settings in
      Alcotest.(check string) "branch prefix" "agent/" config.git.task_branch_prefix;
      Alcotest.(check (list string)) "protected trunks" [ "main"; "release" ] config.git.protected_trunk_branches;
      Alcotest.(check (list string)) "allowed loop-start branches" [ "symphony/dogfood" ]
        config.git.allowed_loop_start_branches;
      Alcotest.(check bool) "auto merge" false config.git.auto_merge;
      Alcotest.(check string) "attention status" "Needs merge" config.git.merge_attention_status;
      Alcotest.(check bool) "attention status visible" true
        (List.exists (( = ) "Needs merge") config.tracker.terminal_states);
      Alcotest.(check bool) "cleanup worktree" false config.git.cleanup.remove_worktree_after_merge;
      Alcotest.(check bool) "pull request enabled" true config.pull_request.enabled;
      Alcotest.(check string) "pull request mode" "task" config.pull_request.mode;
      Alcotest.(check bool) "pull request opens on review" true config.pull_request.open_on_review;
      Alcotest.(check string) "pull request base" "main" config.pull_request.base_branch;
      Alcotest.(check string) "pull request title" "Symphony batch from <head_branch> into <base_branch>" config.pull_request.title;
      Alcotest.(check int) "protected path patterns" 2 (List.length config.protected_paths.patterns);
      Alcotest.(check string) "protected authorization section" "Protected Path Authorization"
        config.protected_paths.authorization.issue_section;
      (match config.stage_agents.stages with
      | [ { Config.commit = Some engineer_commit; _ } as engineer; { Config.commit = Some reviewer_commit; _ } ] ->
          Alcotest.(check (option int)) "stage max concurrent agents" (Some 2) engineer.max_concurrent_agents;
          Alcotest.(check bool) "stage push" true engineer_commit.push;
          Alcotest.(check bool) "stage push default" false reviewer_commit.push;
          (match reviewer_commit.classification with
          | Some classification ->
              Alcotest.(check string) "classification default" "docs" classification.default;
              Alcotest.(check (list (pair string string))) "classification label map"
                [ ("documentation", "docs"); ("bug", "fix") ]
                classification.label_map;
              Alcotest.(check string) "classification conflict behavior" "human_attention"
                classification.conflict_behavior
          | None -> Alcotest.fail "expected classification policy")
      | _ -> Alcotest.fail "expected stage commit policy");
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {
        "states": ["In progress"],
        "agent": "engineer",
        "commit": {
          "enabled": true,
          "type": "feat",
          "classification": {"default": "", "labelMap": {"bug": "fix"}}
        }
      }
    ]
  }
}|};
      Alcotest.check_raises "empty classification default is invalid"
        (Config.Invalid_config "stageAgents.stages[].commit.classification.default must not be empty")
        (fun () -> ignore (Config.from_settings_file ~workspace_root:root settings)))

let test_config_validates_stage_concurrency_policy () =
  with_temp_dir "symphony-settings-stage-cap-" (fun root ->
      Util.mkdir_p (Filename.concat root ".symphony/agents");
      Util.write_file (Filename.concat root ".symphony/agents/engineer.md") "Engineer";
      Unix.putenv "GITHUB_TOKEN" "token";
      let write_settings stage_field =
        let settings = Filename.concat root ("settings-" ^ string_of_int (Random.bits ()) ^ ".json") in
        Util.write_file settings
          (Printf.sprintf
             {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer"%s}
    ]
  }
}|}
             stage_field);
        settings
      in
      let omitted = Config.from_settings_file ~workspace_root:root (write_settings "") in
      let valid = Config.from_settings_file ~workspace_root:root (write_settings {js|, "maxConcurrentAgents": 2|js}) in
      (match (omitted.stage_agents.stages, valid.stage_agents.stages) with
      | [ omitted_stage ], [ valid_stage ] ->
          Alcotest.(check (option int)) "omitted stage cap" None omitted_stage.max_concurrent_agents;
          Alcotest.(check (option int)) "valid stage cap" (Some 2) valid_stage.max_concurrent_agents
      | _ -> Alcotest.fail "expected one configured stage");
      let assert_invalid label stage_field =
        match Config.from_settings_file ~workspace_root:root (write_settings stage_field) with
        | _ -> Alcotest.fail (label ^ " should be invalid")
        | exception Config.Invalid_config message ->
            Alcotest.(check string) label "stageAgents.stages.maxConcurrentAgents must be positive" message
      in
      assert_invalid "zero stage cap" {js|, "maxConcurrentAgents": 0|js};
      assert_invalid "negative stage cap" {js|, "maxConcurrentAgents": -1|js};
      assert_invalid "non-integer stage cap" {js|, "maxConcurrentAgents": "two"|js})

let test_config_parses_stage_context_snapshot_and_readiness () =
  with_temp_dir "symphony-settings-stage-context-" (fun root ->
      Util.mkdir_p (Filename.concat root ".symphony/agents");
      Util.write_file (Filename.concat root ".symphony/agents/engineer.md") "Engineer";
      Unix.putenv "GITHUB_TOKEN" "token";
      let write_settings stage_field =
        let settings = Filename.concat root ("settings-" ^ string_of_int (Random.bits ()) ^ ".json") in
        Util.write_file settings
          (Printf.sprintf
             {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer"%s}
    ]
  }
}|}
             stage_field);
        Config.from_settings_file ~workspace_root:root settings
      in
      let omitted = write_settings "" in
      (match omitted.stage_agents.stages with
      | [ stage ] -> Alcotest.(check bool) "omitted snapshot disabled" false (Config.stage_context_snapshot_enabled stage)
      | _ -> Alcotest.fail "expected one configured stage");
      let enabled =
        write_settings {js|, "context": {"snapshot": {"enabled": true, "maxOutputBytes": 4096}}|js}
      in
      (match enabled.stage_agents.stages with
      | [ { Config.context_snapshot = Some snapshot; _ } as stage ] ->
          Alcotest.(check bool) "snapshot enabled" true (Config.stage_context_snapshot_enabled stage);
          Alcotest.(check int) "snapshot cap" 4096 snapshot.max_output_bytes
      | _ -> Alcotest.fail "expected enabled snapshot");
      let invalid =
        write_settings {js|, "context": {"snapshot": {"enabled": true, "maxOutputBytes": "large"}}|js}
      in
      let gaps = Config.readiness_gaps invalid in
      match
        List.find_opt
          (fun (gap : Config.readiness_gap) -> gap.requirement = "stageAgents.engineer.context.snapshot")
          gaps
      with
      | Some gap ->
          Alcotest.(check bool) "mentions setting path" true
            (contains_substring gap.remediation "stageAgents.stages[].context.snapshot.maxOutputBytes")
      | None -> Alcotest.fail "expected context snapshot readiness gap")

let test_config_parses_allowed_loop_start_branch_policy () =
  with_temp_dir "symphony-loop-start-policy-" (fun root ->
      Util.mkdir_p (Filename.concat root ".symphony/agents");
      Util.write_file (Filename.concat root ".symphony/agents/engineer.md") "Engineer";
      Unix.putenv "GITHUB_TOKEN" "token";
      let write_settings body =
        let settings = Filename.concat root ("settings-" ^ string_of_int (Random.bits ()) ^ ".json") in
        Util.write_file settings body;
        Config.from_settings_file ~workspace_root:root settings
      in
      let omitted =
        write_settings
          {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {"enabled": false}
}|}
      in
      Alcotest.(check (list string)) "omitted allows any branch" [] omitted.git.allowed_loop_start_branches;
      let empty =
        write_settings
          {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "git": {"allowedLoopStartBranches": []},
  "stageAgents": {"enabled": false}
}|}
      in
      Alcotest.(check (list string)) "empty allows any branch" [] empty.git.allowed_loop_start_branches;
      let valid =
        write_settings
          {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "git": {"allowedLoopStartBranches": ["symphony/dogfood", "release/train"]},
  "stageAgents": {"enabled": false}
}|}
      in
      Alcotest.(check (list string)) "valid branches" [ "symphony/dogfood"; "release/train" ]
        valid.git.allowed_loop_start_branches;
      Alcotest.check_raises "whitespace-only branch is invalid"
        (Config.Invalid_config "git.allowedLoopStartBranches must not contain empty branch names")
        (fun () ->
          ignore
            (write_settings
               {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "git": {"allowedLoopStartBranches": ["   "]},
  "stageAgents": {"enabled": false}
}|})))

let test_config_parses_stage_goal_and_readiness () =
  let original_home = Sys.getenv_opt "HOME" in
  let original_probe = Sys.getenv_opt "SYMPHONY_CODEX_GOAL_STDIN_PROBE" in
  Fun.protect
    ~finally:(fun () ->
      (match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "");
      match original_probe with
      | Some value -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" value
      | None -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "";
          Unix.putenv "GITHUB_TOKEN" "token";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          (match config.stage_agents.stages with
          | [ stage ] -> Alcotest.(check bool) "goal enabled" true (Config.stage_goal_enabled stage)
          | _ -> Alcotest.fail "expected one stage");
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "missing codex goals gap" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps);
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[ features ]\ngoals = true # enable Codex goals\n";
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex goals gap resolved" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps)))

let test_disabled_stage_goal_does_not_require_codex_goals () =
  let original_home = Sys.getenv_opt "HOME" in
  Fun.protect
    ~finally:(fun () -> match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-disabled-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": false}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "no codex goals gap" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps);
          Alcotest.(check bool) "no stdin gap" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_config_parses_stage_skill_load_and_readiness () =
  let original_codex_home = Sys.getenv_opt "CODEX_HOME" in
  Fun.protect
    ~finally:(fun () ->
      match original_codex_home with
      | Some value -> Unix.putenv "CODEX_HOME" value
      | None -> Unix.putenv "CODEX_HOME" "")
    (fun () ->
      with_temp_dir "symphony-stage-skills-" (fun root ->
          Unix.putenv "GITHUB_TOKEN" "token";
          let codex_home = Filename.concat root "codex-home" in
          Unix.putenv "CODEX_HOME" codex_home;
          let agents_root = Filename.concat root ".symphony/agents" in
          let workspace_skills = Filename.concat root ".agents/skills" in
          let codex_skills = Filename.concat codex_home "skills" in
          Util.mkdir_p agents_root;
          Util.mkdir_p (Filename.concat workspace_skills "to-prd");
          Util.mkdir_p (Filename.concat workspace_skills "shared-skill");
          Util.mkdir_p (Filename.concat codex_skills "imagegen");
          Util.mkdir_p (Filename.concat codex_skills "shared-skill");
          Util.write_file (Filename.concat agents_root "planner.md") "Planner";
          Util.write_file (Filename.concat (Filename.concat workspace_skills "to-prd") "SKILL.md") "workspace skill";
          Util.write_file (Filename.concat (Filename.concat workspace_skills "shared-skill") "SKILL.md") "workspace shared";
          Util.write_file (Filename.concat (Filename.concat codex_skills "imagegen") "SKILL.md") "home skill";
          Util.write_file (Filename.concat (Filename.concat codex_skills "shared-skill") "SKILL.md") "home shared";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Backlog"], "agent": "planner", "skills": ["to-prd", "imagegen", "shared-skill"]}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          (match config.stage_agents.stages with
          | [ stage ] -> Alcotest.(check (list string)) "ordered skills" [ "to-prd"; "imagegen"; "shared-skill" ] stage.skills
          | _ -> Alcotest.fail "expected one stage");
          Alcotest.(check int) "no readiness gaps" 0 (List.length (Config.readiness_gaps config));
          Alcotest.(check string) "workspace wins"
            (Filename.concat (Filename.concat workspace_skills "shared-skill") "SKILL.md")
            (Option.value (Config.resolve_stage_skill_path config "shared-skill") ~default:"missing");
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Backlog"], "agent": "planner", "skills": ["to-prd", "to-prd", "$bad", "missing-skill"]}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let requirements = Config.readiness_gaps config |> List.map (fun (gap : Config.readiness_gap) -> gap.requirement) in
          Alcotest.(check bool) "duplicate gap" true (List.exists (( = ) "stageAgents.planner.skills.to-prd") requirements);
          Alcotest.(check bool) "malformed gap" true (List.exists (( = ) "stageAgents.planner.skills.$bad") requirements);
          Alcotest.(check bool) "missing gap" true
            (List.exists (( = ) "stageAgents.planner.skills.missing-skill") requirements)))

let test_stage_goal_requires_codex_exec_stdin_support () =
  let original_home = Sys.getenv_opt "HOME" in
  Fun.protect
    ~finally:(fun () -> match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-stdin-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[features]\ngoals = true\n";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "cat"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "stdin gap" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "env CODEX_HOME=/tmp/codex /usr/local/bin/codex -m <model> exec"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex exec path accepted with env" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "printf codex exec"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex as argument rejected" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_stage_goal_live_stdin_probe () =
  let original_home = Sys.getenv_opt "HOME" in
  let original_probe = Sys.getenv_opt "SYMPHONY_CODEX_GOAL_STDIN_PROBE" in
  Fun.protect
    ~finally:(fun () ->
      (match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "");
      match original_probe with
      | Some value -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" value
      | None -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-live-probe-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "1";
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[features]\ngoals = true\n";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let fake_codex = Filename.concat root "fake-codex.sh" in
          Util.write_file fake_codex
            {|#!/bin/sh
input="$(cat)"
case "$input" in
  /goal*) exit 0 ;;
  *) exit 42 ;;
esac
|};
          Unix.chmod fake_codex 0o755;
          let settings = Filename.concat root "settings.json" in
          let write_settings command =
            Util.write_file settings
              (Printf.sprintf
                 {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": %S, "model": "fixture-model", "reasoningEffort": "low"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|}
                 command)
          in
          write_settings (fake_codex ^ " -m <model> exec");
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "live probe accepted" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          write_settings "false";
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "live probe rejected" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_pull_request_base_branch_readiness_gap () =
  with_temp_dir "symphony-settings-pr-gap-" (fun root ->
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony");
      Unix.putenv "GITHUB_TOKEN" "token";
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "pullRequest": {"enabled": true, "baseBranch": ""},
  "stageAgents": {"enabled": false}
}|};
      let config = Config.from_settings_file ~workspace_root:root settings in
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "base branch gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "pullRequest.baseBranch") gaps))

let test_pull_request_base_branch_must_differ_from_loop_start () =
  with_temp_dir "symphony-settings-pr-same-branch-gap-" (fun root ->
      init_repo root "main";
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony");
      Unix.putenv "GITHUB_TOKEN" "token";
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "pullRequest": {"enabled": true, "baseBranch": "main"},
  "stageAgents": {"enabled": false}
}|};
      let config = Config.from_settings_file ~workspace_root:root settings in
      let gaps = Config.readiness_gaps config in
      match List.find_opt (fun (gap : Config.readiness_gap) -> gap.requirement = "pullRequest.baseBranch") gaps with
      | Some gap ->
          Alcotest.(check bool) "mentions Loop-Start Branch" true
            (contains_substring gap.remediation "current Loop-Start Branch main")
      | None -> Alcotest.fail "expected pull request base branch gap")

let test_task_pull_request_allows_base_branch_to_equal_loop_start () =
  with_temp_dir "symphony-settings-task-pr-same-branch-" (fun root ->
      init_repo root "main";
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony");
      Unix.putenv "GITHUB_TOKEN" "token";
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "pullRequest": {"enabled": true, "mode": "task", "baseBranch": "main"},
  "stageAgents": {"enabled": false}
}|};
      let config = Config.from_settings_file ~workspace_root:root settings in
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "no self-target gap for Task Pull Requests" false
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "pullRequest.baseBranch") gaps))

let test_workflow_and_config () =
  let content =
    {|
---
tracker:
  kind: github
  owner: acme
  repo: widgets
  project_number: 7
  api_key: literal-token
  active_states: [Todo, Doing]
workspace:
  root: ./workspaces
codex:
  command: codex exec
---
Issue {{ issue.identifier }}: {{ issue.title }}
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      let config = Config.from_workflow workflow in
      Alcotest.(check string) "owner" "acme" config.tracker.owner;
      Alcotest.(check string) "repo" "widgets" config.tracker.repo;
      Alcotest.(check int) "project number" 7 config.tracker.project_number;
      Alcotest.(check (list string)) "active states" [ "Todo"; "Doing" ] config.tracker.active_states;
      Alcotest.(check string) "prompt" "Issue {{ issue.identifier }}: {{ issue.title }}" workflow.prompt_template)

let test_prompt_strict_rendering () =
  let issue =
    {
      (Issue.empty ~id:"I_kw" ~identifier:"#42" ~title:"Fix build" ~state:"Todo") with
      comments =
        [
          {
            Issue.author = Some "matheus";
            body = "Please include issue comments.";
            created_at = Some "2026-05-06T18:00:00Z";
            url = Some "https://example.test/comment/1";
          };
        ];
    }
  in
  Alcotest.(check string)
    "rendered prompt" "Work on #42: Fix build attempt=2"
    (Prompt.render ~issue ~attempt:(Some 2) "Work on {{ issue.identifier }}: {{ issue.title }} attempt={{ attempt }}");
  Alcotest.(check bool) "renders comments" true
    (contains_substring
       (Prompt.render ~issue ~attempt:None "Comments:\n{{ issue.comments }}")
       "matheus at 2026-05-06T18:00:00Z:\nPlease include issue comments.");
  Alcotest.check_raises "unknown issue field fails"
    (Prompt.Template_render_error "unknown issue field: missing")
    (fun () -> ignore (Prompt.render ~issue ~attempt:None "{{ issue.missing }}"))

let test_workspace_safety () =
  let root = Filename.concat (Filename.get_temp_dir_name ()) ("symphony-test-" ^ string_of_int (Random.bits ())) in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.command ("rm -rf " ^ Util.shell_quote root)))
    (fun () ->
      let workspace = Workspace.create_for_issue ~root "ABC/42 needs work" in
      Alcotest.(check string) "sanitized" "ABC_42_needs_work" workspace.workspace_key;
      Alcotest.(check bool) "created" true workspace.created_now;
      Alcotest.(check bool) "inside root" true (Workspace.is_inside ~root ~path:workspace.path);
      let reused = Workspace.create_for_issue ~root "ABC/42 needs work" in
      Alcotest.(check bool) "reused" false reused.created_now)

let test_shell_launch_runs_agent_in_agent_worktree () =
  with_temp_dir "symphony-launch-root-" (fun root ->
      let workspace_root = Filename.concat root "workspaces" in
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = workspace_root };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex =
            {
              command = "sh -c 'pwd > launched.cwd; cat > launched.prompt'";
              model = Config.default_model;
              reasoning_effort = Config.default_reasoning_effort;
              turn_timeout_ms = 1000;
              read_timeout_ms = 100;
              stall_timeout_ms = 1000;
            };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:workspace_root issue.identifier in
      let launched = Orchestrator.shell_launch ~config ~workspace ~prompt:"Issue #1" ~issue in
      (match launched.pid with
      | Some pid -> ignore (Unix.waitpid [] pid)
      | None -> Alcotest.fail "expected shell launch pid");
      Alcotest.(check string) "agent cwd" (Unix.realpath workspace.path)
        (Util.read_file (Filename.concat workspace.path "launched.cwd") |> Util.trim);
      Alcotest.(check string) "prompt piped" "Issue #1" (Util.read_file (Filename.concat workspace.path "launched.prompt") |> Util.trim);
      Alcotest.(check bool) "loop-start unchanged" false (Sys.file_exists (Filename.concat root "launched.cwd")))

let test_invalid_tracker_kind () =
  let content =
    {|
---
tracker:
  kind: linear
---
body
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      Alcotest.check_raises "linear rejected"
        (Config.Invalid_config "tracker.kind must be github for this implementation")
        (fun () -> ignore (Config.from_workflow workflow)))

let test_legacy_codex_app_server_command_normalizes_to_exec () =
  let content =
    {|
---
tracker:
  kind: github
  owner: acme
  repo: widgets
  project_number: 7
codex:
  command: codex app-server
---
body
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      let config = Config.from_workflow workflow in
      Alcotest.(check string) "legacy command" Config.default_codex_command config.codex.command)

let test_project_status_order_uses_transition_flow () =
  let tracker =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Backlog"; "Todo"; "To-Do"; "In progress"; "In Progress"; "In review" ];
      terminal_states = [ "Done"; "Closed"; "Cancelled" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "To-Do";
      ensure_project_statuses = true;
    }
  in
  let config =
    {
      Config.workflow_path = "settings.json";
      repository_root = "/tmp/widgets";
      tracker;
      polling = { interval_ms = 1000 };
      workspace = { root = "/tmp/widgets/.symphony/workspaces" };
      git = Config.default_git;
      agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
      codex =
        {
          command = Config.default_codex_command;
          model = Config.default_model;
          reasoning_effort = Config.default_reasoning_effort;
          turn_timeout_ms = 1000;
          read_timeout_ms = 100;
          stall_timeout_ms = 1000;
      };
    server = { port = None };
    pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
    stage_agents = { enabled = false; root = "/tmp/widgets/.symphony/agents"; default_agent = None; stages = [] };
    }
  in
  Alcotest.(check (list string)) "kanban status order" [ "To-Do"; "In progress"; "In review"; "Done" ]
    (Config.project_status_order config)

let test_bootstrap_idempotency_preserves_user_files () =
  with_temp_dir "symphony-bootstrap-" (fun root ->
      let home, first = Runtime_home.bootstrap root in
      Alcotest.(check bool) "settings created" true (Sys.file_exists home.settings_path);
      Alcotest.(check bool) "prompt created" true (Sys.file_exists home.prompt_path);
      let ignore_contents = Util.read_file (Filename.concat home.runtime_dir ".gitignore") in
      Alcotest.(check bool) "env ignored" true (String.contains ignore_contents 'e');
      Alcotest.(check bool) "state ignored" true (Util.starts_with ~prefix:"/.env" ignore_contents);
      Alcotest.(check bool) "planner agent created" true (Sys.file_exists (Filename.concat home.agents_dir "planner.md"));
      Alcotest.(check bool) "engineer agent created" true (Sys.file_exists (Filename.concat home.agents_dir "engineer.md"));
      Alcotest.(check bool) "reviewer agent created" true (Sys.file_exists (Filename.concat home.agents_dir "reviewer.md"));
      Util.write_file home.prompt_path "custom prompt {{ issue.title }}";
      let _, second = Runtime_home.bootstrap root in
      Alcotest.(check string) "prompt preserved" "custom prompt {{ issue.title }}" (Util.read_file home.prompt_path);
      Alcotest.(check bool) "created files on first run" true
        (List.exists (fun item -> item.Runtime_home.status = Runtime_home.Created) first);
      Alcotest.(check bool) "skipped files on second run" true
        (List.exists (fun item -> item.Runtime_home.status = Runtime_home.Skipped_existing) second))

let test_root_validation () =
  with_temp_dir "symphony-nongit-" (fun nongit ->
      let original = Unix.getcwd () in
      Fun.protect
        ~finally:(fun () -> Unix.chdir original)
        (fun () ->
          Unix.chdir nongit;
          match Runtime_home.require_workspace_root () with
          | Ok _ -> Alcotest.fail "non-git directories must be rejected"
          | Error msg -> Alcotest.(check bool) "mentions git repository" true (String.contains msg 'G')));
  with_temp_dir "symphony-git-" (fun root ->
      Alcotest.(check int) "git init" 0 (Sys.command ("git init -q " ^ Util.shell_quote root));
      let original = Unix.getcwd () in
      Fun.protect
        ~finally:(fun () -> Unix.chdir original)
        (fun () ->
          Unix.chdir root;
          Alcotest.(check (result string string)) "root accepted" (Ok (Unix.realpath root)) (Runtime_home.require_workspace_root ());
          Unix.mkdir "nested" 0o755;
          Unix.chdir "nested";
          match Runtime_home.require_workspace_root () with
          | Ok _ -> Alcotest.fail "nested directories must be rejected"
          | Error msg ->
              Alcotest.(check bool) "mentions repository root" true
                (String.contains msg 'r' && String.contains msg 'o' && String.contains msg 't')))

let test_settings_and_prompt_loading () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Unix.putenv "GITHUB_TOKEN" "";
  Unix.putenv "GH_TOKEN" "";
  with_temp_dir "symphony-settings-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let config = Config.from_settings_file ~workspace_root:root home.settings_path in
      Alcotest.(check string) "owner placeholder" "your-org" config.tracker.owner;
      Alcotest.(check string) "repo placeholder" "your-repo" config.tracker.repo;
      Alcotest.(check int) "project number" 1 config.tracker.project_number;
      Alcotest.(check string) "workspace root" (Filename.concat (Unix.realpath root) ".symphony/workspaces") config.workspace.root;
      Alcotest.(check int) "server port" 8080 (Option.get config.server.port);
      Alcotest.(check string) "codex model" "gpt-5.5" config.codex.model;
      Alcotest.(check string) "codex reasoning" "medium" config.codex.reasoning_effort;
      Alcotest.(check string) "codex launch command" "codex -m 'gpt-5.5' -c 'model_reasoning_effort=\"medium\"' exec"
        (Orchestrator.codex_command config);
      Alcotest.(check (option string)) "dispatch status" (Some "In progress") config.tracker.project_status_on_dispatch;
      Alcotest.(check (option string)) "review status" (Some "In review") config.tracker.project_status_on_success;
      Alcotest.(check (option string)) "retry status" (Some "To-Do") config.tracker.project_status_on_retry;
      Alcotest.(check bool) "ensure statuses" true config.tracker.ensure_project_statuses;
      Alcotest.(check bool) "stage agents enabled" true config.stage_agents.enabled;
      Alcotest.(check string) "stage agent root" (Filename.concat (Unix.realpath root) ".symphony/agents") config.stage_agents.root;
      Alcotest.(check int) "stage mappings" 3 (List.length config.stage_agents.stages);
      (match config.stage_agents.stages with
      | planner :: engineer :: _ ->
          Alcotest.(check (list string)) "planner skills default empty" [] planner.skills;
          Alcotest.(check (list string)) "engineer skills default empty" [] engineer.skills;
          Alcotest.(check (option string)) "planner success status" (Some "To-Do") planner.success_status;
          Alcotest.(check bool) "planner goal disabled" false (Config.stage_goal_enabled planner);
          Alcotest.(check bool) "engineer goal disabled" false (Config.stage_goal_enabled engineer);
          (match engineer.Config.commit with
          | Some commit ->
              Alcotest.(check bool) "engineer commits enabled" true commit.enabled;
              Alcotest.(check string) "engineer commit type" "feature" commit.commit_type;
              Alcotest.(check string) "engineer commit message" Config.default_commit_message commit.message
          | None -> Alcotest.fail "expected engineer commit policy")
      | _ -> Alcotest.fail "expected default stage mappings");
      let prompt = Runtime_home.load_prompt home in
      let issue = Issue.empty ~id:"I" ~identifier:"#1" ~title:"Install CLI" ~state:"Todo" in
      let rendered = Prompt.render ~issue ~attempt:(Some 3) prompt in
      Alcotest.(check bool) "rendered issue identifier" true (String.contains rendered '#');
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "placeholder owner gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "tracker.owner") gaps);
      Alcotest.(check bool) "token gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "environment.GITHUB_TOKEN") gaps));
  (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
  match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" ""

let test_runtime_env_loading () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Fun.protect
    ~finally:(fun () ->
      (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
      match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" "")
    (fun () ->
      Unix.putenv "GITHUB_TOKEN" "";
      Unix.putenv "GH_TOKEN" "";
      with_temp_dir "symphony-env-" (fun root ->
          let home, _ = Runtime_home.bootstrap root in
          Util.write_file home.env_path "GITHUB_TOKEN=github_pat_from_env_file\n";
          Runtime_home.load_env home;
          let config = Config.from_settings_file ~workspace_root:root home.settings_path in
          Alcotest.(check (option string)) "token loaded" (Some "github_pat_from_env_file") config.tracker.api_key;
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "token gap resolved" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "environment.GITHUB_TOKEN") gaps)))

let test_repo_url_readiness_gap () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Fun.protect
    ~finally:(fun () ->
      (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
      match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" "")
    (fun () ->
      Unix.putenv "GITHUB_TOKEN" "github_pat_test";
      Unix.putenv "GH_TOKEN" "";
      with_temp_dir "symphony-repo-url-" (fun root ->
          let home, _ = Runtime_home.bootstrap root in
          Util.write_file home.settings_path
            {|{
  "tracker": {
    "kind": "github",
    "owner": "acme",
    "repo": "https://github.com/acme/widgets",
    "projectNumber": 1,
    "apiKeyEnv": "GITHUB_TOKEN"
  }
}
|};
          let config = Config.from_settings_file ~workspace_root:root home.settings_path in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "repo URL gap" true
            (List.exists
               (fun (gap : Config.readiness_gap) ->
                 gap.requirement = "tracker.repo" && String.contains gap.remediation '/')
               gaps)))

let test_runtime_gitignore_contents () =
  with_temp_dir "symphony-ignore-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let contents = Util.read_file (Filename.concat home.runtime_dir ".gitignore") in
      Alcotest.(check bool) "ignores env" true (String.contains contents 'e');
      Alcotest.(check string) "exact ignore rules" "/.env\n/state/\n/workspaces/\n" contents)

let test_cli_mode_selection () =
  Alcotest.(check string) "terminal default" "terminal_console" (Cli_mode.(select ~web:false |> to_string));
  Alcotest.(check string) "web flag" "web_dashboard" (Cli_mode.(select ~web:true |> to_string))

let make_fake_npm_install root =
  let prefix = Filename.concat root "prefix" in
  let package_root = Filename.concat prefix "lib/node_modules/symphony-orchestrator" in
  let bin_dir = Filename.concat prefix "bin" in
  Util.mkdir_p (Filename.concat package_root "bin");
  Util.mkdir_p bin_dir;
  Util.write_file (Filename.concat package_root "package.json") {|{"name":"symphony-orchestrator"}|};
  let launcher_target = Filename.concat package_root "bin/symphony.js" in
  Util.write_file launcher_target "#!/usr/bin/env node\n";
  Unix.chmod launcher_target 0o755;
  let launcher = Filename.concat bin_dir "symphony" in
  Unix.symlink launcher_target launcher;
  (prefix, launcher, launcher_target)

let test_update_detects_npm_install_prefix () =
  with_temp_dir "symphony-update-prefix-" (fun root ->
      let prefix, launcher, launcher_target = make_fake_npm_install root in
      match Update_cli.detect_install_shape ~launcher_path:launcher with
      | Update_cli.Npm_package shape ->
          Alcotest.(check string) "launcher realpath" (Unix.realpath launcher_target) shape.launcher_path;
          Alcotest.(check string) "install prefix" (Unix.realpath prefix) (Unix.realpath shape.install_prefix)
      | Update_cli.Source_checkout path -> Alcotest.fail ("unexpected source checkout: " ^ path)
      | Update_cli.Unsupported reason -> Alcotest.fail reason)

let test_update_detects_prefix_from_package_launcher () =
  with_temp_dir "symphony-update-package-launcher-" (fun root ->
      let prefix, _, launcher_target = make_fake_npm_install root in
      match Update_cli.detect_install_shape ~launcher_path:launcher_target with
      | Update_cli.Npm_package shape ->
          Alcotest.(check string) "launcher realpath" (Unix.realpath launcher_target) shape.launcher_path;
          Alcotest.(check string) "install prefix" (Unix.realpath prefix) (Unix.realpath shape.install_prefix)
      | Update_cli.Source_checkout path -> Alcotest.fail ("unexpected source checkout: " ^ path)
      | Update_cli.Unsupported reason -> Alcotest.fail reason)

let test_update_rejects_source_checkout_launcher () =
  with_temp_dir "symphony-update-source-" (fun root ->
      Util.write_file (Filename.concat root "dune-project") "(lang dune 3.0)\n";
      Util.mkdir_p (Filename.concat root "bin");
      let launcher = Filename.concat root "bin/symphony.js" in
      Util.write_file launcher "#!/usr/bin/env node\n";
      Unix.chmod launcher 0o755;
      match Update_cli.detect_install_shape ~launcher_path:launcher with
      | Update_cli.Source_checkout source_root -> Alcotest.(check string) "source root" (Unix.realpath root) source_root
      | Update_cli.Npm_package _ -> Alcotest.fail "source checkout must not be treated as npm install"
      | Update_cli.Unsupported reason -> Alcotest.fail reason)

let test_update_prefers_launcher_env () =
  let original = Sys.getenv_opt "SYMPHONY_LAUNCHER_PATH" in
  Fun.protect
    ~finally:(fun () ->
      match original with
      | Some value -> Unix.putenv "SYMPHONY_LAUNCHER_PATH" value
      | None -> Unix.putenv "SYMPHONY_LAUNCHER_PATH" "")
    (fun () ->
      Unix.putenv "SYMPHONY_LAUNCHER_PATH" "/tmp/current-symphony";
      match Update_cli.find_callable () with
      | Ok path -> Alcotest.(check string) "launcher env" "/tmp/current-symphony" path
      | Error error -> Alcotest.fail error)

let test_update_noninteractive_requires_yes_before_install () =
  with_temp_dir "symphony-update-noninteractive-" (fun root ->
      let _, launcher, _ = make_fake_npm_install root in
      let commands = ref [] in
      let runner command =
        commands := command :: !commands;
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 0; output = {|"0.2.0"|} }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:false ()
      in
      Alcotest.(check int) "exit code" 1 code;
      Alcotest.(check (list string)) "only discovers latest"
        [ "npm view symphony-orchestrator version --json" ]
        (List.rev !commands))

let test_update_already_current_does_not_require_yes () =
  with_temp_dir "symphony-update-current-" (fun root ->
      let _, launcher, _ = make_fake_npm_install root in
      let commands = ref [] in
      let runner command =
        commands := command :: !commands;
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 0; output = {|"0.1.1"|} }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:false ()
      in
      Alcotest.(check int) "exit code" 0 code;
      Alcotest.(check (list string)) "only discovers latest"
        [ "npm view symphony-orchestrator version --json" ]
        (List.rev !commands))

let test_update_discovery_failure_does_not_install () =
  with_temp_dir "symphony-update-discovery-" (fun root ->
      let _, launcher, _ = make_fake_npm_install root in
      let commands = ref [] in
      let runner command =
        commands := command :: !commands;
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 1; output = "offline" }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:true ()
      in
      Alcotest.(check int) "exit code" 1 code;
      Alcotest.(check (list string)) "only discovers latest"
        [ "npm view symphony-orchestrator version --json" ]
        (List.rev !commands))

let test_update_installs_and_validates_with_yes () =
  with_temp_dir "symphony-update-yes-" (fun root ->
      let prefix, launcher, launcher_target = make_fake_npm_install root in
      let launcher_real = Unix.realpath launcher_target in
      let commands = ref [] in
      let runner command =
        commands := command :: !commands;
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 0; output = {|"0.2.0"|} }
        else if
          command
          = Printf.sprintf "npm install -g symphony-orchestrator@0.2.0 --prefix %s" (Util.shell_quote prefix)
        then { Update_cli.code = 0; output = "installed" }
        else if command = "command -v symphony" then { Update_cli.code = 0; output = launcher }
        else if command = Printf.sprintf "%s --version" (Util.shell_quote launcher_real) then
          { Update_cli.code = 0; output = "0.2.0" }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:true ()
      in
      Alcotest.(check int) "exit code" 0 code;
      Alcotest.(check int) "command count" 4 (List.length !commands))

let test_update_install_failure_does_not_validate () =
  with_temp_dir "symphony-update-install-failure-" (fun root ->
      let prefix, launcher, _ = make_fake_npm_install root in
      let commands = ref [] in
      let runner command =
        commands := command :: !commands;
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 0; output = {|"0.2.0"|} }
        else if
          command
          = Printf.sprintf "npm install -g symphony-orchestrator@0.2.0 --prefix %s" (Util.shell_quote prefix)
        then { Update_cli.code = 1; output = "EACCES" }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:true ()
      in
      Alcotest.(check int) "exit code" 1 code;
      Alcotest.(check int) "discovery and install only" 2 (List.length !commands))

let test_update_validation_failure_is_not_success () =
  with_temp_dir "symphony-update-validation-" (fun root ->
      let prefix, launcher, launcher_target = make_fake_npm_install root in
      let launcher_real = Unix.realpath launcher_target in
      let runner command =
        if command = "npm view symphony-orchestrator version --json" then { Update_cli.code = 0; output = {|"0.2.0"|} }
        else if
          command
          = Printf.sprintf "npm install -g symphony-orchestrator@0.2.0 --prefix %s" (Util.shell_quote prefix)
        then { Update_cli.code = 0; output = "installed" }
        else if command = "command -v symphony" then { Update_cli.code = 0; output = launcher }
        else if command = Printf.sprintf "%s --version" (Util.shell_quote launcher_real) then
          { Update_cli.code = 0; output = "0.1.1" }
        else Alcotest.fail ("unexpected command: " ^ command)
      in
      let code =
        Update_cli.run ~runner ~find_callable:(fun () -> Ok launcher) ~is_tty:(fun () -> false) ~current_version:"0.1.1"
          ~yes:true ()
      in
      Alcotest.(check int) "exit code" 1 code)

let test_runtime_state_exposes_running_issue_details () =
  let issue =
    {
      (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Add dashboard issue list" ~state:"In progress") with
      description = Some "Show the status, title, and a concise description for each running issue.";
      url = Some "https://example.test/issues/1";
    }
  in
  let state =
    {
      (Runtime_state.empty ()) with
      issues = [ issue ];
      running =
        [
          {
            Runtime_state.issue;
            stage_agent = None;
            stage_states = [];
            session_id = Some "pid:123";
            turn_count = 0;
            last_event = Some "launched";
            last_message = None;
            started_at = "2026-05-04T00:00:00Z";
            last_event_at = None;
            tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
            goal_usage = None;
          };
        ];
    }
  in
  let open Yojson.Safe.Util in
  let row = Runtime_state.to_yojson state |> member "running" |> to_list |> List.hd in
  Alcotest.(check string) "identifier" "#1" (row |> member "issue_identifier" |> to_string);
  Alcotest.(check string) "state" "In progress" (row |> member "state" |> to_string);
  Alcotest.(check string) "title" "Add dashboard issue list" (row |> member "title" |> to_string);
  Alcotest.(check string) "description" "Show the status, title, and a concise description for each running issue."
    (row |> member "description" |> to_string);
  let issue_row = Runtime_state.to_yojson state |> member "issues" |> to_list |> List.hd in
  Alcotest.(check string) "issue snapshot status" "In progress" (issue_row |> member "state" |> to_string);
  let ordered_state = Runtime_state.empty ~status_order:[ "Todo"; "In progress"; "In review"; "Done" ] () in
  Alcotest.(check (list string)) "status order"
    [ "Todo"; "In progress"; "In review"; "Done" ]
    (Runtime_state.to_yojson ordered_state |> member "status_order" |> to_list |> List.map to_string)

let test_ordered_queue_parses_cli_identifiers () =
  match Ordered_queue.parse "19,#22,31" with
  | Error _ -> Alcotest.fail "expected ordered queue parse success"
  | Ok queue ->
      Alcotest.(check (list int)) "numbers" [ 19; 22; 31 ] (Ordered_queue.numbers queue);
      Alcotest.(check (list string)) "identifiers" [ "#19"; "#22"; "#31" ] (Ordered_queue.identifiers queue);
      (match Ordered_queue.parse "19,,abc,#19" with
      | Ok _ -> Alcotest.fail "expected ordered queue parse problems"
      | Error problems ->
          Alcotest.(check int) "problem count" 3 (List.length problems);
          Alcotest.(check string) "duplicate" "duplicate issue identifier" (List.hd (List.rev problems)).Ordered_queue.reason)

let test_runtime_state_exposes_ordered_queue () =
  let queue =
    {
      Runtime_state.entries =
        [
          { Runtime_state.issue_identifier = "#1"; title = Some "One"; state = "running"; skip_reason = None };
          {
            Runtime_state.issue_identifier = "#2";
            title = Some "Two";
            state = "skipped";
            skip_reason = Some "Issue is no longer in a dispatchable project state.";
          };
        ];
    }
  in
  let open Yojson.Safe.Util in
  let json = Runtime_state.empty ~ordered_queue:queue () |> Runtime_state.to_yojson in
  let entries = json |> member "ordered_queue" |> member "entries" |> to_list in
  Alcotest.(check int) "entry count" 2 (List.length entries);
  Alcotest.(check string) "first state" "running" (List.hd entries |> member "state" |> to_string);
  Alcotest.(check string) "skip reason" "Issue is no longer in a dispatchable project state."
    (List.nth entries 1 |> member "skip_reason" |> to_string)

let test_orchestrator_resumes_same_ordered_queue_state () =
  with_temp_dir "symphony-queue-resume-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let persisted =
        {
          Runtime_state.entries =
            [
              { Runtime_state.issue_identifier = "#2"; title = Some "Two"; state = "completed"; skip_reason = None };
              { Runtime_state.issue_identifier = "#1"; title = Some "One"; state = "pending"; skip_reason = None };
            ];
        }
      in
      let path = Orchestrator.ordered_queue_state_path config in
      Util.mkdir_p (Filename.dirname path);
      Util.write_file path (Runtime_state.ordered_queue_to_yojson persisted |> Yojson.Safe.to_string);
      let same_queue =
        match Ordered_queue.parse "#2,#1" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let same = Orchestrator.make ~ordered_queue:same_queue ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      (match (Orchestrator.get_state same).Runtime_state.ordered_queue with
      | Some queue ->
          Alcotest.(check (list string)) "resumed states" [ "completed"; "pending" ]
            (List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state) queue.entries)
      | None -> Alcotest.fail "expected resumed ordered queue");
      let different_queue =
        match Ordered_queue.parse "#1,#2" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let different =
        Orchestrator.make ~ordered_queue:different_queue ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      match (Orchestrator.get_state different).Runtime_state.ordered_queue with
      | Some queue ->
          Alcotest.(check (list string)) "different queue resets" [ "pending"; "pending" ]
            (List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state) queue.entries)
      | None -> Alcotest.fail "expected new ordered queue")

let test_runtime_state_exposes_goal_usage_when_available () =
  let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Add goal usage" ~state:"In progress" in
  let state =
    {
      (Runtime_state.empty ()) with
      running =
        [
          {
            Runtime_state.issue;
            stage_agent = None;
            stage_states = [];
            session_id = Some "pid:123";
            turn_count = 0;
            last_event = Some "agent_output";
            last_message = Some "stdout/stderr updated";
            started_at = "2026-05-04T00:00:00Z";
            last_event_at = Some "2026-05-04T00:00:05Z";
            tokens = { input_tokens = 1; output_tokens = 2; total_tokens = 3 };
            goal_usage = Some { Runtime_state.status = Some "complete"; time_used_seconds = Some 5.; tokens_used = Some 99 };
          };
        ];
    }
  in
  let open Yojson.Safe.Util in
  let usage = Runtime_state.to_yojson state |> member "running" |> to_list |> List.hd |> member "goal_usage" in
  Alcotest.(check string) "goal status" "complete" (usage |> member "status" |> to_string);
  Alcotest.(check (float 0.01)) "goal time" 5. (usage |> member "time_used_seconds" |> to_float);
  Alcotest.(check int) "goal tokens" 99 (usage |> member "tokens_used" |> to_int);
  let retrying_state =
    {
      (Runtime_state.empty ()) with
      retrying =
        [
          {
            Runtime_state.issue_id = "I1";
            issue_identifier = "#1";
            attempt = 1;
            due_at = "2026-05-04T00:01:00Z";
            error = Some "agent exited with code 1";
            goal_usage = Some { Runtime_state.status = Some "active"; time_used_seconds = None; tokens_used = Some 42 };
          };
        ];
      issue_errors =
        [
          {
            Runtime_state.issue_id = "I2";
            issue_identifier = "#2";
            error = "commit required but agent produced no code changes";
            goal_usage = Some { Runtime_state.status = Some "blocked"; time_used_seconds = Some 2.; tokens_used = None };
          };
        ];
    }
  in
  let retry_usage = Runtime_state.to_yojson retrying_state |> member "retrying" |> to_list |> List.hd |> member "goal_usage" in
  Alcotest.(check string) "retry goal status" "active" (retry_usage |> member "status" |> to_string);
  Alcotest.(check int) "retry goal tokens" 42 (retry_usage |> member "tokens_used" |> to_int);
  let error_usage =
    Runtime_state.to_yojson retrying_state |> member "issue_errors" |> to_list |> List.hd |> member "goal_usage"
  in
  Alcotest.(check string) "error goal status" "blocked" (error_usage |> member "status" |> to_string);
  Alcotest.(check (float 0.01)) "error goal time" 2. (error_usage |> member "time_used_seconds" |> to_float)

let websocket_request () =
  {
    Server.request_line = "GET /api/v1/state/live HTTP/1.1";
    path = "/api/v1/state/live";
    headers =
      [
        ("host", "127.0.0.1");
        ("upgrade", "websocket");
        ("connection", "Upgrade");
        ("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==");
        ("sec-websocket-version", "13");
      ];
  }

let read_exact fd length =
  let bytes = Bytes.create length in
  let rec loop offset =
    if offset < length then
      let read = Unix.read fd bytes offset (length - offset) in
      if read = 0 then Alcotest.fail "unexpected EOF while reading websocket frame" else loop (offset + read)
  in
  loop 0;
  Bytes.unsafe_to_string bytes

let read_websocket_text_frame fd =
  let header = read_exact fd 2 in
  Alcotest.(check int) "text frame opcode" 0x81 (Char.code header.[0]);
  let len_code = Char.code header.[1] land 0x7f in
  let length =
    if len_code < 126 then len_code
    else if len_code = 126 then
      let extended = read_exact fd 2 in
      (Char.code extended.[0] lsl 8) lor Char.code extended.[1]
    else Alcotest.fail "test frames should not need 64-bit lengths"
  in
  read_exact fd length

let read_http_upgrade fd =
  let buffer = Buffer.create 256 in
  let rec loop recent =
    let next = read_exact fd 1 in
    Buffer.add_string buffer next;
    let recent = recent ^ next in
    let recent =
      if String.length recent > 4 then String.sub recent (String.length recent - 4) 4 else recent
    in
    if recent <> "\r\n\r\n" then loop recent
  in
  loop "";
  let response = Buffer.contents buffer in
  Alcotest.(check bool) "switching protocols" true (String.contains response '1');
  response

let with_websocket_client state f =
  let current_state = ref state in
  let live = Server.create_live_state ~get_state:(fun () -> !current_state) in
  let server_fd, client_fd = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  let server_oc = Unix.out_channel_of_descr server_fd in
  let thread =
    Thread.create
      (fun () ->
        Fun.protect
          ~finally:(fun () -> close_out_noerr server_oc)
          (fun () -> Server.handle_websocket live server_fd server_oc (websocket_request ())))
      ()
  in
  Fun.protect
    ~finally:(fun () ->
      Unix.close client_fd;
      ignore (Thread.join thread))
    (fun () ->
      let _upgrade = read_http_upgrade client_fd in
      let initial = read_websocket_text_frame client_fd in
      f ~set_state:(fun state -> current_state := state) ~live ~client_fd ~initial)

let test_websocket_accept_and_initial_snapshot () =
  Alcotest.(check string) "RFC accept key" "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    (Server.websocket_accept "dGhlIHNhbXBsZSBub25jZQ==");
  let state =
    {
      (Runtime_state.empty ()) with
      issues = [ Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Live state" ~state:"Todo" ];
    }
  in
  with_websocket_client state (fun ~set_state:_ ~live:_ ~client_fd:_ ~initial ->
      let open Yojson.Safe.Util in
      let json = Yojson.Safe.from_string initial in
      Alcotest.(check string) "initial issue" "#1" (json |> member "issues" |> to_list |> List.hd |> member "issue_identifier" |> to_string))

let test_websocket_broadcast_after_state_change () =
  let state = Runtime_state.empty () in
  with_websocket_client state (fun ~set_state ~live ~client_fd ~initial:_ ->
      set_state
        {
          state with
          running =
            [
              {
                Runtime_state.issue = Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Running" ~state:"In progress";
                stage_agent = None;
                stage_states = [];
                session_id = Some "pid:2";
                turn_count = 0;
                last_event = Some "started";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      Server.broadcast_live_state live;
      let open Yojson.Safe.Util in
      let json = read_websocket_text_frame client_fd |> Yojson.Safe.from_string in
      Alcotest.(check int) "running count" 1 (json |> member "counts" |> member "running" |> to_int))

let test_websocket_readiness_snapshot_and_http_state () =
  let state =
    Runtime_state.empty
      ~readiness_gaps:[ { Runtime_state.requirement = "tracker.owner"; remediation = "set tracker owner" } ]
      ~last_error:"tracker.owner: set tracker owner" ()
  in
  with_websocket_client state (fun ~set_state:_ ~live:_ ~client_fd:_ ~initial ->
      let open Yojson.Safe.Util in
      let json = Yojson.Safe.from_string initial in
      Alcotest.(check string) "readiness requirement" "tracker.owner"
        (json |> member "readiness_gaps" |> to_list |> List.hd |> member "requirement" |> to_string));
  let http =
    Server.handle_request (fun () -> state)
      { Server.request_line = "GET /api/v1/state HTTP/1.1"; path = "/api/v1/state"; headers = [] }
  in
  Alcotest.(check bool) "diagnostic endpoint preserved" true (String.contains http '{')

let test_orchestrator_notifies_each_state_mutation () =
  with_temp_dir "symphony-notify-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let notifications = ref 0 in
      let fetch _ = [] in
      let orchestrator =
        Orchestrator.make ~fetch ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun _ -> incr notifications)
          ()
      in
      Orchestrator.poll_once orchestrator;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "notifies repeated state writes" 2 !notifications)

let test_orchestrator_parses_final_output_when_size_was_already_seen () =
  with_temp_dir "symphony-final-output-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Fast output" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:(Filename.concat root "workspaces") issue.identifier in
      let stdout_path = Filename.concat workspace.path "stdout.log" in
      Util.write_file stdout_path
        {|input_tokens: 11
output_tokens: 13
total_tokens: 24
Goal Usage: {"status":"complete","time_used_seconds":1.5,"tokens_used":24}
|};
      let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "true" |] Unix.stdin Unix.stdout Unix.stderr in
      Unix.sleepf 0.05;
      let snapshots = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun state -> snapshots := state :: !snapshots)
          ()
      in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                stage_agent = None;
                stage_states = [];
                session_id = Some "pid:test";
                turn_count = 0;
                last_event = Some "launched";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      orchestrator.Orchestrator.children <-
        [
          {
            Orchestrator.pid;
            issue;
            stage = None;
            issue_id = issue.id;
            issue_identifier = issue.identifier;
            issue_title = issue.title;
            workspace;
            started_at = Unix.time ();
            last_output_at = Unix.time ();
            stdout_path = Some stdout_path;
            stderr_path = None;
            stdout_size = (Unix.stat stdout_path).Unix.st_size;
            stderr_size = 0;
          };
        ];
      Orchestrator.reap_children orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "final total tokens parsed" 24 state.codex_totals.total_tokens;
      Alcotest.(check int) "completed row removed" 0 (List.length state.running);
      let saw_goal_usage =
        List.exists
          (fun (state : Runtime_state.t) ->
            List.exists
              (fun (row : Runtime_state.running) ->
                match row.goal_usage with
                | Some usage -> usage.status = Some "complete" && usage.tokens_used = Some 24
                | None -> false)
              state.running)
          !snapshots
      in
      Alcotest.(check bool) "goal usage was exposed before completion" true saw_goal_usage)

let test_orchestrator_parses_final_output_before_timeout_retry () =
  with_temp_dir "symphony-timeout-output-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1; read_timeout_ms = 1000; stall_timeout_ms = 100000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Timeout output" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:(Filename.concat root "workspaces") issue.identifier in
      let stdout_path = Filename.concat workspace.path "stdout.log" in
      Util.write_file stdout_path
        {|input_tokens: 3
output_tokens: 5
total_tokens: 8
Goal Usage: {"status":"active","time_used_seconds":9,"tokens_used":8}
|};
      let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "sleep 30" |] Unix.stdin Unix.stdout Unix.stderr in
      let snapshots = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun state -> snapshots := state :: !snapshots)
          ()
      in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                stage_agent = None;
                stage_states = [];
                session_id = Some "pid:timeout";
                turn_count = 0;
                last_event = Some "launched";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      orchestrator.Orchestrator.children <-
        [
          {
            Orchestrator.pid;
            issue;
            stage = None;
            issue_id = issue.id;
            issue_identifier = issue.identifier;
            issue_title = issue.title;
            workspace;
            started_at = Unix.time () -. 10.;
            last_output_at = Unix.time ();
            stdout_path = Some stdout_path;
            stderr_path = None;
            stdout_size = (Unix.stat stdout_path).Unix.st_size;
            stderr_size = 0;
          };
        ];
      Orchestrator.reap_children orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "timeout total tokens parsed" 8 state.codex_totals.total_tokens;
      Alcotest.(check int) "running removed" 0 (List.length state.running);
      Alcotest.(check int) "retrying added" 1 (List.length state.retrying);
      (match state.retrying with
      | retry :: _ -> (
          match retry.goal_usage with
          | Some usage ->
              Alcotest.(check (option string)) "retry goal status preserved" (Some "active") usage.status;
              Alcotest.(check (option int)) "retry goal tokens preserved" (Some 8) usage.tokens_used
          | None -> Alcotest.fail "expected retry goal usage")
      | [] -> Alcotest.fail "expected retrying row");
      let saw_goal_usage =
        List.exists
          (fun (state : Runtime_state.t) ->
            List.exists
              (fun (row : Runtime_state.running) ->
                match row.goal_usage with
                | Some usage -> usage.status = Some "active" && usage.tokens_used = Some 8
                | None -> false)
              state.running)
          !snapshots
      in
      Alcotest.(check bool) "timeout goal usage exposed before retry" true saw_goal_usage)

let test_orchestrator_preserves_goal_usage_on_blocked_issue_error () =
  with_temp_dir "symphony-blocked-goal-usage-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Blocked usage" ~state:"Todo" in
      let orchestrator = Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                stage_agent = None;
                stage_states = [];
                session_id = Some "pid:block";
                turn_count = 0;
                last_event = Some "agent_output";
                last_message = Some "stdout/stderr updated";
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = Some "2026-05-04T00:00:10Z";
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = Some { Runtime_state.status = Some "blocked"; time_used_seconds = Some 10.; tokens_used = Some 77 };
              };
            ];
        };
      Orchestrator.mark_blocked orchestrator issue.id "commit required but agent produced no code changes";
      match (Orchestrator.get_state orchestrator).issue_errors with
      | issue_error :: _ -> (
          match issue_error.goal_usage with
          | Some usage ->
              Alcotest.(check (option string)) "blocked goal status" (Some "blocked") usage.status;
              Alcotest.(check (option int)) "blocked goal tokens" (Some 77) usage.tokens_used
          | None -> Alcotest.fail "expected blocked goal usage")
      | [] -> Alcotest.fail "expected issue error")

let test_ready_terminal_mode_runs_orchestrator () =
  Alcotest.(check bool) "ready terminal loops" true
    (Runtime_policy.action ~mode:Cli_mode.Terminal_console ~readiness_gaps:[] = Runtime_policy.Run_orchestrator);
  Alcotest.(check bool) "gapped terminal serves readiness state" true
    (Runtime_policy.action ~mode:Cli_mode.Terminal_console
       ~readiness_gaps:[ { Runtime_state.requirement = "tracker.owner"; remediation = "set owner" } ]
    = Runtime_policy.Serve_readiness_state)

let test_github_project_field_parsing () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo"; "In Progress" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node =
    Yojson.Safe.from_string
      {|{
  "id": "I_1",
  "number": 42,
  "title": "Fix parser",
  "body": "Body",
  "url": "https://github.example/acme/widgets/issues/42",
  "createdAt": "2026-01-01T00:00:00Z",
  "updatedAt": "2026-01-02T00:00:00Z",
  "comments": { "nodes": [
    {
      "body": "Needs the project comments in prompt.md",
      "createdAt": "2026-05-06T18:00:00Z",
      "url": "https://github.example/acme/widgets/issues/42#issuecomment-1",
      "author": { "login": "matheus" }
    }
  ] },
  "labels": { "nodes": [{ "name": "Bug" }] },
  "projectItems": {
    "nodes": [
      {
        "project": { "number": 99 },
        "fieldValues": { "nodes": [{ "name": "Done", "field": { "name": "Status" } }] }
      },
      {
        "project": { "number": 7 },
        "fieldValues": { "nodes": [{ "name": "In Progress", "field": { "name": "Status" } }] }
      }
    ]
  }
}|}
  in
  match Github_tracker.issue_from_project_node ~config node with
  | None -> Alcotest.fail "expected active issue from matching project"
  | Some issue ->
      Alcotest.(check string) "identifier" "#42" issue.identifier;
      Alcotest.(check string) "status" "In Progress" issue.state;
      Alcotest.(check int) "comment count" 1 (List.length issue.comments);
      Alcotest.(check string) "comment body" "Needs the project comments in prompt.md" (List.hd issue.comments).body;
      Alcotest.(check (list string)) "labels lowercased" [ "bug" ] issue.labels

let test_github_active_state_filtering () =
  let base_config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node ?(issue_state = "OPEN") status =
    Yojson.Safe.from_string
      (Printf.sprintf
         {|{
  "id": "I_1",
  "number": 42,
  "state": %S,
  "title": "Fix parser",
  "labels": { "nodes": [] },
  "projectItems": { "nodes": [
    { "project": { "number": 7 }, "fieldValues": { "nodes": [
      { "name": %S, "field": { "name": "Status" } }
    ] } }
  ] }
}|}
         issue_state status)
  in
  Alcotest.(check bool) "todo included" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node "Todo")));
  Alcotest.(check bool) "done visible" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node "Done")));
  Alcotest.(check bool) "closed done visible" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node ~issue_state:"CLOSED" "Done")));
  Alcotest.(check bool) "closed active issue excluded" true
    (Option.is_none (Github_tracker.issue_from_project_node ~config:base_config (node ~issue_state:"CLOSED" "Todo")));
  Alcotest.(check bool) "unconfigured status excluded" true
    (Option.is_none (Github_tracker.issue_from_project_node ~config:base_config (node "In review")));
  Alcotest.(check bool) "missing project excluded" true
    (Option.is_none
       (Github_tracker.issue_from_project_node
          ~config:{ base_config with Config.project_number = 99 }
          (node "Todo")))

let test_github_empty_project_field_values_are_ignored () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 2;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "To-Do" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node =
    Yojson.Safe.from_string
      {|{
  "id": "I_2",
  "number": 2,
  "title": "Replicate pi-agent IPC",
  "labels": { "nodes": [] },
  "projectItems": { "nodes": [
    { "project": { "number": 2 }, "fieldValues": { "nodes": [
      {},
      {},
      { "name": "To-Do", "field": { "name": "Status" } }
    ] } }
  ] }
}|}
  in
  match Github_tracker.issue_from_project_node ~config node with
  | None -> Alcotest.fail "expected empty field value placeholders to be ignored"
  | Some issue -> Alcotest.(check string) "status" "To-Do" issue.state

let test_github_status_metadata_parsing () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 2;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let json =
    Yojson.Safe.from_string
      {|{
  "data": {
    "repositoryOwner": {
      "projectV2": {
        "id": "PVT_1",
        "fields": { "nodes": [
          {},
          { "id": "PVTSSF_status", "name": "Status", "options": [
            { "id": "todo", "name": "Todo", "color": "GRAY", "description": "" },
            { "id": "doing", "name": "In Progress", "color": "YELLOW", "description": "" }
          ] }
        ] }
      }
    },
    "node": {
      "projectItems": { "nodes": [
        { "id": "PVTI_other", "project": { "number": 1 } },
        { "id": "PVTI_item", "project": { "number": 2 } }
      ] }
    }
  }
}|}
  in
  match Github_tracker.status_metadata_from_json ~config json with
  | Error error -> Alcotest.fail error
  | Ok metadata ->
      Alcotest.(check string) "project id" "PVT_1" metadata.project_id;
      Alcotest.(check string) "item id" "PVTI_item" metadata.item_id;
      Alcotest.(check string) "field id" "PVTSSF_status" metadata.field_id;
      Alcotest.(check int) "options" 2 (List.length metadata.options)

let test_github_api_error_normalization () =
  let graphql_json =
    Yojson.Safe.from_string
      {|{
  "errors": [
    { "message": "Could not resolve to a Repository" },
    { "message": "GitHub API rate limit exceeded for user ID 29718530." }
  ]
}|}
  in
  let rest_json =
    Yojson.Safe.from_string
      {|{ "message": "API rate limit exceeded for user ID 29718530." }|}
  in
  let graphql_messages = Github_tracker.github_api_error_messages graphql_json in
  let rest_messages = Github_tracker.github_api_error_messages rest_json in
  Alcotest.(check (list string)) "graphql errors"
    [ "Could not resolve to a Repository"; "GitHub API rate limit exceeded for user ID 29718530." ]
    graphql_messages;
  Alcotest.(check (list string)) "top-level message" [ "API rate limit exceeded for user ID 29718530." ] rest_messages;
  Alcotest.(check bool) "rate remediation"
    true
    (String.starts_with ~prefix:"GitHub API rate limit exceeded."
       (Github_tracker.github_api_error_remediation rest_messages))

let stage_capacity_config root ~global_cap =
  {
    Config.workflow_path = "settings.json";
    repository_root = root;
    tracker =
      {
        kind = "github";
        owner = "acme";
        repo = "widgets";
        project_number = 7;
        api_key_env = "GITHUB_TOKEN";
        api_key = Some "token";
        active_states = [ "Backlog"; "Todo"; "In progress"; "In review" ];
        terminal_states = [ "Done"; "Human attention" ];
        project_status_field = "Status";
        project_status_on_dispatch = Some "In progress";
        project_status_on_success = Some "Done";
        project_status_on_retry = Some "Todo";
        ensure_project_statuses = true;
      };
    polling = { interval_ms = 1000 };
    workspace = { root = Filename.concat root "workspaces" };
    git = Config.default_git;
    agent = { max_concurrent_agents = global_cap; max_turns = 10; max_retry_backoff_ms = 1000 };
    codex =
      {
        command = "cat";
        model = Config.default_model;
        reasoning_effort = Config.default_reasoning_effort;
        turn_timeout_ms = 1000;
        read_timeout_ms = 1000;
        stall_timeout_ms = 1000;
      };
    server = { port = None };
    pull_request = Config.default_pull_request;
    protected_paths = Config.default_protected_paths;
    stage_agents =
      {
        enabled = true;
        root = Filename.concat root "agents";
        default_agent = None;
        stages =
          [
            {
              Config.states = [ "Backlog" ];
              agent = "planner";
              max_concurrent_agents = Some 1;
                    context_snapshot = None;
              skills = [];
              start_status = None;
              success_status = Some "Todo";
              retry_status = Some "Backlog";
              goal = None;
              commit = None;
            };
            {
              Config.states = [ "Todo"; "In progress" ];
              agent = "engineer";
              max_concurrent_agents = Some 2;
                    context_snapshot = None;
              skills = [];
              start_status = Some "In progress";
              success_status = Some "In review";
              retry_status = Some "Todo";
              goal = None;
              commit = None;
            };
            {
              Config.states = [ "In review" ];
              agent = "reviewer";
              max_concurrent_agents = Some 2;
                    context_snapshot = None;
              skills = [];
              start_status = None;
              success_status = Some "Done";
              retry_status = Some "In progress";
              goal = None;
              commit = None;
            };
          ];
      };
  }

let test_orchestrator_dispatch_limits () =
  with_temp_dir "symphony-orchestrator-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Two" ~state:"Todo";
          Issue.empty ~id:"I3" ~identifier:"#3" ~title:"Three" ~state:"Todo";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.id :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = issues in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "running limited" 2 (List.length state.Runtime_state.running);
      Alcotest.(check int) "launch count limited" 2 (List.length !launched);
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "still capped" 2 (List.length state.Runtime_state.running))

let test_orchestrator_stage_capacity_dispatches_all_available_slots () =
  with_temp_dir "symphony-orchestrator-stage-slots-" (fun root ->
      let config = stage_capacity_config root ~global_cap:5 in
      let issues =
        [
          Issue.empty ~id:"P1" ~identifier:"#1" ~title:"Plan one" ~state:"Backlog";
          Issue.empty ~id:"E1" ~identifier:"#2" ~title:"Engineer one" ~state:"Todo";
          Issue.empty ~id:"E2" ~identifier:"#3" ~title:"Engineer two" ~state:"In progress";
          Issue.empty ~id:"R1" ~identifier:"#4" ~title:"Review one" ~state:"In review";
          Issue.empty ~id:"R2" ~identifier:"#5" ~title:"Review two" ~state:"In review";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.identifier :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "all configured slots used" 5 (List.length state.Runtime_state.running);
      Alcotest.(check (list string)) "launches across stages" [ "#1"; "#2"; "#3"; "#4"; "#5" ] (List.rev !launched))

let test_orchestrator_stage_capacity_does_not_spawn_idle_agents () =
  with_temp_dir "symphony-orchestrator-stage-idle-" (fun root ->
      let config = stage_capacity_config root ~global_cap:5 in
      let issues = [ Issue.empty ~id:"E1" ~identifier:"#1" ~title:"Engineer one" ~state:"Todo" ] in
      let launch_count = ref 0 in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launch_count;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "one issue launched" 1 !launch_count;
      Alcotest.(check int) "no idle running rows" 1 (List.length state.Runtime_state.running))

let test_orchestrator_stage_capacity_respects_lower_global_cap () =
  with_temp_dir "symphony-orchestrator-stage-global-cap-" (fun root ->
      let config = stage_capacity_config root ~global_cap:3 in
      let issues =
        [
          Issue.empty ~id:"P1" ~identifier:"#1" ~title:"Plan one" ~state:"Backlog";
          Issue.empty ~id:"E1" ~identifier:"#2" ~title:"Engineer one" ~state:"Todo";
          Issue.empty ~id:"E2" ~identifier:"#3" ~title:"Engineer two" ~state:"In progress";
          Issue.empty ~id:"R1" ~identifier:"#4" ~title:"Review one" ~state:"In review";
          Issue.empty ~id:"R2" ~identifier:"#5" ~title:"Review two" ~state:"In review";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.identifier :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "global cap wins" 3 (List.length state.Runtime_state.running);
      Alcotest.(check (list string)) "only first global slots launch" [ "#1"; "#2"; "#3" ] (List.rev !launched))

let test_orchestrator_stage_capacity_prevents_duplicate_dispatch () =
  with_temp_dir "symphony-orchestrator-stage-duplicates-" (fun root ->
      let config = stage_capacity_config root ~global_cap:5 in
      let issues =
        [
          Issue.empty ~id:"running" ~identifier:"#1" ~title:"Already running" ~state:"Todo";
          Issue.empty ~id:"retrying" ~identifier:"#2" ~title:"Retry later" ~state:"Todo";
          Issue.empty ~id:"blocked" ~identifier:"#3" ~title:"Blocked" ~state:"Todo";
          Issue.empty ~id:"attention" ~identifier:"#4" ~title:"Needs attention" ~state:"Human attention";
          Issue.empty ~id:"ready" ~identifier:"#5" ~title:"Ready" ~state:"Todo";
        ]
      in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      let running_issue = List.nth issues 0 in
      let retrying_issue = List.nth issues 1 in
      let blocked_issue = List.nth issues 2 in
      let ready_issue = List.nth issues 4 in
      let running_row issue =
        {
          Runtime_state.issue;
          stage_agent = Some "engineer";
          stage_states = [ "Todo"; "In progress" ];
          session_id = Some issue.Issue.id;
          turn_count = 0;
          last_event = Some "test";
          last_message = None;
          started_at = Util.now_iso8601 ();
          last_event_at = None;
          tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
          goal_usage = None;
        }
      in
      Orchestrator.update_state orchestrator (fun state ->
          {
            state with
            running = [ running_row running_issue; running_row retrying_issue; running_row blocked_issue ];
          });
      Orchestrator.mark_retrying orchestrator retrying_issue.id "retry later";
      Orchestrator.mark_blocked orchestrator blocked_issue.id "blocked";
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      let running_identifiers = List.map (fun (row : Runtime_state.running) -> row.issue.identifier) state.running in
      Alcotest.(check (list string)) "running and ready issues only" [ ready_issue.identifier; running_issue.identifier ]
        running_identifiers)

let test_orchestrator_stage_capacity_skips_full_ordered_stage () =
  with_temp_dir "symphony-orchestrator-stage-cap-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo"; "In progress"; "In review" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "Done";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 3; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex =
            {
              command = "cat";
              model = Config.default_model;
              reasoning_effort = Config.default_reasoning_effort;
              turn_timeout_ms = 1000;
              read_timeout_ms = 1000;
              stall_timeout_ms = 1000;
            };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    max_concurrent_agents = Some 1;
                    context_snapshot = None;
                    skills = [];
                    start_status = Some "In progress";
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = None;
                  };
                  {
                    Config.states = [ "In review" ];
                    agent = "reviewer";
                    max_concurrent_agents = Some 2;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "Done";
                    retry_status = Some "In progress";
                    goal = None;
                    commit = None;
                  };
                ];
            };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Todo one" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Todo two" ~state:"Todo";
          Issue.empty ~id:"I3" ~identifier:"#3" ~title:"Review one" ~state:"In review";
          Issue.empty ~id:"I4" ~identifier:"#4" ~title:"Review two" ~state:"In review";
        ]
      in
      let ordered_queue =
        match Ordered_queue.parse "#1,#2,#3,#4" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.identifier :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~ordered_queue ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "launch skips full todo stage" [ "#1"; "#3"; "#4" ] (List.rev !launched);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "global cap used by admissible stages" 3 (List.length state.Runtime_state.running);
      let todo_running =
        state.running
        |> List.filter (fun (row : Runtime_state.running) -> row.stage_agent = Some "engineer" && row.stage_states = [ "Todo" ])
        |> List.length
      in
      let review_running =
        state.running
        |> List.filter (fun (row : Runtime_state.running) -> row.stage_agent = Some "reviewer" && row.stage_states = [ "In review" ])
        |> List.length
      in
      Alcotest.(check int) "todo stage cap" 1 todo_running;
      Alcotest.(check int) "review stage cap" 2 review_running)

let test_orchestrator_dispatches_ordered_queue_only_in_order () =
  with_temp_dir "symphony-orchestrator-queue-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex =
            {
              command = "cat";
              model = Config.default_model;
              reasoning_effort = Config.default_reasoning_effort;
              turn_timeout_ms = 1000;
              read_timeout_ms = 1000;
              stall_timeout_ms = 1000;
            };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I3" ~identifier:"#3" ~title:"Three" ~state:"Todo";
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Two" ~state:"Todo";
        ]
      in
      let ordered_queue =
        match Ordered_queue.parse "#2,#1" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.identifier :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~ordered_queue ~launch ~fetch:(fun _ -> issues) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "launch order" [ "#2"; "#1" ] (List.rev !launched);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "only queued running" 2 (List.length state.Runtime_state.running);
      match state.Runtime_state.ordered_queue with
      | None -> Alcotest.fail "expected ordered queue state"
      | Some queue ->
          Alcotest.(check (list string)) "queue states" [ "running"; "running" ]
            (List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state) queue.entries))

let test_orchestrator_pauses_tracker_after_rate_limit () =
  with_temp_dir "symphony-orchestrator-rate-limit-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let calls = ref 0 in
      let fetch _ =
        incr calls;
        raise
          (Github_tracker.Tracker_rate_limited
             ("GitHub API rate limit exceeded. Original message: API rate limit exceeded for user ID 29718530.", 300000))
      in
      let orchestrator =
        Orchestrator.make ~fetch ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "fetch paused after rate limit" 1 !calls;
      match (Orchestrator.get_state orchestrator).last_error with
      | Some error ->
          Alcotest.(check bool) "pause message" true
            (String.starts_with ~prefix:"GitHub API rate limit exceeded; retrying tracker poll" error)
      | None -> Alcotest.fail "expected tracker pause error")

let test_orchestrator_does_not_dispatch_terminal_issues () =
  with_temp_dir "symphony-orchestrator-terminal-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "Done";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Two" ~state:"Done";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.id :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = issues in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "all board issues visible" 2 (List.length state.Runtime_state.issues);
      Alcotest.(check (list string)) "only active issue launched" [ "I1" ] (List.rev !launched))

let test_orchestrator_retries_failed_agent () =
  with_temp_dir "symphony-orchestrator-retry-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "false"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let fetch _ = [ issue ] in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "no longer running" 0 (List.length state.Runtime_state.running);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      match state.retrying with
      | retry :: _ ->
          Alcotest.(check string) "retry issue" "I1" retry.issue_id;
          Alcotest.(check int) "retry attempt" 1 retry.attempt
      | [] -> Alcotest.fail "expected retry row")

let test_orchestrator_moves_status_to_review_on_success () =
  with_temp_dir "symphony-orchestrator-status-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo"; "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let current_status = ref "Todo" in
      let fetch _ =
        if List.exists (fun status -> String.lowercase_ascii status = String.lowercase_ascii !current_status) config.tracker.active_states
        then [ { issue with state = !current_status } ]
        else []
      in
      let statuses = ref [] in
      let set_status _ issue status =
        current_status := status;
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list (pair string string))) "status transitions"
        [ ("#1", "In progress"); ("#1", "In review") ]
        (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "completed agent removed" 0 (List.length state.Runtime_state.running))

let test_orchestrator_uses_stage_agent_prompt_and_status () =
  with_temp_dir "symphony-stage-agent-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "reviewer.md") "Reviewer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In review" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In review" ];
                    agent = "reviewer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "Done";
                    retry_status = Some "In progress";
                    goal = None;
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In review" in
      let current_status = ref "In review" in
      let fetch _ = if !current_status = "In review" then [ { issue with state = !current_status } ] else [] in
      let statuses = ref [] in
      let captured_prompt = ref "" in
      let set_status _ issue status =
        current_status := status;
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }} {{ issue.title }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "reviewer prompt included" true (String.contains !captured_prompt 'R');
      Alcotest.(check bool) "base prompt included" true (String.contains !captured_prompt '#');
      Alcotest.(check (list (pair string string))) "no start status for review" [] (List.rev !statuses);
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list (pair string string))) "review moves done" [ ("#1", "Done") ] (List.rev !statuses))

let test_orchestrator_prepends_stage_goal_handoff () =
  with_temp_dir "symphony-stage-goal-prompt-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "engineer.md") "Engineer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = Some { enabled = true; max_output_bytes = 12000; validation_error = None };
                    skills = [ "to-prd"; "github:gh-fix-ci" ];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = Some { enabled = true };
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue =
        {
          (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo") with
          description = Some "Build the feature";
          comments =
            [
              {
                Issue.author = Some "reviewer";
                body = "Remember the edge case from the thread.";
                created_at = Some "2026-05-06T18:30:00Z";
                url = Some "https://example.test/issues/1#issuecomment-1";
              };
            ];
          url = Some "https://example.test/issues/1";
          labels = [ "enhancement"; "codex" ];
          priority = Some 2;
          blocked_by = [ { Issue.id = Some "I0"; identifier = Some "#0"; state = Some "Done" } ];
          created_at = Some "2026-01-01T00:00:00Z";
        }
      in
      let captured_prompt = ref "" in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator = Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Normal {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "goal command first" true (String.starts_with ~prefix:"/goal {\"kind\":\"Stage Goal Context\"" !captured_prompt);
      Alcotest.(check bool) "stage agent included" true (String.contains !captured_prompt 'E');
      Alcotest.(check bool) "normal prompt included" true (String.contains !captured_prompt '#');
      Alcotest.(check bool) "normal prompt includes comments" true
        (contains_substring !captured_prompt "Issue comments:\n\nreviewer at 2026-05-06T18:30:00Z:\nRemember the edge case from the thread.");
      Alcotest.(check bool) "skill load preserves order" true
        (contains_substring !captured_prompt "Stage Skill Load:\n$to-prd\n$github:gh-fix-ci");
      Alcotest.(check bool) "snapshot appended" true
        (contains_substring !captured_prompt "## Agent Context Snapshot\n\n- Issue: #1 One");
      Alcotest.(check bool) "snapshot includes branch" true
        (contains_substring !captured_prompt "- Task Branch: symphony/task-1");
      Alcotest.(check bool) "snapshot includes worktree" true
        (contains_substring !captured_prompt "- Agent Worktree:");
      Alcotest.(check bool) "snapshot includes loop-start" true
        (contains_substring !captured_prompt "- Loop-Start Branch:");
      Alcotest.(check bool) "handoff remains before prompt snapshot" true
        (String.starts_with ~prefix:"/goal " !captured_prompt
        && contains_substring !captured_prompt "---\n\nEngineer stage instructions");
      let goal_line =
        match String.split_on_char '\n' !captured_prompt with
        | first :: _ -> first
        | [] -> Alcotest.fail "expected prompt"
      in
      let goal_json = String.sub goal_line 6 (String.length goal_line - 6) |> Yojson.Safe.from_string in
      let open Yojson.Safe.Util in
      Alcotest.(check string) "goal kind" "Stage Goal Context" (goal_json |> member "kind" |> to_string);
      Alcotest.(check string) "goal issue" "#1" (goal_json |> member "issue_identifier" |> to_string);
      Alcotest.(check string) "goal description" "Build the feature" (goal_json |> member "description" |> to_string);
      Alcotest.(check string) "goal comment" "Remember the edge case from the thread."
        (goal_json |> member "comments" |> to_list |> List.hd |> member "body" |> to_string);
      Alcotest.(check (list string)) "goal labels" [ "enhancement"; "codex" ]
        (goal_json |> member "labels" |> to_list |> List.map to_string);
      Alcotest.(check int) "goal priority" 2 (goal_json |> member "priority" |> to_int);
      Alcotest.(check string) "goal blocker" "#0"
        (goal_json |> member "blocker_references" |> to_list |> List.hd |> member "identifier" |> to_string);
      Alcotest.(check bool) "created timestamp omitted" true
        (match goal_json |> member "created_at" with `Null -> true | _ -> false);
      Alcotest.(check bool) "updated timestamp omitted" true
        (match goal_json |> member "updated_at" with `Null -> true | _ -> false);
      Alcotest.(check bool) "skill load omitted from goal context" true
        (match goal_json |> member "skills" with `Null -> true | _ -> false))

let test_orchestrator_skips_stage_goal_when_disabled () =
  with_temp_dir "symphony-stage-goal-disabled-prompt-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "engineer.md") "Engineer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = Some { enabled = false };
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let captured_prompt = ref "" in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator = Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Normal {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "no goal command" false (String.starts_with ~prefix:"/goal" !captured_prompt);
      Alcotest.(check bool) "no context snapshot" false
        (contains_substring !captured_prompt "## Agent Context Snapshot");
      Alcotest.(check bool) "stage agent still included" true (String.contains !captured_prompt 'E');
      Alcotest.(check bool) "normal prompt still included" true (String.contains !captured_prompt '#'))

let test_orchestrator_truncates_agent_context_snapshot () =
  with_temp_dir "symphony-context-snapshot-truncated-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "engineer.md") "Engineer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = Some { enabled = true; max_output_bytes = 96; validation_error = None };
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue =
        {
          (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One with a very long deterministic title" ~state:"Todo") with
          labels = [ "enhancement"; "context"; "snapshot"; "bounded" ];
        }
      in
      let workspace = Workspace.create_for_issue ~root:config.workspace.root issue.identifier in
      let prompt =
        Orchestrator.compose_prompt ~stage:(List.hd config.stage_agents.stages) config issue (Some 2) "Normal #1" ~workspace
          ~loop_start_branch:(Some "symphony/dogfood")
      in
      let marker = "## Agent Context Snapshot" in
      let rec drop_until_marker = function
        | [] -> []
        | line :: _ as lines when line = marker -> lines
        | _ :: rest -> drop_until_marker rest
      in
      let snapshot =
        match String.split_on_char '\n' prompt |> drop_until_marker with
        | [] -> Alcotest.fail "expected snapshot"
        | lines -> String.concat "\n" lines
      in
      Alcotest.(check bool) "snapshot capped" true (String.length snapshot <= 96);
      Alcotest.(check bool) "snapshot truncation marker" true (contains_substring snapshot "[truncated]"))

let test_parse_goal_usage_from_codex_output () =
  with_temp_dir "symphony-goal-usage-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      Util.write_file stdout_path
        {|noise
Goal Usage: {"goal_usage":{"status":"complete","time_used_seconds":12.5,"tokens_used":345}}
|};
      match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "status" (Some "complete") usage.status;
          Alcotest.(check (option (float 0.01))) "time" (Some 12.5) usage.time_used_seconds;
          Alcotest.(check (option int)) "tokens" (Some 345) usage.tokens_used)

let test_parse_goal_usage_variants_and_ignores_invalid () =
  with_temp_dir "symphony-goal-usage-variants-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      let stderr_path = Filename.concat root "stderr.log" in
      Util.write_file stdout_path "Goal Usage: not json\n";
      Alcotest.(check bool) "invalid ignored" true (Option.is_none (Orchestrator.parse_goal_usage (Some stdout_path) None));
      Util.write_file stdout_path {|{"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      Alcotest.(check bool) "bare non-goal json ignored" true
        (Option.is_none (Orchestrator.parse_goal_usage (Some stdout_path) None));
      Util.write_file stdout_path {|Goal Usage: {"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      (match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected prefixed top-level goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "prefixed status" (Some "active") usage.status;
          Alcotest.(check (option int)) "prefixed tokens" (Some 44) usage.tokens_used);
      Util.write_file stderr_path {|goal usage: {"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      match Orchestrator.parse_goal_usage (Some stdout_path) (Some stderr_path) with
      | None -> Alcotest.fail "expected camel case goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "status" (Some "active") usage.status;
          Alcotest.(check (option (float 0.01))) "time" (Some 3.) usage.time_used_seconds;
          Alcotest.(check (option int)) "tokens" (Some 44) usage.tokens_used)

let test_parse_goal_usage_nested_usage_fields () =
  with_temp_dir "symphony-goal-usage-nested-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      Util.write_file stdout_path
        {|{"goalUsage":{"goalStatus":"complete","durationSeconds":7.25,"tokenUsage":{"totalTokens":88}}}|};
      match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected nested goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "nested status" (Some "complete") usage.status;
          Alcotest.(check (option (float 0.01))) "nested time" (Some 7.25) usage.time_used_seconds;
          Alcotest.(check (option int)) "nested tokens" (Some 88) usage.tokens_used)

let test_orchestrator_commits_stage_before_success_status () =
  with_temp_dir "symphony-stage-commit-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "fixture"; message = "<type>: <generated_message_max_90char>"; push = false; classification = None };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let events = ref [] in
      let set_status _ _ status =
        events := ("status:" ^ status) :: !events;
        Ok ()
      in
      let commit_stage _ _workspace issue stage next_status =
        let message =
          match stage with
          | Some { Config.commit = Some policy; _ } -> Orchestrator.render_commit_message issue stage next_status policy
          | _ -> Alcotest.fail "expected stage commit policy"
        in
        events := ("commit:" ^ message) :: !events;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~commit_stage ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list string)) "commit before status" [ "commit:fixture: complete #1 One"; "status:In review" ] (List.rev !events))

let test_stage_commit_classification_renders_messages () =
  let policy =
    {
      Config.enabled = true;
      commit_type = "feat";
      message = "<type>: <generated_message_max_90char>";
      push = false;
      classification =
        Some
          {
            default = "feat";
            label_map = [ ("bug", "fix"); ("documentation", "docs"); ("docs", "docs") ];
            conflict_behavior = "human_attention";
          };
    }
  in
  let stage =
    Some
      {
        Config.states = [ "In progress" ];
        agent = "engineer";
        max_concurrent_agents = None;
                    context_snapshot = None;
        skills = [];
        start_status = None;
        success_status = Some "In review";
        retry_status = Some "Todo";
        goal = None;
        commit = Some policy;
      }
  in
  let issue ?(labels = []) identifier title =
    { (Issue.empty ~id:identifier ~identifier ~title ~state:"In progress") with labels }
  in
  Alcotest.(check string) "fallback classification" "feat: complete #1 Fallback"
    (Orchestrator.render_commit_message (issue "#1" "Fallback") stage (Some "In review") policy);
  Alcotest.(check string) "label-derived classification" "fix: complete #2 Bug"
    (Orchestrator.render_commit_message (issue ~labels:[ "Bug" ] "#2" "Bug") stage (Some "In review") policy);
  Alcotest.(check string) "tag token classification" "fix: complete #2 Bug"
    (Orchestrator.render_commit_message (issue ~labels:[ "Bug" ] "#2" "Bug") stage (Some "In review")
       { policy with message = "<tag>: <generated_message_max_90char>" });
  Alcotest.(check string) "same classification labels" "docs: complete #3 Docs"
    (Orchestrator.render_commit_message (issue ~labels:[ "documentation"; "docs" ] "#3" "Docs") stage
       (Some "In review") policy);
  match Orchestrator.render_commit_message_result (issue ~labels:[ "bug"; "documentation" ] "#4" "Conflict") stage
          (Some "In review") policy with
  | Ok message -> Alcotest.fail ("expected conflict, got " ^ message)
  | Error error ->
      Alcotest.(check string) "conflict diagnostic"
        "stage commit classification conflict: bug -> fix, documentation -> docs"
        error

let test_orchestrator_retries_when_success_status_move_fails () =
  with_temp_dir "symphony-status-failure-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In review" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "Done";
              project_status_on_retry = Some "In progress";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In review" in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = [ issue ] in
      let set_status _ _ status = if status = "Done" then Error "bad option id" else Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "running removed" 0 (List.length state.Runtime_state.running);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      match state.retrying with
      | retry :: _ ->
          Alcotest.(check string) "retry issue" "I1" retry.issue_id;
          Alcotest.(check int) "retry attempt" 1 retry.attempt
      | [] -> Alcotest.fail "expected retry row")

let test_orchestrator_retries_push_failure_before_success_status () =
  with_temp_dir "symphony-push-failure-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = true; classification = None };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let commit_stage _ _ _ _ _ = Error "stage push failed: exit 1: remote rejected" in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~commit_stage ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      statuses := [];
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check (list string)) "retry status only" [ "Todo" ] (List.rev !statuses);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      Alcotest.(check (option string)) "last error" (Some "stage push failed: exit 1: remote rejected") state.last_error)

let test_stage_commit_requires_code_changes () =
  with_temp_dir "symphony-empty-commit-" (fun root ->
      Alcotest.(check int) "git init" 0 (Sys.command ("git init -q " ^ Util.shell_quote root));
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let stage =
        Some
          {
            Config.states = [ "In progress" ];
            agent = "engineer";
            max_concurrent_agents = None;
                    context_snapshot = None;
            skills = [];
            start_status = None;
            success_status = Some "In review";
            retry_status = Some "Todo";
            goal = None;
            commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = false; classification = None };
          }
      in
      let workspace = { Workspace.path = root; workspace_key = "test"; created_now = false } in
      match Orchestrator.git_commit_stage_changes config workspace issue stage (Some "In review") with
      | Ok () -> Alcotest.fail "empty commit-required stages must fail"
      | Error error -> Alcotest.(check string) "empty commit error" "commit required but agent produced no code changes" error)

let test_orchestrator_does_not_retry_empty_commit () =
  with_temp_dir "symphony-empty-commit-block-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          protected_paths = Config.default_protected_paths;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = false; classification = None };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let launches = ref 0 in
      let statuses = ref [] in
      let fetch _ = [ issue ] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let commit_stage _ _ _ _ _ = Error "commit required but agent produced no code changes" in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~commit_stage ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "first launch" 1 !launches;
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "no immediate relaunch" 1 !launches;
      Alcotest.(check (list string)) "moves no-change issue out of in-progress" [ "Todo" ] (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "not retrying" 0 (List.length state.retrying);
      Alcotest.(check int) "issue error recorded" 1 (List.length state.issue_errors);
      Alcotest.(check (option string)) "last error" (Some "commit required but agent produced no code changes") state.last_error)

let base_orchestrator_config root git =
  {
    Config.workflow_path = "settings.json";
    repository_root = root;
    tracker =
      {
        kind = "github";
        owner = "acme";
        repo = "widgets";
        project_number = 7;
        api_key_env = "GITHUB_TOKEN";
        api_key = Some "token";
        active_states = [ "Todo"; "In progress" ];
        terminal_states = [ "Done" ];
        project_status_field = "Status";
        project_status_on_dispatch = Some "In progress";
        project_status_on_success = Some "In review";
        project_status_on_retry = Some "Todo";
        ensure_project_statuses = true;
      };
    polling = { interval_ms = 1000 };
    workspace = { root = Filename.concat root ".symphony/workspaces" };
    git;
    agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
    codex =
      {
        command = "true";
        model = Config.default_model;
        reasoning_effort = Config.default_reasoning_effort;
        turn_timeout_ms = 1000;
        read_timeout_ms = 100;
        stall_timeout_ms = 1000;
    };
    server = { port = None };
    pull_request = Config.default_pull_request;
    protected_paths = Config.default_protected_paths;
    stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
  }

let protected_path_policy patterns =
  {
    Config.patterns = patterns;
    authorization = { Config.issue_section = "Protected Path Authorization" };
  }

let with_protected_paths patterns config = { config with Config.protected_paths = protected_path_policy patterns }

let protected_stage =
  Some
    {
      Config.states = [ "In progress" ];
      agent = "engineer";
      max_concurrent_agents = None;
                    context_snapshot = None;
      skills = [];
      start_status = None;
      success_status = Some "In review";
      retry_status = Some "Todo";
      goal = None;
      commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = false; classification = None };
    }

let protected_patterns =
  [
    { Config.name = "cli-entrypoint"; pattern = "bin/symphony.js"; reason = None };
    { Config.name = "release-workflows"; pattern = ".github/workflows/"; reason = None };
    { Config.name = "package-scripts"; pattern = "scripts/package-*.js"; reason = None };
  ]

let test_protected_path_policy_matches_files_directories_and_globs () =
  let config = base_orchestrator_config (Unix.getcwd ()) (git_policy ()) |> with_protected_paths protected_patterns in
  let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
  let paths =
    [
      "bin/symphony.js";
      ".github/workflows/export-npm.yml";
      "scripts/package-binary.js";
      "apps/backend/lib/config.ml";
    ]
  in
  let matches = Orchestrator.unauthorized_protected_path_matches config issue paths in
  Alcotest.(check (list string)) "matched paths"
    [ "bin/symphony.js"; ".github/workflows/export-npm.yml"; "scripts/package-binary.js" ]
    (List.map (fun (match_ : Orchestrator.protected_path_match) -> match_.path) matches)

let test_stage_commit_blocks_unauthorized_protected_path_change () =
  with_temp_dir "symphony-protected-stage-block-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> with_protected_paths protected_patterns in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      Util.mkdir_p (Filename.concat root "bin");
      Util.write_file (Filename.concat root "bin/symphony.js") "changed\n";
      let workspace = { Workspace.path = root; workspace_key = "test"; created_now = false } in
      match Orchestrator.git_commit_stage_changes config workspace issue protected_stage (Some "In review") with
      | Ok () -> Alcotest.fail "expected Protected Path Policy block"
      | Error error ->
          Alcotest.(check bool) "diagnostic names path" true (contains_substring error "bin/symphony.js");
          Alcotest.(check bool) "diagnostic names pattern" true (contains_substring error "cli-entrypoint");
          Alcotest.(check int) "no stage commit" 1
            (run_ok ~cwd:root "commit count" "git rev-list --count HEAD" |> int_of_string))

let test_stage_commit_blocks_deleted_and_renamed_protected_paths () =
  with_temp_dir "symphony-protected-stage-delete-rename-" (fun root ->
      init_repo root "feature/start";
      Util.mkdir_p (Filename.concat root "bin");
      Util.mkdir_p (Filename.concat root "scripts");
      Util.write_file (Filename.concat root "bin/symphony.js") "entrypoint\n";
      Util.write_file (Filename.concat root "scripts/package-binary.js") "package\n";
      ignore
        (run_ok ~cwd:root "seed protected files"
           "git add bin/symphony.js scripts/package-binary.js && git commit -q -m protected-files");
      let config = base_orchestrator_config root (git_policy ()) |> with_protected_paths protected_patterns in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      Sys.remove (Filename.concat root "bin/symphony.js");
      ignore (run_ok ~cwd:root "rename protected script" "git mv scripts/package-binary.js scripts/ordinary.js");
      let workspace = { Workspace.path = root; workspace_key = "test"; created_now = false } in
      match Orchestrator.git_commit_stage_changes config workspace issue protected_stage (Some "In review") with
      | Ok () -> Alcotest.fail "expected Protected Path Policy block"
      | Error error ->
          Alcotest.(check bool) "diagnostic names deleted path" true (contains_substring error "bin/symphony.js");
          Alcotest.(check bool) "diagnostic names renamed path" true
            (contains_substring error "scripts/package-binary.js");
          Alcotest.(check int) "no stage commit" 2
            (run_ok ~cwd:root "commit count" "git rev-list --count HEAD" |> int_of_string))

let test_stage_commit_allows_authorized_protected_path_change () =
  with_temp_dir "symphony-protected-stage-authorized-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> with_protected_paths protected_patterns in
      let issue =
        {
          (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress") with
          description = Some "## Protected Path Authorization\n\n- `cli-entrypoint`\n";
        }
      in
      Util.mkdir_p (Filename.concat root "bin");
      Util.write_file (Filename.concat root "bin/symphony.js") "changed\n";
      let workspace = { Workspace.path = root; workspace_key = "test"; created_now = false } in
      match Orchestrator.git_commit_stage_changes config workspace issue protected_stage (Some "In review") with
      | Error error -> Alcotest.fail error
      | Ok () ->
          Alcotest.(check int) "stage commit created" 2
            (run_ok ~cwd:root "commit count" "git rev-list --count HEAD" |> int_of_string))

let test_orchestrator_moves_unauthorized_protected_stage_to_attention () =
  with_temp_dir "symphony-protected-stage-attention-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config =
        {
          (base_orchestrator_config root (git_policy ())) with
          Config.protected_paths = protected_path_policy protected_patterns;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit =
                      Some
                        {
                          enabled = true;
                          commit_type = "feat";
                          message = Config.default_commit_message;
                          push = false;
                          classification = None;
                        };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I33" ~identifier:"#33" ~title:"Protected" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.mkdir_p (Filename.concat workspace.path "bin");
      Util.write_file (Filename.concat workspace.path "bin/symphony.js") "changed\n";
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list (pair string string))) "attention status" [ ("#33", "Human attention") ]
        (List.rev !statuses);
      Alcotest.(check int) "no stage commit" 2
        (run_ok ~cwd:workspace.path "commit count" "git rev-list --count HEAD" |> int_of_string);
      Alcotest.(check bool) "worktree kept for inspection" true (Sys.file_exists workspace.path);
      Alcotest.(check bool) "diagnostic names path" true
        (contains_substring
           (Option.value (Orchestrator.get_state orchestrator).Runtime_state.last_error ~default:"")
           "bin/symphony.js"))

let test_allowed_loop_start_branch_readiness () =
  with_temp_dir "symphony-loop-start-ready-" (fun root ->
      init_repo root "symphony/dogfood";
      let allowed = base_orchestrator_config root (git_policy ~allowed_loop_start_branches:[ "symphony/dogfood" ] ()) in
      Alcotest.(check int) "allowed branch has no policy gap" 0
        (Config.readiness_gaps allowed
        |> List.filter (fun (gap : Config.readiness_gap) -> gap.requirement = "git.allowedLoopStartBranches")
        |> List.length);
      ignore (run_ok ~cwd:root "create main" "git switch -q -c main");
      let blocked = base_orchestrator_config root (git_policy ~allowed_loop_start_branches:[ "symphony/dogfood" ] ()) in
      let gaps = Config.readiness_gaps blocked in
      let gap =
        List.find_opt (fun (gap : Config.readiness_gap) -> gap.requirement = "git.allowedLoopStartBranches") gaps
      in
      Alcotest.(check bool) "disallowed branch is a readiness gap" true (Option.is_some gap);
      let remediation = match gap with Some gap -> gap.remediation | None -> "" in
      Alcotest.(check bool) "mentions current branch" true (contains_substring remediation "current Loop-Start Branch main");
      Alcotest.(check bool) "mentions allowed branch" true (contains_substring remediation "symphony/dogfood");
      Alcotest.(check bool) "mentions remediation" true
        (contains_substring remediation "Switch to an allowed Loop-Start Branch or update Runtime Settings"))

let completed_stage_config root git =
  {
    (base_orchestrator_config root git) with
    Config.stage_agents =
      {
        enabled = true;
        root = Filename.concat root "agents";
        default_agent = None;
        stages =
          [
            {
              Config.states = [ "In progress" ];
              agent = "engineer";
              max_concurrent_agents = None;
                    context_snapshot = None;
              skills = [];
              start_status = Some "In progress";
              success_status = Some "In review";
              retry_status = Some "Todo";
              goal = None;
              commit = None;
            };
          ];
      };
  }

let diagnostic_categories state =
  List.map (fun (row : Runtime_state.startup_reconciliation) -> row.category) state.Runtime_state.startup_reconciliation

let create_task_worktree config issue =
  match Orchestrator.shell_prepare_workspace config ~loop_start_branch:(Orchestrator.current_branch config.Config.repository_root) issue with
  | Ok workspace -> workspace
  | Error error -> Alcotest.fail error

let completed_child issue workspace =
  {
    Orchestrator.pid = 0;
    issue;
    stage = None;
    issue_id = issue.Issue.id;
    issue_identifier = issue.identifier;
    issue_title = issue.title;
    workspace;
    started_at = Unix.time ();
    last_output_at = Unix.time ();
    stdout_path = None;
    stderr_path = None;
    stdout_size = 0;
    stderr_size = 0;
  }

let test_conflicting_stage_commit_classification_moves_attention_without_commit () =
  with_temp_dir "symphony-stage-commit-classification-attention-" (fun root ->
      init_repo root "symphony/dogfood";
      let config =
        {
          (base_orchestrator_config root (git_policy ~auto_merge:false ())) with
          Config.stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit =
                      Some
                        {
                          enabled = true;
                          commit_type = "feat";
                          message = Config.default_commit_message;
                          push = false;
                          classification =
                            Some
                              {
                                default = "feat";
                                label_map = [ ("bug", "fix"); ("documentation", "docs") ];
                                conflict_behavior = "human_attention";
                              };
                        };
                  };
                ];
            };
        }
      in
      let issue =
        {
          (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Conflicting labels" ~state:"In progress") with
          labels = [ "bug"; "documentation" ];
        }
      in
      Util.write_file (Filename.concat root "change.txt") "change\n";
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        (completed_child issue { Workspace.path = root; workspace_key = "test"; created_now = false });
      Alcotest.(check (list string)) "moves to attention" [ "Human attention" ] (List.rev !statuses);
      Alcotest.(check int) "no stage commit created" 1
        (List.length (run_ok ~cwd:root "log" "git log --format=%s" |> Util.split_lines));
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "not retrying" 0 (List.length state.retrying);
      Alcotest.(check (option string)) "last error"
        (Some "stage commit classification conflict: bug -> fix, documentation -> docs")
        state.last_error)

let test_ordered_queue_keeps_stage_handoffs_pending () =
  with_temp_dir "symphony-orchestrator-queue-stage-" (fun root ->
      let current_status = ref "Backlog" in
      let base_config = base_orchestrator_config root (git_policy ()) in
      let config =
        {
          base_config with
          Config.tracker =
            {
              base_config.tracker with
              active_states = [ "Backlog"; "Todo" ];
              project_status_on_dispatch = None;
              project_status_on_success = Some "Done";
            };
          pull_request = { Config.default_pull_request with enabled = false };
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Backlog" ];
                    agent = "planner";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "Todo";
                    retry_status = Some "Backlog";
                    goal = None;
                    commit = None;
                  };
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    max_concurrent_agents = None;
                    context_snapshot = None;
                    skills = [];
                    start_status = None;
                    success_status = Some "Done";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue () = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:!current_status in
      let ordered_queue =
        match Ordered_queue.parse "#1" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.state :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        current_status := status;
        Ok ()
      in
      let commit_stage _ _ _ _ _ = Ok () in
      let orchestrator =
        Orchestrator.make ~ordered_queue ~launch ~fetch:(fun _ -> [ issue () ]) ~set_status ~commit_stage ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "first launch" [ "Backlog" ] (List.rev !launched);
      let workspace = Workspace.create_for_issue ~root:config.Config.workspace.root "#1" in
      Orchestrator.mark_completed orchestrator (completed_child (issue ()) workspace);
      (match (Orchestrator.get_state orchestrator).Runtime_state.ordered_queue with
      | Some queue ->
          Alcotest.(check (list string)) "stage handoff remains pending" [ "pending" ]
            (List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state) queue.entries)
      | None -> Alcotest.fail "expected ordered queue state");
      Alcotest.(check string) "moved to next active stage" "Todo" !current_status;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "second launch" [ "Backlog"; "Todo" ] (List.rev !launched))

let test_ordered_queue_revives_persisted_completed_active_entries () =
  with_temp_dir "symphony-orchestrator-queue-revive-" (fun root ->
      let base_config = base_orchestrator_config root (git_policy ()) in
      let config =
        {
          base_config with
          Config.tracker = { base_config.tracker with active_states = [ "Todo" ]; project_status_on_dispatch = None };
          pull_request = { Config.default_pull_request with enabled = false };
        }
      in
      let persisted =
        {
          Runtime_state.entries =
            [ { Runtime_state.issue_identifier = "#1"; title = Some "One"; state = "completed"; skip_reason = None } ];
        }
      in
      let path = Orchestrator.ordered_queue_state_path config in
      Util.mkdir_p (Filename.dirname path);
      Util.write_file path (Runtime_state.ordered_queue_to_yojson persisted |> Yojson.Safe.to_string);
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let ordered_queue =
        match Ordered_queue.parse "#1" with Ok queue -> queue | Error _ -> Alcotest.fail "queue parse failed"
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.identifier :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~ordered_queue ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "revived active entry launches" [ "#1" ] (List.rev !launched);
      match (Orchestrator.get_state orchestrator).Runtime_state.ordered_queue with
      | Some queue ->
          Alcotest.(check (list string)) "revived state is running" [ "running" ]
            (List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state) queue.entries)
      | None -> Alcotest.fail "expected ordered queue state")

let commit_file ~cwd file content message =
  Util.write_file (Filename.concat cwd file) content;
  ignore (run_ok ~cwd "commit file" (Printf.sprintf "git add %s && git commit -q -m %s" (Util.shell_quote file) (Util.shell_quote message)))

let test_startup_reconciliation_merges_completed_worktrees_in_order () =
  with_temp_dir "symphony-startup-reconcile-order-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let issue_22 = Issue.empty ~id:"I22" ~identifier:"#22" ~title:"Twenty two" ~state:"In review" in
      let issue_21 = Issue.empty ~id:"I21" ~identifier:"#21" ~title:"Twenty one" ~state:"In review" in
      let workspace_21 = create_task_worktree config issue_21 in
      commit_file ~cwd:workspace_21.path "a.txt" "a\n" "task 21";
      ignore (run_ok ~cwd:root "create second task branch" "git branch symphony/task-22 symphony/task-21");
      let workspace_22 = create_task_worktree config issue_22 in
      commit_file ~cwd:workspace_22.path "b.txt" "b\n" "task 22";
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue_22; issue_21 ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "first file merged" true (Sys.file_exists (Filename.concat root "a.txt"));
      Alcotest.(check bool) "second file merged" true (Sys.file_exists (Filename.concat root "b.txt"));
      Alcotest.(check (list string)) "diagnostic order" [ "direct_fast_forward"; "direct_fast_forward" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      let log = run_ok ~cwd:root "log" "git log --reverse --format=%s" |> Util.split_lines in
      Alcotest.(check (list string)) "merge order" [ "initial"; "ignore-runtime-home"; "task 21"; "task 22" ] log;
      Alcotest.(check (list (pair string string))) "no status changes after success" [] (List.rev !statuses))

let test_startup_reconciliation_already_contained_applies_cleanup_without_status_change () =
  with_temp_dir "symphony-startup-reconcile-contained-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I23" ~identifier:"#23" ~title:"Twenty three" ~state:"In review" in
      let workspace = create_task_worktree config issue in
      commit_file ~cwd:workspace.path "contained.txt" "contained\n" "task 23";
      ignore (run_ok ~cwd:root "manual merge" "git merge --ff-only symphony/task-23");
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "diagnostics" [ "already_reconciled" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check bool) "worktree removed" false (Sys.file_exists workspace.path);
      Alcotest.(check bool) "task branch kept" true
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-23") = 0);
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "startup reconciliation runs once" 1
        (List.length (Orchestrator.get_state orchestrator).Runtime_state.startup_reconciliation);
      Alcotest.(check (list (pair string string))) "no status changes" [] (List.rev !statuses))

let test_startup_reconciliation_moves_unsafe_candidates_to_attention () =
  with_temp_dir "symphony-startup-reconcile-attention-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let protected_issue = Issue.empty ~id:"I24" ~identifier:"#24" ~title:"Protected" ~state:"In review" in
      let uncommitted_issue = Issue.empty ~id:"I25" ~identifier:"#25" ~title:"Uncommitted" ~state:"In review" in
      let protected_workspace = create_task_worktree config protected_issue in
      commit_file ~cwd:protected_workspace.path "protected.txt" "protected\n" "task 24";
      let uncommitted_workspace = create_task_worktree config uncommitted_issue in
      Util.write_file (Filename.concat uncommitted_workspace.path "dirty.txt") "dirty\n";
      let protected_config =
        {
          config with
          Config.git = { config.git with protected_trunk_branches = [ "feature/start" ] };
        }
      in
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ protected_issue; uncommitted_issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config:protected_config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "protected not merged" false (Sys.file_exists (Filename.concat root "protected.txt"));
      Alcotest.(check int) "no stage commit created for uncommitted changes" 2
        (List.length (run_ok ~cwd:uncommitted_workspace.path "log" "git log --format=%s" |> Util.split_lines));
      Alcotest.(check (list string)) "diagnostics"
        [ "attention_protected_trunk"; "attention_uncommitted_changes" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check (list (pair string string))) "attention statuses"
        [ ("#24", "Human attention"); ("#25", "Human attention") ]
        (List.rev !statuses);
      Alcotest.(check int) "issue errors" 2 (List.length (Orchestrator.get_state orchestrator).issue_errors))

let test_startup_reconciliation_blocks_unauthorized_protected_path_change () =
  with_temp_dir "symphony-startup-reconcile-protected-path-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config =
        completed_stage_config root (git_policy ~auto_merge:true ()) |> with_protected_paths protected_patterns
      in
      let issue = Issue.empty ~id:"I32" ~identifier:"#32" ~title:"Protected path" ~state:"In review" in
      let workspace = create_task_worktree config issue in
      Util.mkdir_p (Filename.concat workspace.path "bin");
      commit_file ~cwd:workspace.path "bin/symphony.js" "changed\n" "task 32";
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "protected file not merged" false (Sys.file_exists (Filename.concat root "bin/symphony.js"));
      Alcotest.(check (list string)) "diagnostics" [ "attention_protected_paths" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check (list (pair string string))) "attention status" [ ("#32", "Human attention") ]
        (List.rev !statuses))

let test_startup_reconciliation_updates_task_branch_before_fast_forward () =
  with_temp_dir "symphony-startup-reconcile-nonff-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let nonff_issue = Issue.empty ~id:"I26" ~identifier:"#26" ~title:"Non fast forward" ~state:"In review" in
      let later_issue = Issue.empty ~id:"I27" ~identifier:"#27" ~title:"Later" ~state:"In review" in
      let nonff_workspace = create_task_worktree config nonff_issue in
      commit_file ~cwd:nonff_workspace.path "nonff.txt" "task\n" "task 26";
      commit_file ~cwd:root "loop.txt" "loop\n" "loop advance";
      let later_workspace = create_task_worktree config later_issue in
      commit_file ~cwd:later_workspace.path "later.txt" "later\n" "task 27";
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ nonff_issue; later_issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "non fast forward merged" true (Sys.file_exists (Filename.concat root "nonff.txt"));
      Alcotest.(check bool) "later candidate still merged" true (Sys.file_exists (Filename.concat root "later.txt"));
      Alcotest.(check (list string)) "diagnostics"
        [ "updated_task_branch_then_fast_forwarded"; "updated_task_branch_then_fast_forwarded" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check (list (pair string string))) "no attention status" []
        (List.rev !statuses))

let test_startup_reconciliation_detects_wrong_and_missing_task_branch () =
  with_temp_dir "symphony-startup-reconcile-branch-state-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let wrong_issue = Issue.empty ~id:"I28" ~identifier:"#28" ~title:"Wrong branch" ~state:"In review" in
      let missing_issue = Issue.empty ~id:"I29" ~identifier:"#29" ~title:"Missing branch" ~state:"In review" in
      let stale_issue = Issue.empty ~id:"I32" ~identifier:"#32" ~title:"Stale workspace" ~state:"In review" in
      ignore (run_ok ~cwd:root "wrong branch" "git branch symphony/task-other feature/start");
      Util.mkdir_p config.workspace.root;
      let wrong_path = Filename.concat config.workspace.root "_28" in
      ignore
        (run_ok ~cwd:root "wrong worktree"
           (Printf.sprintf "git worktree add %s symphony/task-other" (Util.shell_quote wrong_path)));
      let missing_workspace = create_task_worktree config missing_issue in
      ignore (run_ok ~cwd:root "delete expected branch" "git update-ref -d refs/heads/symphony/task-29");
      let stale_path = Filename.concat config.workspace.root "_32" in
      Unix.mkdir stale_path 0o755;
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ wrong_issue; missing_issue; stale_issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "missing worktree kept" true (Sys.file_exists missing_workspace.path);
      Alcotest.(check (list string)) "diagnostics"
        [ "attention_wrong_branch"; "attention_missing_task_branch"; "skipped_not_git_worktree" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check (list (pair string string))) "attention statuses"
        [ ("#28", "Human attention"); ("#29", "Human attention"); ("#32", "Human attention") ]
        (List.rev !statuses))

let test_startup_reconciliation_blocks_when_loop_start_dirty () =
  with_temp_dir "symphony-startup-reconcile-dirty-loop-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I30" ~identifier:"#30" ~title:"Dirty loop" ~state:"In review" in
      let workspace = create_task_worktree config issue in
      commit_file ~cwd:workspace.path "dirty-loop-task.txt" "task\n" "task 30";
      Util.write_file (Filename.concat root "dirty-loop.txt") "dirty\n";
      let statuses = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ])
          ~set_status:(fun _ issue status ->
            statuses := (issue.Issue.identifier, status) :: !statuses;
            Ok ())
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "not merged" false (Sys.file_exists (Filename.concat root "dirty-loop-task.txt"));
      Alcotest.(check (list string)) "startup-level diagnostic" [ "startup_blocked_dirty_loop_start" ]
        (diagnostic_categories (Orchestrator.get_state orchestrator));
      Alcotest.(check (list (pair string string))) "no candidate status changes" [] (List.rev !statuses);
      match (Orchestrator.get_state orchestrator).last_error with
      | Some error ->
          Alcotest.(check bool) "last error names startup reconciliation" true
            (Util.starts_with ~prefix:"Startup Reconciliation blocked:" error)
      | None -> Alcotest.fail "expected startup reconciliation error")

let test_startup_reconciliation_ignores_retained_branch_without_worktree () =
  with_temp_dir "symphony-startup-reconcile-no-worktree-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = completed_stage_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I31" ~identifier:"#31" ~title:"No worktree" ~state:"In review" in
      ignore (run_ok ~cwd:root "branch" "git branch symphony/task-31 feature/start");
      let external_worktree = Filename.concat (Filename.dirname root) "external-task-31" in
      ignore
        (run_ok ~cwd:root "external worktree"
           (Printf.sprintf "git worktree add %s symphony/task-31" (Util.shell_quote external_worktree)));
      commit_file ~cwd:external_worktree "retained.txt" "retained\n" "task 31";
      ignore (run_ok ~cwd:root "remove external worktree" (Printf.sprintf "git worktree remove %s" (Util.shell_quote external_worktree)));
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Alcotest.fail "unexpected status change")
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "retained branch not merged" false (Sys.file_exists (Filename.concat root "retained.txt"));
      Alcotest.(check (list string)) "no diagnostics for branch without worktree" []
        (diagnostic_categories (Orchestrator.get_state orchestrator)))

let test_orchestrator_creates_task_worktree_and_branch () =
  with_temp_dir "symphony-task-worktree-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I1" ~identifier:"#3" ~title:"Three" ~state:"Todo" in
      let captured_workspace = ref None in
      let launch ~config:_ ~(workspace : Workspace.t) ~prompt:_ ~issue =
        captured_workspace := Some workspace;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      let workspace = match !captured_workspace with Some workspace -> workspace | None -> Alcotest.fail "expected launch" in
      Alcotest.(check bool) "under runtime workspaces" true (Workspace.is_inside ~root:config.workspace.root ~path:workspace.path);
      Alcotest.(check string) "task branch" "symphony/task-3" (run_ok ~cwd:workspace.path "branch" "git branch --show-current");
      Alcotest.(check bool) "task branch exists" true
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-3") = 0);
      Alcotest.(check (list string)) "start status moved" [ "In progress" ] (List.rev !statuses))

let pull_request_config config =
  {
    config with
    Config.pull_request =
      {
        enabled = true;
        mode = "batch";
        open_on_review = false;
        base_branch = "main";
        title = "Symphony batch from <head_branch>";
        body = "Opened automatically by Symphony after orchestration became idle.";
      };
  }

let open_on_review_pull_request_config config =
  { config with Config.pull_request = { config.Config.pull_request with enabled = true; open_on_review = true } }

let task_pull_request_config config =
  {
    config with
    Config.pull_request =
      {
        enabled = true;
        mode = "task";
        open_on_review = false;
        base_branch = "main";
        title = "Symphony task from <head_branch>";
        body = "Opened automatically by Symphony when the task reached review.";
      };
  }

let test_orchestrator_opens_batch_pull_request_once_when_idle () =
  with_temp_dir "symphony-batch-pr-idle-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref [] in
      let batch_pull_request_handoff _config ~head_branch =
        attempts := head_branch :: !attempts;
        Ok (Some "https://github.example/acme/widgets/pull/1")
      in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~batch_pull_request_handoff ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "handoff attempted once" [ "feature/start" ] (List.rev !attempts);
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "status" "completed" handoff.status;
          Alcotest.(check (option string)) "url" (Some "https://github.example/acme/widgets/pull/1") handoff.url
      | None -> Alcotest.fail "expected pull request handoff state")

let test_orchestrator_opens_batch_pull_request_on_review_status () =
  with_temp_dir "symphony-batch-pr-review-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) |> open_on_review_pull_request_config in
      let issue = Issue.empty ~id:"I33" ~identifier:"#33" ~title:"Thirty three" ~state:"Todo" in
      let attempts = ref [] in
      let current_status = ref "Todo" in
      let launch ~config:_ ~workspace ~prompt:_ ~issue =
        commit_file ~cwd:workspace.Workspace.path "review-pr.txt" "ready\n" "task 33";
        let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "true" |] Unix.stdin Unix.stdout Unix.stderr in
        { Orchestrator.pid = Some pid; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ =
        if List.exists (fun status -> String.lowercase_ascii status = String.lowercase_ascii !current_status) config.tracker.active_states
        then [ { issue with state = !current_status } ]
        else []
      in
      let set_status _ _ status =
        current_status := status;
        Ok ()
      in
      let batch_pull_request_handoff _config ~head_branch =
        attempts := head_branch :: !attempts;
        Ok (Some "https://github.example/acme/widgets/pull/33")
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch ~set_status ~batch_pull_request_handoff ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "handoff attempted after review status" [ "feature/start" ] (List.rev !attempts);
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "status" "completed" handoff.status;
          Alcotest.(check (option string)) "url" (Some "https://github.example/acme/widgets/pull/33") handoff.url
      | None -> Alcotest.fail "expected pull request handoff state")

let test_orchestrator_opens_task_pull_request_on_review_status_from_protected_loop_start () =
  with_temp_dir "symphony-task-pr-review-" (fun root ->
      init_repo root "main";
      ignore_runtime_home root;
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) |> task_pull_request_config in
      let issue = Issue.empty ~id:"I34" ~identifier:"#34" ~title:"Thirty four" ~state:"Todo" in
      let attempts = ref [] in
      let current_status = ref "Todo" in
      let launch ~config:_ ~workspace ~prompt:_ ~issue =
        commit_file ~cwd:workspace.Workspace.path "task-pr.txt" "ready\n" "task 34";
        let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "true" |] Unix.stdin Unix.stdout Unix.stderr in
        { Orchestrator.pid = Some pid; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ =
        if List.exists (fun status -> String.lowercase_ascii status = String.lowercase_ascii !current_status) config.tracker.active_states
        then [ { issue with state = !current_status } ]
        else []
      in
      let set_status _ _ status =
        current_status := status;
        Ok ()
      in
      let batch_pull_request_handoff _config ~head_branch =
        attempts := head_branch :: !attempts;
        Ok (Some "https://github.example/acme/widgets/pull/34")
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch ~set_status ~batch_pull_request_handoff ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "handoff attempted from Task Branch" [ "symphony/task-34" ] (List.rev !attempts);
      Alcotest.(check bool) "not merged into main" false (Sys.file_exists (Filename.concat root "task-pr.txt"));
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "mode" "task" handoff.mode;
          Alcotest.(check (option string)) "issue identifier" (Some "#34") handoff.issue_identifier;
          Alcotest.(check (option string)) "head branch" (Some "symphony/task-34") handoff.head_branch;
          Alcotest.(check string) "status" "completed" handoff.status;
          Alcotest.(check (option string)) "url" (Some "https://github.example/acme/widgets/pull/34") handoff.url
      | None -> Alcotest.fail "expected task pull request handoff state")

let test_task_pull_request_opens_before_auto_merge_cleanup () =
  with_temp_dir "symphony-task-pr-before-cleanup-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let git =
        {
          (git_policy ~auto_merge:true ()) with
          cleanup = { Config.remove_worktree_after_merge = true; keep_task_branch = false };
        }
      in
      let config = base_orchestrator_config root git |> task_pull_request_config in
      let issue = Issue.empty ~id:"I35" ~identifier:"#35" ~title:"Thirty five" ~state:"In progress" in
      let workspace = create_task_worktree config issue in
      commit_file ~cwd:workspace.path "task-pr-before-cleanup.txt" "ready\n" "task 35";
      let statuses = ref [] in
      let branch_exists_during_handoff = ref false in
      let attempts = ref [] in
      let set_status _ issue status =
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let batch_pull_request_handoff _config ~head_branch =
        branch_exists_during_handoff :=
          Sys.command
            ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/"
            ^ Util.shell_quote head_branch)
          = 0;
        attempts := head_branch :: !attempts;
        Ok (Some "https://github.example/acme/widgets/pull/35")
      in
      let orchestrator =
        Orchestrator.make ~set_status ~batch_pull_request_handoff ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.mark_completed orchestrator (completed_child issue workspace);
      Alcotest.(check (list string)) "handoff attempted from Task Branch" [ "symphony/task-35" ] (List.rev !attempts);
      Alcotest.(check bool) "Task Branch exists during handoff" true !branch_exists_during_handoff;
      Alcotest.(check bool) "task merged into Loop-Start Branch" true
        (Sys.file_exists (Filename.concat root "task-pr-before-cleanup.txt"));
      Alcotest.(check bool) "Task Branch removed after cleanup" false
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-35") = 0);
      Alcotest.(check (list (pair string string))) "review status before completion" [ ("#35", "In review") ]
        (List.rev !statuses);
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "status" "completed" handoff.status;
          Alcotest.(check (option string)) "head branch" (Some "symphony/task-35") handoff.head_branch
      | None -> Alcotest.fail "expected task pull request handoff state")

let test_orchestrator_retries_batch_pull_request_handoff_failure () =
  with_temp_dir "symphony-batch-pr-retry-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref 0 in
      let batch_pull_request_handoff _config ~head_branch:_ =
        incr attempts;
        if !attempts = 1 then Error "batch branch push failed: exit 1: rejected" else Ok None
      in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~batch_pull_request_handoff ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      (match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "failure status" "retryable_failure" handoff.status;
          Alcotest.(check (option string)) "failure error" (Some "batch branch push failed: exit 1: rejected") handoff.error
      | None -> Alcotest.fail "expected failed handoff state");
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "retried on later idle poll" 2 !attempts;
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff -> Alcotest.(check string) "eventual status" "completed" handoff.status
      | None -> Alcotest.fail "expected completed handoff state")

let test_orchestrator_blocks_batch_pull_request_on_attention () =
  with_temp_dir "symphony-batch-pr-attention-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref 0 in
      let batch_pull_request_handoff _config ~head_branch:_ =
        incr attempts;
        Ok None
      in
      let issue = Issue.empty ~id:"I-attn" ~identifier:"#99" ~title:"Needs merge" ~state:"Human attention" in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ]) ~batch_pull_request_handoff ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "no handoff while attention remains" 0 !attempts;
      Alcotest.(check bool) "no handoff state" true
        (Option.is_none (Orchestrator.get_state orchestrator).Runtime_state.pull_request))

let test_batch_pull_request_handoff_reuses_existing_pr () =
  with_temp_dir "symphony-batch-pr-existing-" (fun root ->
      let remote = Filename.concat root "remote.git" in
      let repo = Filename.concat root "repo" in
      let bin = Filename.concat root "bin" in
      Unix.mkdir repo 0o755;
      Unix.mkdir bin 0o755;
      ignore (run_ok ~cwd:root "bare remote" ("git init -q --bare " ^ Util.shell_quote remote));
      init_repo repo "feature/start";
      ignore (run_ok ~cwd:repo "add origin" ("git remote add origin " ^ Util.shell_quote remote));
      let gh_log = Filename.concat root "gh.log" in
      let gh_path = Filename.concat bin "gh" in
      Util.write_file gh_path
        (Printf.sprintf
           {|#!/bin/sh
printf '%%s\n' "$*" >> %s
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[{"url":"https://github.example/acme/widgets/pull/9"}]\n'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "create" ]; then
  exit 42
fi
exit 1
|}
           (Util.shell_quote gh_log));
      Unix.chmod gh_path 0o755;
      let original_path = Sys.getenv_opt "PATH" in
      Fun.protect
        ~finally:(fun () -> match original_path with Some path -> Unix.putenv "PATH" path | None -> Unix.putenv "PATH" "")
        (fun () ->
          Unix.putenv "PATH" (bin ^ ":" ^ Option.value original_path ~default:"");
          let config = base_orchestrator_config repo (git_policy ()) |> pull_request_config in
          match Orchestrator.gh_batch_pull_request_handoff config ~head_branch:"feature/start" with
          | Error error -> Alcotest.fail error
          | Ok url ->
              Alcotest.(check (option string)) "existing PR URL" (Some "https://github.example/acme/widgets/pull/9") url;
              Alcotest.(check bool) "remote loop-start branch pushed" true
                (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/feature/start") = 0);
              let lines = Util.read_file gh_log |> Util.split_lines in
              Alcotest.(check bool) "looked for existing PR" true
                (List.exists (Util.starts_with ~prefix:"pr list") lines);
              Alcotest.(check bool) "did not create duplicate" false
                (List.exists (Util.starts_with ~prefix:"pr create") lines)))

let test_orchestrator_requires_clean_loop_start_for_new_worktree () =
  with_temp_dir "symphony-dirty-loop-" (fun root ->
      init_repo root "feature/start";
      Util.write_file (Filename.concat root "dirty.txt") "dirty\n";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I2" ~identifier:"#4" ~title:"Four" ~state:"Todo" in
      let launches = ref 0 in
      let statuses = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "not launched" 0 !launches;
      Alcotest.(check (list string)) "moves to attention without in-progress" [ "Human attention" ] (List.rev !statuses);
      Alcotest.(check (option string)) "last error"
        (Some "loop-start worktree must be clean before creating task worktrees")
        (Orchestrator.get_state orchestrator).last_error;
      Alcotest.(check bool) "no placeholder worktree left" false
        (Sys.file_exists (Filename.concat config.workspace.root "_4")))

let test_orchestrator_blocks_disallowed_loop_start_before_side_effects () =
  with_temp_dir "symphony-disallowed-loop-start-" (fun root ->
      init_repo root "main";
      let config =
        completed_stage_config root (git_policy ~auto_merge:true ~allowed_loop_start_branches:[ "symphony/dogfood" ] ())
      in
      let issue = Issue.empty ~id:"I30" ~identifier:"#30" ~title:"Thirty" ~state:"In review" in
      let workspace = create_task_worktree config issue in
      Util.write_file (Filename.concat workspace.path "should-not-merge.txt") "blocked\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add should-not-merge.txt && git commit -q -m task");
      let fetches = ref 0 in
      let statuses = ref [] in
      let launches = ref 0 in
      let prs = ref 0 in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ ->
            incr fetches;
            [ issue ])
          ~set_status
          ~batch_pull_request_handoff:(fun _ ~head_branch:_ ->
            incr prs;
            Ok (Some "https://example.test/pr/1"))
          ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "tracker not fetched" 0 !fetches;
      Alcotest.(check int) "not launched" 0 !launches;
      Alcotest.(check (list string)) "no status movement" [] (List.rev !statuses);
      Alcotest.(check int) "no batch pull request" 0 !prs;
      Alcotest.(check bool) "startup reconciliation did not merge" false
        (Sys.file_exists (Filename.concat root "should-not-merge.txt"));
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check (list string)) "readiness gap"
        [ "git.allowedLoopStartBranches" ]
        (List.map (fun (gap : Runtime_state.readiness_gap) -> gap.requirement) state.readiness_gaps))

let test_orchestrator_reuses_existing_task_branch_on_restart () =
  with_temp_dir "symphony-reuse-task-branch-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I6" ~identifier:"#8" ~title:"Eight" ~state:"In progress" in
      ignore (run_ok ~cwd:root "create task branch" "git branch symphony/task-8 feature/start");
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Alcotest.(check string) "reused branch checked out" "symphony/task-8"
        (run_ok ~cwd:workspace.path "branch" "git branch --show-current"))

let test_orchestrator_prunes_missing_registered_worktree () =
  with_temp_dir "symphony-missing-registered-worktree-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I13" ~identifier:"#13" ~title:"Thirteen" ~state:"In progress" in
      let workspace = create_task_worktree config issue in
      ignore (run_ok ~cwd:root "delete worktree directory" (Printf.sprintf "rm -rf %s" (Util.shell_quote workspace.path)));
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Alcotest.(check string) "recreated branch checked out" "symphony/task-13"
        (run_ok ~cwd:workspace.path "branch" "git branch --show-current"))

let test_orchestrator_reuses_worktree_for_existing_in_progress_task_before_launch () =
  with_temp_dir "symphony-existing-progress-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I9" ~identifier:"#11" ~title:"Eleven" ~state:"In progress" in
      ignore (run_ok ~cwd:root "create task branch" "git branch symphony/task-11 feature/start");
      let launched_branch = ref None in
      let launch ~config:_ ~(workspace : Workspace.t) ~prompt:_ ~issue =
        launched_branch := Some (run_ok ~cwd:workspace.path "branch" "git branch --show-current");
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (option string)) "launched from reused task branch" (Some "symphony/task-11") !launched_branch)

let test_orchestrator_rejects_existing_non_worktree_workspace () =
  with_temp_dir "symphony-existing-non-worktree-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I10" ~identifier:"#12" ~title:"Twelve" ~state:"In progress" in
      Util.mkdir_p config.workspace.root;
      let stale_workspace = Filename.concat config.workspace.root "_12" in
      Unix.mkdir stale_workspace 0o755;
      let launches = ref 0 in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "not launched" 0 !launches;
      Alcotest.(check (list string)) "attention status" [ "Human attention" ] (List.rev !statuses);
      Alcotest.(check (option string)) "last error"
        (Some (stale_workspace ^ " exists but is not an Agent Worktree"))
        (Orchestrator.get_state orchestrator).last_error)

let test_stage_commit_pushes_task_branch () =
  with_temp_dir "symphony-stage-push-" (fun root ->
      let remote = Filename.concat root "remote.git" in
      let repo = Filename.concat root "repo" in
      Unix.mkdir repo 0o755;
      ignore (run_ok ~cwd:root "bare remote" ("git init -q --bare " ^ Util.shell_quote remote));
      init_repo repo "feature/start";
      ignore (run_ok ~cwd:repo "add origin" ("git remote add origin " ^ Util.shell_quote remote));
      let config = base_orchestrator_config repo (git_policy ()) in
      let issue = Issue.empty ~id:"I3" ~identifier:"#5" ~title:"Five" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "work.txt") "work\n";
      let stage =
        Some
          {
            Config.states = [ "In progress" ];
            agent = "engineer";
            max_concurrent_agents = None;
                    context_snapshot = None;
            skills = [];
            start_status = None;
            success_status = Some "In review";
            retry_status = Some "Todo";
            goal = None;
            commit = Some { enabled = true; commit_type = "feat"; message = Config.default_commit_message; push = true; classification = None };
          }
      in
      (match Orchestrator.git_commit_stage_changes config workspace issue stage (Some "In review") with
      | Ok () -> ()
      | Error error -> Alcotest.fail error);
      Alcotest.(check bool) "remote task branch exists" true
        (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/symphony/task-5") = 0);
      Alcotest.(check bool) "loop-start branch not pushed" false
        (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/feature/start") = 0))

let test_auto_merge_fast_forwards_and_removes_worktree () =
  with_temp_dir "symphony-auto-merge-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I4" ~identifier:"#6" ~title:"Six" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "merged.txt") "merged\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add merged.txt && git commit -q -m task");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "merged file present" true (Sys.file_exists (Filename.concat root "merged.txt"));
      Alcotest.(check bool) "worktree removed" false (Sys.file_exists workspace.path);
      Alcotest.(check bool) "task branch kept" true
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-6") = 0);
      Alcotest.(check (list string)) "success status after merge" [ "In review" ] (List.rev !statuses))

let test_cleanup_can_remove_task_branch_after_merge () =
  with_temp_dir "symphony-cleanup-branch-" (fun root ->
      init_repo root "feature/start";
      let git =
        {
          (git_policy ~auto_merge:true ()) with
          cleanup = { Config.remove_worktree_after_merge = true; keep_task_branch = false };
        }
      in
      let config = base_orchestrator_config root git in
      let issue = Issue.empty ~id:"I7" ~identifier:"#9" ~title:"Nine" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "cleanup.txt") "cleanup\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add cleanup.txt && git commit -q -m task");
      let orchestrator = Orchestrator.make ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "task branch removed" false
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-9") = 0))

let test_auto_merge_skips_protected_trunk_branch () =
  with_temp_dir "symphony-protected-trunk-" (fun root ->
      init_repo root "main";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I8" ~identifier:"#10" ~title:"Ten" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"main" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "protected.txt") "protected\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add protected.txt && git commit -q -m task");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "not merged into main" false (Sys.file_exists (Filename.concat root "protected.txt"));
      Alcotest.(check bool) "worktree kept" true (Sys.file_exists workspace.path);
      Alcotest.(check (list string)) "still advances status" [ "In review" ] (List.rev !statuses))

let test_auto_merge_integrates_parallel_unrelated_task_branches () =
  with_temp_dir "symphony-parallel-task-integration-" (fun root ->
      init_repo root "feature/start";
      ignore_runtime_home root;
      let git = git_policy ~auto_merge:true () in
      let config =
        {
          (base_orchestrator_config root git) with
          Config.agent = { Config.max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
        }
      in
      let issue_11 = Issue.empty ~id:"I11" ~identifier:"#11" ~title:"Eleven" ~state:"In progress" in
      let issue_12 = Issue.empty ~id:"I12" ~identifier:"#12" ~title:"Twelve" ~state:"In progress" in
      let workspace_11 = create_task_worktree config issue_11 in
      let workspace_12 = create_task_worktree config issue_12 in
      commit_file ~cwd:workspace_11.path "one.txt" "one\n" "task 11";
      commit_file ~cwd:workspace_12.path "two.txt" "two\n" "task 12";
      let statuses = ref [] in
      let set_status _ issue status =
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator (completed_child issue_11 workspace_11);
      Orchestrator.mark_completed orchestrator (completed_child issue_12 workspace_12);
      Alcotest.(check bool) "first file merged" true (Sys.file_exists (Filename.concat root "one.txt"));
      Alcotest.(check bool) "second file merged" true (Sys.file_exists (Filename.concat root "two.txt"));
      Alcotest.(check bool) "first worktree removed" false (Sys.file_exists workspace_11.path);
      Alcotest.(check bool) "second worktree removed" false (Sys.file_exists workspace_12.path);
      Alcotest.(check (list (pair string string))) "both statuses advance"
        [ ("#11", "In review"); ("#12", "In review") ]
        (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "no issue errors" 0 (List.length state.issue_errors);
      Alcotest.(check (list string)) "integration results"
        [ "direct_fast_forward"; "updated_task_branch_then_fast_forwarded" ]
        (List.map
           (fun (row : Runtime_state.task_branch_integration) -> row.result)
           state.Runtime_state.task_branch_integrations))

let test_auto_merge_failure_moves_human_attention () =
  with_temp_dir "symphony-auto-merge-fail-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I5" ~identifier:"#7" ~title:"Seven" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat root "shared.txt") "base\n";
      ignore (run_ok ~cwd:root "base commit" "git add shared.txt && git commit -q -m base-shared");
      Util.write_file (Filename.concat workspace.path "shared.txt") "task\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add shared.txt && git commit -q -m task");
      Util.write_file (Filename.concat root "shared.txt") "loop\n";
      ignore (run_ok ~cwd:root "loop commit" "git add shared.txt && git commit -q -m loop");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          stage = None;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list string)) "attention status only" [ "Human attention" ] (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "issue error" 1 (List.length state.issue_errors);
      Alcotest.(check bool) "worktree kept for inspection" true (Sys.file_exists workspace.path);
      Alcotest.(check (list string)) "attention diagnostic" [ "attention" ]
        (List.map
           (fun (row : Runtime_state.task_branch_integration) -> row.result)
           state.Runtime_state.task_branch_integrations))

let manual_merge_config ?(keep_task_branch = true) root =
  if not (Sys.file_exists (Filename.concat root ".gitignore")) then (
    Util.write_file (Filename.concat root ".gitignore") ".symphony/\nagents/\n";
    ignore (run_ok ~cwd:root "ignore runtime files" "git add .gitignore && git commit -q -m ignore-runtime-files"));
  let git =
    {
      (git_policy ~auto_merge:false ()) with
      cleanup = { Config.remove_worktree_after_merge = true; keep_task_branch };
    }
  in
  {
    (base_orchestrator_config root git) with
    stage_agents =
      {
        enabled = true;
        root = Filename.concat root "agents";
        default_agent = None;
        stages =
          [
            {
              states = [ "In review" ];
              start_status = None;
              success_status = Some "Done";
              retry_status = None;
              agent = "reviewer";
              max_concurrent_agents = None;
                    context_snapshot = None;
              skills = [];
              goal = None;
              commit = None;
            };
          ];
      };
  }

let project_issue issue = Some { Github_tracker.issue; project_status = Some issue.Issue.state; closed = false }

let run_manual_merge_test config issues selectors =
  let fetch numbers =
    List.map
      (fun number ->
        ( number,
          match issues |> List.find_opt (fun issue -> issue.Issue.identifier = "#" ^ string_of_int number) with
          | None -> None
          | Some issue -> project_issue issue ))
      numbers
  in
  let statuses = ref [] in
  let set_status issue status =
    statuses := (issue.Issue.identifier, status) :: !statuses;
    Ok ()
  in
  (Manual_merge.run ~fetch_issues:fetch ~set_status config selectors, statuses)

let test_manual_merge_rejects_invalid_and_duplicate_selectors () =
  with_temp_dir "symphony-manual-merge-selectors-" (fun root ->
      init_repo root "feature/start";
      let config = manual_merge_config root in
      let result, _ = run_manual_merge_test config [] [ "20,#20"; "symphony/task-21" ] in
      match result with
      | Ok _ -> Alcotest.fail "expected selector preflight errors"
      | Error errors ->
          Alcotest.(check int) "two selector errors" 2 (List.length errors);
          Alcotest.(check bool) "duplicate rejected" true
            (List.exists (fun error -> String.contains error 'd') errors);
          Alcotest.(check bool) "branch selector rejected" true
            (List.exists (fun error -> String.contains error '/') errors))

let test_manual_merge_fast_forwards_protected_trunk_and_updates_review_status () =
  with_temp_dir "symphony-manual-merge-protected-" (fun root ->
      init_repo root "main";
      let config = manual_merge_config root in
      let issue = Issue.empty ~id:"I20" ~identifier:"#20" ~title:"Twenty" ~state:"In review" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"main" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "manual.txt") "manual\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add manual.txt && git commit -q -m task");
      let result, statuses = run_manual_merge_test config [ issue ] [ "#20" ] in
      let report = match result with Ok report -> report | Error errors -> Alcotest.fail (String.concat "; " errors) in
      Alcotest.(check int) "merged" 1 report.merged;
      Alcotest.(check int) "already integrated" 0 report.already_integrated;
      Alcotest.(check bool) "merged file present" true (Sys.file_exists (Filename.concat root "manual.txt"));
      Alcotest.(check bool) "worktree removed" false (Sys.file_exists workspace.path);
      Alcotest.(check (list (pair string string))) "review status advanced" [ ("#20", "Done") ] (List.rev !statuses))

let test_manual_merge_blocks_unauthorized_protected_path_change () =
  with_temp_dir "symphony-manual-merge-protected-path-" (fun root ->
      init_repo root "feature/start";
      let config = manual_merge_config root |> with_protected_paths protected_patterns in
      let issue = Issue.empty ~id:"I20" ~identifier:"#20" ~title:"Twenty" ~state:"In review" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.mkdir_p (Filename.concat workspace.path "bin");
      commit_file ~cwd:workspace.path "bin/symphony.js" "changed\n" "task";
      let result, statuses = run_manual_merge_test config [ issue ] [ "#20" ] in
      (match result with
      | Ok _ -> Alcotest.fail "expected protected path preflight failure"
      | Error errors ->
          Alcotest.(check int) "one error" 1 (List.length errors);
          Alcotest.(check bool) "diagnostic names path" true
            (List.exists (fun error -> contains_substring error "bin/symphony.js") errors));
      Alcotest.(check bool) "protected file not merged" false (Sys.file_exists (Filename.concat root "bin/symphony.js"));
      Alcotest.(check (list (pair string string))) "no status updates" [] (List.rev !statuses))

let test_manual_merge_preflight_is_all_or_nothing () =
  with_temp_dir "symphony-manual-merge-preflight-" (fun root ->
      init_repo root "feature/start";
      let config = manual_merge_config root in
      let issue20 = Issue.empty ~id:"I20" ~identifier:"#20" ~title:"Twenty" ~state:"In review" in
      let issue21 = Issue.empty ~id:"I21" ~identifier:"#21" ~title:"Twenty one" ~state:"In review" in
      let workspace20 =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue20 with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace20.path "twenty.txt") "twenty\n";
      ignore (run_ok ~cwd:workspace20.path "task commit" "git add twenty.txt && git commit -q -m task");
      let workspace21 =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue21 with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace21.path "dirty.txt") "dirty\n";
      let result, statuses = run_manual_merge_test config [ issue20; issue21 ] [ "20,21" ] in
      (match result with
      | Ok _ -> Alcotest.fail "expected dirty Agent Worktree preflight failure"
      | Error errors ->
          Alcotest.(check int) "one preflight error" 1 (List.length errors);
          Alcotest.(check bool) "diagnostic names dirty path" true (List.exists (fun error -> String.contains error '/') errors));
      Alcotest.(check bool) "first branch not merged" false (Sys.file_exists (Filename.concat root "twenty.txt"));
      Alcotest.(check (list (pair string string))) "no status updates" [] (List.rev !statuses))

let test_manual_merge_accepts_cumulative_fast_forward_order () =
  with_temp_dir "symphony-manual-merge-chain-" (fun root ->
      init_repo root "feature/start";
      let config = manual_merge_config root in
      let issue20 = Issue.empty ~id:"I20" ~identifier:"#20" ~title:"Twenty" ~state:"In review" in
      let workspace20 =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue20 with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace20.path "twenty.txt") "twenty\n";
      ignore (run_ok ~cwd:workspace20.path "task commit" "git add twenty.txt && git commit -q -m task");
      let issue21 = Issue.empty ~id:"I21" ~identifier:"#21" ~title:"Twenty one" ~state:"In review" in
      ignore (run_ok ~cwd:root "create dependent branch" "git branch symphony/task-21 symphony/task-20");
      let workspace21 =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue21 with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace21.path "twenty-one.txt") "twenty-one\n";
      ignore (run_ok ~cwd:workspace21.path "task commit" "git add twenty-one.txt && git commit -q -m task");
      let result, _ = run_manual_merge_test config [ issue20; issue21 ] [ "#20"; "#21" ] in
      let report = match result with Ok report -> report | Error errors -> Alcotest.fail (String.concat "; " errors) in
      Alcotest.(check int) "merged both" 2 report.merged;
      Alcotest.(check bool) "first file present" true (Sys.file_exists (Filename.concat root "twenty.txt"));
      Alcotest.(check bool) "second file present" true (Sys.file_exists (Filename.concat root "twenty-one.txt")))

let test_manual_merge_cleans_already_integrated_terminal_task () =
  with_temp_dir "symphony-manual-merge-terminal-" (fun root ->
      init_repo root "feature/start";
      let config = manual_merge_config root in
      let issue = Issue.empty ~id:"I22" ~identifier:"#22" ~title:"Twenty two" ~state:"Done" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "done.txt") "done\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add done.txt && git commit -q -m task");
      ignore (run_ok ~cwd:root "pre-integrate" "git merge --ff-only symphony/task-22");
      let result, statuses = run_manual_merge_test config [ issue ] [ "22" ] in
      let report = match result with Ok report -> report | Error errors -> Alcotest.fail (String.concat "; " errors) in
      Alcotest.(check int) "already integrated" 1 report.already_integrated;
      Alcotest.(check bool) "worktree removed" false (Sys.file_exists workspace.path);
      Alcotest.(check (list (pair string string))) "terminal status unchanged" [] (List.rev !statuses))

let () =
  Alcotest.run "symphony-backend"
    [
      ("workflow", [ Alcotest.test_case "parse config" `Quick test_workflow_and_config ]);
      ("prompt", [ Alcotest.test_case "strict render" `Quick test_prompt_strict_rendering ]);
      ("workspace", [ Alcotest.test_case "sanitize and reuse" `Quick test_workspace_safety ]);
      ("launch", [ Alcotest.test_case "runs agent in agent worktree" `Quick test_shell_launch_runs_agent_in_agent_worktree ]);
      ( "runtime-home",
        [
          Alcotest.test_case "bootstrap is idempotent" `Quick test_bootstrap_idempotency_preserves_user_files;
          Alcotest.test_case "requires git repository root" `Quick test_root_validation;
          Alcotest.test_case "loads settings and prompt" `Quick test_settings_and_prompt_loading;
          Alcotest.test_case "loads runtime env file" `Quick test_runtime_env_loading;
          Alcotest.test_case "rejects repo URL in settings" `Quick test_repo_url_readiness_gap;
          Alcotest.test_case "writes ignore rules" `Quick test_runtime_gitignore_contents;
        ] );
      ( "config",
        [
          Alcotest.test_case "reject non-github tracker" `Quick test_invalid_tracker_kind;
          Alcotest.test_case "normalizes legacy codex app-server command" `Quick test_legacy_codex_app_server_command_normalizes_to_exec;
          Alcotest.test_case "derives kanban status order from transitions" `Quick test_project_status_order_uses_transition_flow;
          Alcotest.test_case "parses git policy and stage push" `Quick test_config_parses_git_policy_and_stage_push;
          Alcotest.test_case "validates stage concurrency policy" `Quick test_config_validates_stage_concurrency_policy;
          Alcotest.test_case "parses stage context snapshot and readiness" `Quick
            test_config_parses_stage_context_snapshot_and_readiness;
          Alcotest.test_case "parses allowed loop-start branch policy" `Quick
            test_config_parses_allowed_loop_start_branch_policy;
          Alcotest.test_case "parses stage goal and readiness" `Quick test_config_parses_stage_goal_and_readiness;
          Alcotest.test_case "disabled stage goal does not require codex goals" `Quick test_disabled_stage_goal_does_not_require_codex_goals;
          Alcotest.test_case "parses stage skill load and readiness" `Quick test_config_parses_stage_skill_load_and_readiness;
          Alcotest.test_case "stage goal requires codex exec stdin support" `Quick test_stage_goal_requires_codex_exec_stdin_support;
          Alcotest.test_case "stage goal live stdin probe" `Quick test_stage_goal_live_stdin_probe;
          Alcotest.test_case "requires pull request base branch when enabled" `Quick test_pull_request_base_branch_readiness_gap;
          Alcotest.test_case "requires pull request base branch to differ from loop start" `Quick
            test_pull_request_base_branch_must_differ_from_loop_start;
          Alcotest.test_case "allows task pull request base branch to equal loop start" `Quick
            test_task_pull_request_allows_base_branch_to_equal_loop_start;
          Alcotest.test_case "checks allowed loop-start branch readiness" `Quick
            test_allowed_loop_start_branch_readiness;
        ] );
      ( "runtime-state",
        [
          Alcotest.test_case "exposes running issue details" `Quick test_runtime_state_exposes_running_issue_details;
          Alcotest.test_case "parses ordered queue identifiers" `Quick test_ordered_queue_parses_cli_identifiers;
          Alcotest.test_case "exposes ordered queue" `Quick test_runtime_state_exposes_ordered_queue;
          Alcotest.test_case "resumes same ordered queue state" `Quick test_orchestrator_resumes_same_ordered_queue_state;
          Alcotest.test_case "exposes goal usage when available" `Quick test_runtime_state_exposes_goal_usage_when_available;
        ] );
      ( "server",
        [
          Alcotest.test_case "handles websocket upgrade and initial snapshot" `Quick test_websocket_accept_and_initial_snapshot;
          Alcotest.test_case "broadcasts after state change" `Quick test_websocket_broadcast_after_state_change;
          Alcotest.test_case "serves readiness live snapshot and diagnostic state" `Quick test_websocket_readiness_snapshot_and_http_state;
        ] );
      ( "cli",
        [
          Alcotest.test_case "selects terminal or web mode" `Quick test_cli_mode_selection;
          Alcotest.test_case "detects update Install Prefix" `Quick test_update_detects_npm_install_prefix;
          Alcotest.test_case "detects prefix from package launcher" `Quick
            test_update_detects_prefix_from_package_launcher;
          Alcotest.test_case "rejects source checkout updates" `Quick test_update_rejects_source_checkout_launcher;
          Alcotest.test_case "prefers launcher environment" `Quick test_update_prefers_launcher_env;
          Alcotest.test_case "requires --yes when non-interactive" `Quick test_update_noninteractive_requires_yes_before_install;
          Alcotest.test_case "already current skips confirmation" `Quick test_update_already_current_does_not_require_yes;
          Alcotest.test_case "discovery failure does not install" `Quick test_update_discovery_failure_does_not_install;
          Alcotest.test_case "installs and validates update" `Quick test_update_installs_and_validates_with_yes;
          Alcotest.test_case "install failure does not validate" `Quick test_update_install_failure_does_not_validate;
          Alcotest.test_case "fails validation mismatch" `Quick test_update_validation_failure_is_not_success;
          Alcotest.test_case "ready terminal mode runs orchestrator" `Quick test_ready_terminal_mode_runs_orchestrator;
        ] );
      ( "github-tracker",
        [
          Alcotest.test_case "parses project status field" `Quick test_github_project_field_parsing;
          Alcotest.test_case "filters active states" `Quick test_github_active_state_filtering;
          Alcotest.test_case "ignores empty project field values" `Quick test_github_empty_project_field_values_are_ignored;
          Alcotest.test_case "parses status update metadata" `Quick test_github_status_metadata_parsing;
          Alcotest.test_case "normalizes API errors" `Quick test_github_api_error_normalization;
        ] );
      ( "orchestrator",
        [
          Alcotest.test_case "enforces dispatch limits" `Quick test_orchestrator_dispatch_limits;
          Alcotest.test_case "dispatches all available stage slots" `Quick
            test_orchestrator_stage_capacity_dispatches_all_available_slots;
          Alcotest.test_case "does not spawn idle stage agents" `Quick
            test_orchestrator_stage_capacity_does_not_spawn_idle_agents;
          Alcotest.test_case "respects lower global cap with stage caps" `Quick
            test_orchestrator_stage_capacity_respects_lower_global_cap;
          Alcotest.test_case "prevents duplicate stage dispatch" `Quick
            test_orchestrator_stage_capacity_prevents_duplicate_dispatch;
          Alcotest.test_case "skips full stage capacity in ordered queue" `Quick
            test_orchestrator_stage_capacity_skips_full_ordered_stage;
          Alcotest.test_case "dispatches ordered queue only in order" `Quick test_orchestrator_dispatches_ordered_queue_only_in_order;
          Alcotest.test_case "keeps ordered queue stage handoffs pending" `Quick
            test_ordered_queue_keeps_stage_handoffs_pending;
          Alcotest.test_case "revives completed ordered queue entries in active states" `Quick
            test_ordered_queue_revives_persisted_completed_active_entries;
          Alcotest.test_case "pauses tracker after rate limit" `Quick test_orchestrator_pauses_tracker_after_rate_limit;
          Alcotest.test_case "does not dispatch terminal issues" `Quick test_orchestrator_does_not_dispatch_terminal_issues;
          Alcotest.test_case "retries failed agents" `Quick test_orchestrator_retries_failed_agent;
          Alcotest.test_case "moves status to review on success" `Quick test_orchestrator_moves_status_to_review_on_success;
          Alcotest.test_case "uses stage agent prompt and status" `Quick test_orchestrator_uses_stage_agent_prompt_and_status;
          Alcotest.test_case "prepends stage goal handoff" `Quick test_orchestrator_prepends_stage_goal_handoff;
          Alcotest.test_case "skips stage goal handoff when disabled" `Quick test_orchestrator_skips_stage_goal_when_disabled;
          Alcotest.test_case "truncates agent context snapshot" `Quick test_orchestrator_truncates_agent_context_snapshot;
          Alcotest.test_case "parses goal usage output" `Quick test_parse_goal_usage_from_codex_output;
          Alcotest.test_case "parses goal usage variants" `Quick test_parse_goal_usage_variants_and_ignores_invalid;
          Alcotest.test_case "parses nested goal usage fields" `Quick test_parse_goal_usage_nested_usage_fields;
          Alcotest.test_case "commits stage before success status" `Quick test_orchestrator_commits_stage_before_success_status;
          Alcotest.test_case "renders stage commit classification messages" `Quick
            test_stage_commit_classification_renders_messages;
          Alcotest.test_case "retries when success status move fails" `Quick test_orchestrator_retries_when_success_status_move_fails;
          Alcotest.test_case "retries push failure before success status"
            `Quick test_orchestrator_retries_push_failure_before_success_status;
          Alcotest.test_case "stage commit requires code changes" `Quick test_stage_commit_requires_code_changes;
          Alcotest.test_case "protected path policy matches files directories and globs" `Quick
            test_protected_path_policy_matches_files_directories_and_globs;
          Alcotest.test_case "stage commit blocks unauthorized protected paths" `Quick
            test_stage_commit_blocks_unauthorized_protected_path_change;
          Alcotest.test_case "stage commit blocks deleted and renamed protected paths" `Quick
            test_stage_commit_blocks_deleted_and_renamed_protected_paths;
          Alcotest.test_case "stage commit allows authorized protected paths" `Quick
            test_stage_commit_allows_authorized_protected_path_change;
          Alcotest.test_case "moves unauthorized protected path work to attention" `Quick
            test_orchestrator_moves_unauthorized_protected_stage_to_attention;
          Alcotest.test_case "does not retry empty required commits" `Quick test_orchestrator_does_not_retry_empty_commit;
          Alcotest.test_case "notifies repeated state mutations" `Quick test_orchestrator_notifies_each_state_mutation;
          Alcotest.test_case "parses final output when size was already seen"
            `Quick test_orchestrator_parses_final_output_when_size_was_already_seen;
          Alcotest.test_case "parses final output before timeout retry"
            `Quick test_orchestrator_parses_final_output_before_timeout_retry;
          Alcotest.test_case "preserves goal usage on blocked issue error"
            `Quick test_orchestrator_preserves_goal_usage_on_blocked_issue_error;
          Alcotest.test_case "startup reconciliation merges completed worktrees in order"
            `Quick test_startup_reconciliation_merges_completed_worktrees_in_order;
          Alcotest.test_case "startup reconciliation cleans already-contained task branches"
            `Quick test_startup_reconciliation_already_contained_applies_cleanup_without_status_change;
          Alcotest.test_case "startup reconciliation moves unsafe candidates to attention"
            `Quick test_startup_reconciliation_moves_unsafe_candidates_to_attention;
          Alcotest.test_case "startup reconciliation blocks unauthorized protected paths"
            `Quick test_startup_reconciliation_blocks_unauthorized_protected_path_change;
          Alcotest.test_case "startup reconciliation updates task branch before fast-forward"
            `Quick test_startup_reconciliation_updates_task_branch_before_fast_forward;
          Alcotest.test_case "startup reconciliation detects wrong and missing branches"
            `Quick test_startup_reconciliation_detects_wrong_and_missing_task_branch;
          Alcotest.test_case "startup reconciliation blocks when loop-start is dirty"
            `Quick test_startup_reconciliation_blocks_when_loop_start_dirty;
          Alcotest.test_case "startup reconciliation ignores branches without worktrees"
            `Quick test_startup_reconciliation_ignores_retained_branch_without_worktree;
          Alcotest.test_case "creates task worktree and branch" `Quick test_orchestrator_creates_task_worktree_and_branch;
          Alcotest.test_case "opens batch pull request once when idle" `Quick test_orchestrator_opens_batch_pull_request_once_when_idle;
          Alcotest.test_case "opens batch pull request on review status" `Quick
            test_orchestrator_opens_batch_pull_request_on_review_status;
          Alcotest.test_case "opens task pull request on review status" `Quick
            test_orchestrator_opens_task_pull_request_on_review_status_from_protected_loop_start;
          Alcotest.test_case "opens task pull request before auto-merge cleanup" `Quick
            test_task_pull_request_opens_before_auto_merge_cleanup;
          Alcotest.test_case "retries failed batch pull request handoff" `Quick test_orchestrator_retries_batch_pull_request_handoff_failure;
          Alcotest.test_case "blocks batch pull request on attention" `Quick test_orchestrator_blocks_batch_pull_request_on_attention;
          Alcotest.test_case "reuses existing batch pull request" `Quick test_batch_pull_request_handoff_reuses_existing_pr;
          Alcotest.test_case "requires clean loop-start worktree" `Quick test_orchestrator_requires_clean_loop_start_for_new_worktree;
          Alcotest.test_case "blocks disallowed loop-start before side effects" `Quick
            test_orchestrator_blocks_disallowed_loop_start_before_side_effects;
          Alcotest.test_case "moves conflicting stage commit classification to attention" `Quick
            test_conflicting_stage_commit_classification_moves_attention_without_commit;
          Alcotest.test_case "reuses existing task branch on restart" `Quick test_orchestrator_reuses_existing_task_branch_on_restart;
          Alcotest.test_case "prunes missing registered worktree" `Quick
            test_orchestrator_prunes_missing_registered_worktree;
          Alcotest.test_case "reuses worktree for existing in-progress task"
            `Quick test_orchestrator_reuses_worktree_for_existing_in_progress_task_before_launch;
          Alcotest.test_case "rejects existing non-worktree workspace" `Quick test_orchestrator_rejects_existing_non_worktree_workspace;
          Alcotest.test_case "pushes task branch after stage commit" `Quick test_stage_commit_pushes_task_branch;
          Alcotest.test_case "fast-forwards task branch and removes worktree" `Quick test_auto_merge_fast_forwards_and_removes_worktree;
          Alcotest.test_case "can remove task branch after merge" `Quick test_cleanup_can_remove_task_branch_after_merge;
          Alcotest.test_case "skips auto-merge on protected trunk" `Quick test_auto_merge_skips_protected_trunk_branch;
          Alcotest.test_case "integrates parallel unrelated task branches"
            `Quick test_auto_merge_integrates_parallel_unrelated_task_branches;
          Alcotest.test_case "moves merge failures to human attention" `Quick test_auto_merge_failure_moves_human_attention;
        ] );
      ( "manual-merge",
        [
          Alcotest.test_case "rejects invalid and duplicate selectors" `Quick
            test_manual_merge_rejects_invalid_and_duplicate_selectors;
          Alcotest.test_case "fast-forwards protected trunk and updates review status" `Quick
            test_manual_merge_fast_forwards_protected_trunk_and_updates_review_status;
          Alcotest.test_case "blocks unauthorized protected paths" `Quick
            test_manual_merge_blocks_unauthorized_protected_path_change;
          Alcotest.test_case "preflight is all or nothing" `Quick test_manual_merge_preflight_is_all_or_nothing;
          Alcotest.test_case "accepts cumulative fast-forward order" `Quick
            test_manual_merge_accepts_cumulative_fast_forward_order;
          Alcotest.test_case "cleans already integrated terminal task" `Quick
            test_manual_merge_cleans_already_integrated_terminal_task;
        ] );
    ]
