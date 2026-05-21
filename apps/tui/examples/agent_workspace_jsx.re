open Tui;
open Tui.Jsx;

module J = Tui.Jsx;

let sessions = [
  <SectionTitle title="Sessions" />,
  <NavItem active=true meta="now" label="ocaml-tui" />,
  <NavItem meta="12m" label="renderer-bugs" />,
  <NavItem meta="1h" label="release-notes" />,
  <NavItem meta="2h" label="perf-pass" />,
  <SectionTitle tone=Components.Info title="Workspaces" />,
  <NavItem meta="main" label="opencaml" />,
  <NavItem meta="dirty" label="demo-kit" />,
];

let transcript = [
  <Message
    tone=Components.Info
    author="User"
    time="14:12"
    body="Build components so people can recreate this kind of terminal UI."
  />,
  <Message
    tone=Components.Success
    author="Assistant"
    time="14:13"
    body="Added dashboard primitives: panels, badges, metric cards, tables, logs, tabs, and command bars."
  />,
  <Message
    tone=Components.Accent
    author="Assistant"
    time="14:16"
    body="Now adding workspace primitives for chat-heavy layouts: side navigation, messages, timelines, and a composer."
  />,
];

let activity = [
  <Timeline
    entries=[
      (Components.Success, "tests", "10 passing"),
      (Components.Info, "build", "dune build @all"),
      (Components.Warning, "review", "image parity needs source pixels"),
      (Components.Accent, "example", "agent_workspace.exe"),
    ]
  />,
  <Panel title="Context">
    <KeyValue
      label_width=9
      pairs=[
        ("branch", "no git repo"),
        ("package", "tui"),
        ("layout", "Toffee flex"),
        ("target", "132x38"),
      ]
    />
  </Panel>,
];

let root =
  J.AppShell.make(
    ~title="Agent Workspace",
    ~subtitle="message-first terminal interface",
    ~badges=[
      (Components.Success, "online"),
      (Components.Accent, "model"),
      (Components.Info, "tools"),
    ],
    ~footer_items=[
      ("q", "uit"),
      ("n", "ew"),
      ("/", "search"),
      ("?", "help"),
      ("Tab", "focus"),
    ],
    ~children=[
      J.Split.make(
        ~left_width=28,
        ~left=[
          J.Panel.make(
            ~title="Navigator",
            ~style=Style.(make(~height=Percent(1.), ())),
            ~children=sessions,
            (),
          ),
        ],
        ~right=[
          J.Box.make(
            ~style=
              Style.(
                make(~flex_direction=Row, ~gap=1, ~height=Percent(1.), ())
              ),
            ~children=[
              J.Panel.make(
                ~title="Conversation",
                ~style=Style.(make(~flex_grow=1., ~height=Percent(1.), ())),
                ~children=[
                  J.ScrollBox.make(
                    ~style=Style.(make(~flex_grow=1., ())),
                    ~children=transcript,
                    (),
                  ),
                  J.Composer.make(
                    ~placeholder="Ask for code, tests, or a review",
                    (),
                  ),
                ],
                (),
              ),
              J.Panel.make(
                ~title="Run State",
                ~tone=Components.Info,
                ~style=
                  Style.(make(~width=Cells(36), ~height=Percent(1.), ())),
                ~children=activity,
                (),
              ),
            ],
            (),
          ),
        ],
        (),
      ),
    ],
    (),
  );

let () = {
  let renderer = Renderer.create(~width=132, ~height=38, root);
  print_endline(Renderer.render_to_string(renderer));
};
