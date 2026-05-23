type json = Yojson.Safe.t;

type selected_harness = {
  name: string,
  kind: string,
};

type settings_result = {
  json,
  selected_harness: option(selected_harness),
};

type logical_agent_default = {
  name: string,
  fallback_harness: string,
  model: string,
  reasoning_effort: string,
};

let obj = fields => `Assoc(fields);
let str = value => `String(value);
let int = value => `Int(value);
let bool = value => `Bool(value);
let list = values => `List(values);
let strings = values => list(List.map(value => str(value), values));

let supported_harness_names = [
  "codex",
  "claude",
  "cursor",
  "cursor-force",
  "pi",
];

let routeable_selected_harness = result =>
  switch (result.Bootstrap_harness_detection.selected) {
  | Some(status)
      when
        status.Bootstrap_harness_detection.auto_selectable
        && List.mem(
             status.Bootstrap_harness_detection.name,
             supported_harness_names,
           )
        && status.Bootstrap_harness_detection.name != "cursor-force" =>
    Some({
      name: status.Bootstrap_harness_detection.name,
      kind: status.Bootstrap_harness_detection.kind,
    })
  | _ => None
  };

let loop = (~enabled, ~command) =>
  obj([("enabled", bool(enabled)), ("command", str(command))]);

let harness = (~kind, ~command, ~loop_enabled, ~loop_command) =>
  obj([
    ("kind", str(kind)),
    ("command", str(command)),
    ("loop", loop(~enabled=loop_enabled, ~command=loop_command)),
  ]);

let harnesses =
  obj([
    (
      "codex",
      harness(
        ~kind="codex",
        ~command=Config.default_codex_command,
        ~loop_enabled=true,
        ~loop_command=Config.default_codex_loop_command,
      ),
    ),
    (
      "claude",
      harness(
        ~kind="claude",
        ~command=Config.default_claude_command,
        ~loop_enabled=false,
        ~loop_command="",
      ),
    ),
    (
      "cursor",
      harness(
        ~kind="cursor",
        ~command=Config.default_cursor_command,
        ~loop_enabled=false,
        ~loop_command="",
      ),
    ),
    (
      "cursor-force",
      harness(
        ~kind="cursor",
        ~command=
          "cursor-agent -p --force --model <model> --output-format stream-json",
        ~loop_enabled=false,
        ~loop_command="",
      ),
    ),
    (
      "pi",
      harness(
        ~kind="pi",
        ~command=Config.default_pi_command,
        ~loop_enabled=false,
        ~loop_command="",
      ),
    ),
  ]);

let logical_agent_defaults = [
  {
    name: "planner",
    fallback_harness: "codex",
    model: Config.default_model,
    reasoning_effort: "medium",
  },
  {
    name: "engineer",
    fallback_harness: "claude",
    model: "opus-4.7",
    reasoning_effort: "xhigh",
  },
  {
    name: "reviewer",
    fallback_harness: "pi",
    model: "openai-codex/gpt-5.5",
    reasoning_effort: "high",
  },
];

let logical_agent =
    (
      selected_harness: option(selected_harness),
      default: logical_agent_default,
    ) => {
  let harness =
    switch (selected_harness) {
    | Some(selected) => selected.name
    | None => default.fallback_harness
    };
  let override_fields =
    switch (selected_harness) {
    | Some(_) => []
    | None => [
        ("model", str(default.model)),
        ("reasoningEffort", str(default.reasoning_effort)),
      ]
    };
  (
    default.name,
    obj(
      [("harness", str(harness))]
      @ override_fields
      @ [
        ("turnTimeoutMs", int(3600000)),
        ("readTimeoutMs", int(5000)),
        ("stallTimeoutMs", int(300000)),
      ],
    ),
  );
};

let agents = (selected_harness: option(selected_harness)) =>
  obj(
    List.map(
      default => logical_agent(selected_harness, default),
      logical_agent_defaults,
    ),
  );

let commit = (~enabled, ~type_) =>
  obj([
    ("enabled", bool(enabled)),
    ("type", str(type_)),
    ("message", str(Config.default_commit_message)),
    ("push", bool(false)),
  ]);

let stage =
    (
      ~states,
      ~agent,
      ~start_status,
      ~success_status,
      ~retry_status,
      ~commit_enabled,
      ~commit_type,
    ) => {
  let status_fields =
    switch (start_status) {
    | Some(status) => [("startStatus", str(status))]
    | None => []
    };
  obj(
    [
      ("states", strings(states)),
      ("agent", str(agent)),
      ("skills", list([])),
    ]
    @ status_fields
    @ [
      ("successStatus", str(success_status)),
      ("retryStatus", str(retry_status)),
      ("goal", obj([("enabled", bool(false))])),
      ("commit", commit(~enabled=commit_enabled, ~type_=commit_type)),
    ],
  );
};

let json = result => {
  let selected_harness = routeable_selected_harness(result);
  obj([
    (
      "tracker",
      obj([
        ("kind", str("github")),
        ("owner", str("your-org")),
        ("repo", str("your-repo")),
        ("projectNumber", int(1)),
        ("apiKeyEnv", str("GITHUB_TOKEN")),
      ]),
    ),
    (
      "project",
      obj([
        ("statusField", str("Status")),
        ("readyStatus", str(Config.default_ready_status)),
        (
          "activeStates",
          strings([
            "Backlog",
            "Todo",
            "To-Do",
            "In progress",
            "In Progress",
            "In review",
          ]),
        ),
        ("terminalStates", strings(["Done", "Closed", "Cancelled"])),
        ("startStatus", str(Config.default_dispatch_status)),
        ("reviewStatus", str(Config.default_review_status)),
        ("retryStatus", str(Config.default_retry_status)),
        ("ensureStatuses", bool(true)),
      ]),
    ),
    ("polling", obj([("intervalMs", int(30000))])),
    ("workspace", obj([("root", str(".symphony/workspaces"))])),
    (
      "sandbox",
      obj([
        ("enabled", bool(false)),
        ("type", str("docker")),
        ("image", str("ghcr.io/your-org/symphony-agent:latest")),
        ("bootstrapCommands", list([])),
        ("persistent", bool(true)),
        ("networkEnabled", bool(false)),
        ("cpuLimit", int(2)),
        ("memoryMb", int(4096)),
      ]),
    ),
    ("harnesses", harnesses),
    ("agents", agents(selected_harness)),
    (
      "git",
      obj([
        ("taskBranchPrefix", str("symphony/task-")),
        ("protectedTrunkBranches", strings(["main", "master"])),
        ("autoMerge", bool(true)),
        ("mergeAttentionStatus", str(Config.default_merge_attention_status)),
        (
          "cleanup",
          obj([
            ("removeWorktreeAfterMerge", bool(true)),
            ("keepTaskBranch", bool(true)),
          ]),
        ),
      ]),
    ),
    (
      "pullRequest",
      obj([
        ("enabled", bool(false)),
        ("mode", str("batch")),
        ("baseBranch", str("main")),
        ("title", str("Symphony batch from <head_branch>")),
        (
          "body",
          str(
            "Opened automatically by Symphony after orchestration became idle.",
          ),
        ),
      ]),
    ),
    (
      "stageAgents",
      obj([
        ("enabled", bool(true)),
        ("root", str(".symphony/agents")),
        ("defaultAgent", str("engineer")),
        (
          "stages",
          list([
            stage(
              ~states=["Backlog"],
              ~agent="planner",
              ~start_status=None,
              ~success_status="To-Do",
              ~retry_status="Backlog",
              ~commit_enabled=false,
              ~commit_type="feature",
            ),
            stage(
              ~states=["Todo", "To-Do", "In progress", "In Progress"],
              ~agent="engineer",
              ~start_status=Some("In progress"),
              ~success_status="In review",
              ~retry_status="To-Do",
              ~commit_enabled=true,
              ~commit_type="feature",
            ),
            stage(
              ~states=["In review", "In Review"],
              ~agent="reviewer",
              ~start_status=None,
              ~success_status="Done",
              ~retry_status="In progress",
              ~commit_enabled=false,
              ~commit_type="refactor",
            ),
          ]),
        ),
      ]),
    ),
    (
      "agent",
      obj([
        ("maxConcurrentAgents", int(2)),
        ("maxTurns", int(10)),
        ("maxRetryBackoffMs", int(300000)),
      ]),
    ),
    ("server", obj([("port", int(8080))])),
  ]);
};

let build = result => {
  let selected_harness = routeable_selected_harness(result);
  {
    json: json(result),
    selected_harness,
  };
};

let to_yojson = result => build(result).json;

let to_string = result =>
  Yojson.Safe.pretty_to_string(to_yojson(result)) ++ "\n";
