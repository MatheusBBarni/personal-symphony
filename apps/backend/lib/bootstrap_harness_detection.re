type auth_signal =
  | Authenticated
  | Auth_missing
  | Auth_unknown
  | Auth_not_checked;

type status_signal =
  | Status_succeeded
  | Status_failed
  | Status_unknown
  | Status_not_checked;

type readiness_confidence =
  | Install_and_auth
  | Install_and_status
  | Executable_only
  | Not_ready
  | Nonselectable;

type guidance_category =
  | Selected_harness
  | No_usable_harness
  | Missing_install
  | Missing_auth
  | Missing_status
  | Nonselectable_harness;

type settings_mode =
  | Generate_missing_runtime_settings
  | Preserve_existing_runtime_settings;

type harness_definition = {
  name: string,
  kind: string,
  executable: string,
  display_name: string,
  selectable: bool,
  requires_auth: bool,
  requires_status: bool,
};

type probe = {
  executable_available: string => bool,
  auth_signal: harness_definition => auth_signal,
  status_signal: harness_definition => status_signal,
};

type harness_status = {
  name: string,
  kind: string,
  executable: string,
  display_name: string,
  executable_available: bool,
  auth_signal,
  status_signal,
  selectable: bool,
  probed_usable: bool,
  auto_selectable: bool,
  readiness_confidence,
  remediation: string,
};

type guidance_item = {
  category: guidance_category,
  harness_name: option(string),
  message: string,
};

type detection_result = {
  supported: list(harness_status),
  selected: option(harness_status),
  nonselectable: list(harness_status),
  guidance: list(guidance_item),
  settings_mode,
};

let supported_definitions = [
  {
    name: "codex",
    kind: "codex",
    executable: "codex",
    display_name: "Codex",
    selectable: true,
    requires_auth: false,
    requires_status: false,
  },
  {
    name: "claude",
    kind: "claude",
    executable: "claude",
    display_name: "Claude Code",
    selectable: true,
    requires_auth: true,
    requires_status: false,
  },
  {
    name: "cursor",
    kind: "cursor",
    executable: "cursor-agent",
    display_name: "Cursor CLI",
    selectable: true,
    requires_auth: false,
    requires_status: true,
  },
  {
    name: "cursor-force",
    kind: "cursor",
    executable: "cursor-agent",
    display_name: "Cursor CLI force mode",
    selectable: false,
    requires_auth: false,
    requires_status: true,
  },
  {
    name: "pi",
    kind: "pi",
    executable: "pi",
    display_name: "PI",
    selectable: true,
    requires_auth: true,
    requires_status: false,
  },
];

/* Stronger install plus auth/status evidence wins before Codex executable-only evidence. */
let selection_priority = ["claude", "cursor", "pi", "codex"];

let auth_signal_to_string =
  fun
  | Authenticated => "authenticated"
  | Auth_missing => "missing_auth"
  | Auth_unknown => "auth_unknown"
  | Auth_not_checked => "auth_not_checked";

let status_signal_to_string =
  fun
  | Status_succeeded => "status_succeeded"
  | Status_failed => "status_failed"
  | Status_unknown => "status_unknown"
  | Status_not_checked => "status_not_checked";

let readiness_confidence_to_string =
  fun
  | Install_and_auth => "install_and_auth"
  | Install_and_status => "install_and_status"
  | Executable_only => "executable_only"
  | Not_ready => "not_ready"
  | Nonselectable => "nonselectable";

let guidance_category_to_string =
  fun
  | Selected_harness => "selected_harness"
  | No_usable_harness => "no_usable_harness"
  | Missing_install => "missing_install"
  | Missing_auth => "missing_auth"
  | Missing_status => "missing_status"
  | Nonselectable_harness => "nonselectable_harness";

let settings_mode_to_string =
  fun
  | Generate_missing_runtime_settings => "generate_missing_runtime_settings"
  | Preserve_existing_runtime_settings => "preserve_existing_runtime_settings";

let auth_satisfied = (definition: harness_definition, auth_signal) =>
  !definition.requires_auth || auth_signal == Authenticated;

let status_satisfied = (definition: harness_definition, status_signal) =>
  !definition.requires_status || status_signal == Status_succeeded;

let probed_usable =
    (
      definition: harness_definition,
      executable_available,
      auth_signal,
      status_signal,
    ) =>
  executable_available
  && auth_satisfied(definition, auth_signal)
  && status_satisfied(definition, status_signal);

let readiness_confidence =
    (
      definition: harness_definition,
      executable_available,
      auth_signal,
      status_signal,
      probed_usable,
    ) =>
  if (!definition.selectable) {
    Nonselectable;
  } else if (!probed_usable) {
    Not_ready;
  } else if (definition.requires_auth && auth_signal == Authenticated) {
    Install_and_auth;
  } else if (definition.requires_status && status_signal == Status_succeeded) {
    Install_and_status;
  } else if (executable_available) {
    Executable_only;
  } else {
    Not_ready;
  };

let remediation =
    (
      definition: harness_definition,
      executable_available,
      auth_signal,
      status_signal,
      probed_usable,
    ) =>
  if (!definition.selectable) {
    definition.name
    ++ " is an explicit Runtime Settings Harness definition and is never selected automatically.";
  } else if (!executable_available) {
    "Install "
    ++ definition.display_name
    ++ " so the "
    ++ definition.executable
    ++ " executable is available.";
  } else if (definition.requires_auth && auth_signal != Authenticated) {
    "Authenticate "
    ++ definition.display_name
    ++ " without storing secrets in Runtime Settings.";
  } else if (definition.requires_status && status_signal != Status_succeeded) {
    "Confirm the "
    ++ definition.display_name
    ++ " status probe succeeds without exposing credentials.";
  } else if (probed_usable) {
    "Runtime readiness still validates the selected Agent Harness before dispatch.";
  } else {
    "Review "
    ++ definition.display_name
    ++ " install and authentication state.";
  };

let status_of_definition = (probe: probe, definition: harness_definition) => {
  let executable_available =
    probe.executable_available(definition.executable);
  let auth_signal =
    if (definition.requires_auth) {
      probe.auth_signal(definition);
    } else {
      Auth_not_checked;
    };
  let status_signal =
    if (definition.requires_status) {
      probe.status_signal(definition);
    } else {
      Status_not_checked;
    };
  let probed_usable =
    probed_usable(
      definition,
      executable_available,
      auth_signal,
      status_signal,
    );
  let auto_selectable = definition.selectable && probed_usable;
  let readiness_confidence =
    readiness_confidence(
      definition,
      executable_available,
      auth_signal,
      status_signal,
      probed_usable,
    );
  let remediation =
    remediation(
      definition,
      executable_available,
      auth_signal,
      status_signal,
      probed_usable,
    );
  {
    name: definition.name,
    kind: definition.kind,
    executable: definition.executable,
    display_name: definition.display_name,
    executable_available,
    auth_signal,
    status_signal,
    selectable: definition.selectable,
    probed_usable,
    auto_selectable,
    readiness_confidence,
    remediation,
  };
};

let status_named = (statuses: list(harness_status), name) =>
  List.find_opt(status => status.name == name, statuses);

let select_status = (statuses: list(harness_status)) =>
  selection_priority
  |> List.filter_map(name =>
       switch (status_named(statuses, name)) {
       | Some(status) when status.auto_selectable => Some(status)
       | _ => None
       }
     )
  |> (
    fun
    | [selected, ..._] => Some(selected)
    | [] => None
  );

let missing_category = (status: harness_status) =>
  if (!status.executable_available) {
    Missing_install;
  } else {
    switch (status.auth_signal, status.status_signal) {
    | (Auth_missing, _)
    | (Auth_unknown, _) => Missing_auth
    | (_, Status_failed)
    | (_, Status_unknown) => Missing_status
    | _ => No_usable_harness
    };
  };

let selected_guidance = (status: harness_status) => {
  category: Selected_harness,
  harness_name: Some(status.name),
  message:
    "Selected "
    ++ status.name
    ++ " from local Bootstrap detection; runtime readiness remains the dispatch authority.",
};

let missing_guidance = (status: harness_status) => {
  category: missing_category(status),
  harness_name: Some(status.name),
  message: status.remediation,
};

let no_usable_guidance = {
  category: No_usable_harness,
  harness_name: None,
  message: "No supported usable Agent Harness was found by local Bootstrap detection.",
};

let nonselectable_guidance = (status: harness_status) => {
  category: Nonselectable_harness,
  harness_name: Some(status.name),
  message: status.remediation,
};

let guidance = (statuses: list(harness_status), selected, nonselectable) => {
  let primary =
    switch (selected) {
    | Some(status) => [selected_guidance(status)]
    | None => [
        no_usable_guidance,
        ...statuses
           |> List.filter(status =>
                status.selectable && !status.probed_usable
              )
           |> List.map(missing_guidance),
      ]
    };
  primary @ List.map(nonselectable_guidance, nonselectable);
};

let detect = (~settings_mode=Generate_missing_runtime_settings, ~probe, ()) => {
  let supported =
    List.map(status_of_definition(probe), supported_definitions);
  let selected = select_status(supported);
  let nonselectable = List.filter(status => !status.selectable, supported);
  let guidance = guidance(supported, selected, nonselectable);
  {
    supported,
    selected,
    nonselectable,
    guidance,
    settings_mode,
  };
};

let guidance_lines = result =>
  List.map(item => item.message, result.guidance);
