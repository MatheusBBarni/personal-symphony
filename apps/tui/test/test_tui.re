open Tui;

module J = Tui.Jsx;

let contains_sub = (haystack, needle) => {
  let haystack_len = String.length(haystack);
  let needle_len = String.length(needle);
  let rec loop = index =>
    index
    + needle_len <= haystack_len
    && (String.sub(haystack, index, needle_len) == needle || loop(index + 1));

  needle_len == 0 || loop(0);
};

let render_node = (~width, ~height, ~node) =>
  Renderer.render_to_string(Renderer.create(~width, ~height, node));

let plain_snapshot = () => {
  let root =
    box(
      ~style=
        Style.(
          make(
            ~border=Single,
            ~title="Hi",
            ~padding=spacing_all(1),
            ~width=Cells(12),
            ~height=Cells(5),
            (),
          )
        ),
      [text("OCaml")],
    );

  let renderer = Renderer.create(~width=12, ~height=5, root);
  Alcotest.(check(string))(
    "box snapshot",
    "┌─ Hi ─────┐\n│          │\n│ OCaml    │\n│          │\n└──────────┘",
    Renderer.render_to_string(renderer),
  );
};

let flex_row_layout = () => {
  let left =
    box(
      ~style=Style.(make(~flex_grow=1., ~bg=Color.ansi(1), ())),
      [text("L")],
    );
  let right = box(~style=Style.(make(~width=Cells(5), ())), [text("R")]);
  let root =
    box(
      ~style=
        Style.(
          make(~flex_direction=Row, ~width=Cells(10), ~height=Cells(1), ())
        ),
      [left, right],
    );
  let renderer = Renderer.create(~width=10, ~height=1, root);
  Alcotest.(check(string))(
    "row text placement",
    "L    R    ",
    Renderer.render_to_string(renderer),
  );
};

let rich_text_inherits_node_paint = () => {
  let root =
    rich_text(
      ~style=
        Style.(
          make(
            ~fg=Color.ansi(1),
            ~bg=Color.ansi(2),
            ~attrs=[Attr.Bold],
            (),
          )
        ),
      [
        Span.make(
          ~style=
            Style.(make(~fg=Color.ansi(3), ~attrs=[Attr.Underline], ())),
          "X",
        ),
      ],
    );
  let renderer = Renderer.create(~width=2, ~height=1, root);
  let surface = Renderer.request_render(renderer);
  switch (Surface.get(surface, ~x=0, ~y=0)) {
  | Some(cell) =>
    Alcotest.(check(bool))(
      "span keeps explicit fg",
      true,
      cell.Surface.style.Style.fg == Some(Color.ansi(3)),
    );
    Alcotest.(check(bool))(
      "span inherits node bg",
      true,
      cell.style.bg == Some(Color.ansi(2)),
    );
    Alcotest.(check(bool))(
      "span inherits parent attrs",
      true,
      Attr.mem(Attr.Bold, cell.style.attrs),
    );
    Alcotest.(check(bool))(
      "span keeps child attrs",
      true,
      Attr.mem(Attr.Underline, cell.style.attrs),
    );
  | None => Alcotest.fail("missing rendered cell")
  };
};

let jsx_text_matches_component_text = () => {
  let direct = Components.text("Hello");
  let wrapped = Tui.Jsx.Text.make(~value="Hello", ());
  let render = node =>
    Renderer.render_to_string(Renderer.create(~width=8, ~height=1, node));

  Alcotest.(check(string))(
    "visible text",
    render(direct),
    render(wrapped),
  );
  switch (wrapped.kind) {
  | Text(_) => ()
  | _ => Alcotest.fail("jsx text did not return a text node")
  };
};

let jsx_box_renders_explicit_text_children = () => {
  let style = Style.(make(~width=Cells(12), ~height=Cells(1), ()));
  let direct = Components.box(~style, [Components.text("Child")]);
  let wrapped =
    Tui.Jsx.Box.make(
      ~style,
      ~children=[Tui.Jsx.Text.make(~value="Child", ())],
      (),
    );
  let render = node =>
    Renderer.render_to_string(Renderer.create(~width=12, ~height=1, node));
  let output = render(wrapped);

  Alcotest.(check(string))("box output", render(direct), output);
  Alcotest.(check(bool))(
    "explicit text child",
    true,
    contains_sub(output, "Child"),
  );
};

let jsx_element_syntax_renders_message_and_panel = () => {
  let direct =
    Components.panel(
      ~tone=Components.Info,
      "Status",
      [
        Patterns.message(
          ~tone=Components.Info,
          ~author="User",
          ~time="12:02",
          "Hello",
        ),
        Components.text("Plain child"),
      ],
    );
  let wrapped = {
    Tui.Jsx.(
      <Panel title="Status" tone=Components.Info>
        <Message
          tone=Components.Info
          author="User"
          time="12:02"
          body="Hello"
        />
        <Text value="Plain child" />
      </Panel>
    );
  };

  Alcotest.(check(string))(
    "jsx element output",
    render_node(~width=48, ~height=12, ~node=direct),
    render_node(~width=48, ~height=12, ~node=wrapped),
  );
};

let direct_component_calls_render_with_jsx_export = () => {
  let root =
    Tui.box(
      ~style=Style.(make(~width=Cells(12), ~height=Cells(1), ())),
      [Tui.text("Direct")],
    );
  let output =
    Renderer.render_to_string(Renderer.create(~width=12, ~height=1, root));

  Alcotest.(check(bool))(
    "direct components still render",
    true,
    contains_sub(output, "Direct"),
  );
};

let jsx_component_wrappers_match_direct_components = () => {
  let direct =
    Components.column([
      Components.rich_text([
        Span.make(~style=Style.(make(~attrs=[Attr.Bold], ())), "Rich"),
      ]),
      Components.row([
        Components.text("Row"),
        Components.vertical_rule(
          ~style=Style.(make(~height=Cells(1), ())),
          (),
        ),
        Components.spacer(~style=Style.(make(~width=Cells(1), ())), ()),
      ]),
      Components.input(~placeholder="filter", ()),
      Components.select([
        Components.option(~description="ready", "Ready"),
        Components.option(~value="run", ~description="active", "Running"),
      ]),
      Components.scroll_box([Components.text("Scrolled")]),
      Components.progress_bar(~label="build", 0.5),
      Components.sparkline([0.1, 0.4, 0.9]),
      Components.panel(
        "Panel",
        [
          Components.badge(~tone=Components.Success, "ok"),
          Components.tab_bar([("Logs", true), ("Files", false)]),
        ],
      ),
      Components.key_value([("branch", "main"), ("state", "ready")]),
      Components.table([("TASK", 8), ("STATE", 6)], [["build", "ok"]]),
      Components.split(
        [Components.text("left")],
        [Components.text("right")],
      ),
      Components.divider(~title="Data", ()),
      Components.callout(
        ~title="Note",
        [Components.text("explicit child")],
      ),
      Components.empty_state(
        ~detail="No rows",
        ~action="Press r",
        "Nothing here",
      ),
      Components.toolbar([("q", "uit"), ("/", "filter")]),
      Components.meter(~label="CPU", ~value="67%", 0.67),
    ]);

  let wrapped =
    J.Column.make(
      ~children=[
        J.RichText.make(
          ~spans=[
            Span.make(~style=Style.(make(~attrs=[Attr.Bold], ())), "Rich"),
          ],
          (),
        ),
        J.Row.make(
          ~children=[
            J.Text.make(~value="Row", ()),
            J.VerticalRule.make(
              ~style=Style.(make(~height=Cells(1), ())),
              (),
            ),
            J.Spacer.make(~style=Style.(make(~width=Cells(1), ())), ()),
          ],
          (),
        ),
        J.Input.make(~placeholder="filter", ()),
        J.Select.make(
          ~options=[
            J.Option.make(~description="ready", ~name="Ready", ()),
            J.Option.make(
              ~value="run",
              ~description="active",
              ~name="Running",
              (),
            ),
          ],
          (),
        ),
        J.ScrollBox.make(
          ~children=[J.Text.make(~value="Scrolled", ())],
          (),
        ),
        J.ProgressBar.make(~label="build", ~fraction=0.5, ()),
        J.Sparkline.make(~values=[0.1, 0.4, 0.9], ()),
        J.Panel.make(
          ~title="Panel",
          ~children=[
            J.Badge.make(~tone=Components.Success, ~label="ok", ()),
            J.TabBar.make(~tabs=[("Logs", true), ("Files", false)], ()),
          ],
          (),
        ),
        J.KeyValue.make(
          ~pairs=[("branch", "main"), ("state", "ready")],
          (),
        ),
        J.Table.make(
          ~columns=[("TASK", 8), ("STATE", 6)],
          ~rows=[["build", "ok"]],
          (),
        ),
        J.Split.make(
          ~left=[J.Text.make(~value="left", ())],
          ~right=[J.Text.make(~value="right", ())],
          (),
        ),
        J.Divider.make(~title="Data", ()),
        J.Callout.make(
          ~title="Note",
          ~children=[J.Text.make(~value="explicit child", ())],
          (),
        ),
        J.EmptyState.make(
          ~detail="No rows",
          ~action="Press r",
          ~title="Nothing here",
          (),
        ),
        J.Toolbar.make(~items=[("q", "uit"), ("/", "filter")], ()),
        J.Meter.make(~label="CPU", ~value="67%", ~fraction=0.67, ()),
      ],
      (),
    );

  Alcotest.(check(string))(
    "component wrapper output",
    render_node(~width=96, ~height=42, ~node=direct),
    render_node(~width=96, ~height=42, ~node=wrapped),
  );
};

let jsx_pattern_wrappers_match_direct_patterns = () => {
  let direct =
    Components.column([
      Patterns.header(
        ~subtitle="sub",
        ~badges=[(Components.Success, "live")],
        "Header",
      ),
      Patterns.rule_panel([Components.text("rule body")]),
      Patterns.metric_card(
        ~label="CPU",
        ~value="67%",
        ~detail="steady",
        ~progress=0.67,
        ~sparkline=[0.2, 0.5, 0.7],
        (),
      ),
      Patterns.log_feed([
        ("12:00", "INFO", "started"),
        ("12:01", "OK", "ready"),
      ]),
      Patterns.section_title("Section"),
      Patterns.nav_item(~active=true, ~meta="now", "Inbox"),
      Patterns.message(
        ~tone=Components.Info,
        ~author="User",
        ~time="12:02",
        "Hello",
      ),
      Patterns.timeline([(Components.Success, "tests", "passing")]),
      Patterns.composer(~placeholder="Ask", ()),
      Patterns.command_bar([("q", "uit"), ("?", "help")]),
      Patterns.footer([("Tab", "focus")]),
      Patterns.modal(
        ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
        "Modal",
        [Components.text("body")],
      ),
      Patterns.app_shell(
        ~title="Shell",
        ~subtitle="frame",
        [Components.text("body")],
      ),
    ]);

  let wrapped =
    J.Column.make(
      ~children=[
        J.Header.make(
          ~subtitle="sub",
          ~badges=[(Components.Success, "live")],
          ~title="Header",
          (),
        ),
        J.RulePanel.make(
          ~children=[J.Text.make(~value="rule body", ())],
          (),
        ),
        J.MetricCard.make(
          ~label="CPU",
          ~value="67%",
          ~detail="steady",
          ~progress=0.67,
          ~sparkline=[0.2, 0.5, 0.7],
          (),
        ),
        J.LogFeed.make(
          ~entries=[("12:00", "INFO", "started"), ("12:01", "OK", "ready")],
          (),
        ),
        J.SectionTitle.make(~title="Section", ()),
        J.NavItem.make(~active=true, ~meta="now", ~label="Inbox", ()),
        J.Message.make(
          ~tone=Components.Info,
          ~author="User",
          ~time="12:02",
          ~body="Hello",
          (),
        ),
        J.Timeline.make(
          ~entries=[(Components.Success, "tests", "passing")],
          (),
        ),
        J.Composer.make(~placeholder="Ask", ()),
        J.CommandBar.make(~items=[("q", "uit"), ("?", "help")], ()),
        J.Footer.make(~shortcuts=[("Tab", "focus")], ()),
        J.Modal.make(
          ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
          ~title="Modal",
          ~children=[J.Text.make(~value="body", ())],
          (),
        ),
        J.AppShell.make(
          ~title="Shell",
          ~subtitle="frame",
          ~children=[J.Text.make(~value="body", ())],
          (),
        ),
      ],
      (),
    );

  Alcotest.(check(string))(
    "pattern wrapper output",
    render_node(~width=96, ~height=56, ~node=direct),
    render_node(~width=96, ~height=56, ~node=wrapped),
  );
};

let direct_agent_workspace_root = () => {
  let sessions = [
    Patterns.section_title("Sessions"),
    Patterns.nav_item(~active=true, ~meta="now", "ocaml-tui"),
    Patterns.nav_item(~meta="12m", "renderer-bugs"),
    Patterns.nav_item(~meta="1h", "release-notes"),
    Patterns.nav_item(~meta="2h", "perf-pass"),
    Patterns.section_title(~tone=Components.Info, "Workspaces"),
    Patterns.nav_item(~meta="main", "opencaml"),
    Patterns.nav_item(~meta="dirty", "demo-kit"),
  ];
  let transcript = [
    Patterns.message(
      ~tone=Components.Info,
      ~author="User",
      ~time="14:12",
      "Build components so people can recreate this kind of terminal UI.",
    ),
    Patterns.message(
      ~tone=Components.Success,
      ~author="Assistant",
      ~time="14:13",
      "Added dashboard primitives: panels, badges, metric cards, tables, logs, tabs, and command bars.",
    ),
    Patterns.message(
      ~tone=Components.Accent,
      ~author="Assistant",
      ~time="14:16",
      "Now adding workspace primitives for chat-heavy layouts: side navigation, messages, timelines, and a composer.",
    ),
  ];
  let activity = [
    Patterns.timeline([
      (Components.Success, "tests", "10 passing"),
      (Components.Info, "build", "dune build @all"),
      (Components.Warning, "review", "image parity needs source pixels"),
      (Components.Accent, "example", "agent_workspace.exe"),
    ]),
    Components.panel(
      "Context",
      [
        Components.key_value(
          ~label_width=9,
          [
            ("branch", "no git repo"),
            ("package", "tui"),
            ("layout", "Toffee flex"),
            ("target", "132x38"),
          ],
        ),
      ],
    ),
  ];

  Patterns.app_shell(
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
    [
      Components.split(
        ~left_width=28,
        [
          Components.panel(
            "Navigator",
            ~style=Style.(make(~height=Percent(1.), ())),
            sessions,
          ),
        ],
        [
          Components.box(
            ~style=
              Style.(
                make(~flex_direction=Row, ~gap=1, ~height=Percent(1.), ())
              ),
            [
              Components.panel(
                "Conversation",
                ~style=Style.(make(~flex_grow=1., ~height=Percent(1.), ())),
                [
                  Components.scroll_box(
                    ~style=Style.(make(~flex_grow=1., ())),
                    transcript,
                  ),
                  Patterns.composer(
                    ~placeholder="Ask for code, tests, or a review",
                    (),
                  ),
                ],
              ),
              Components.panel(
                "Run State",
                ~tone=Components.Info,
                ~style=
                  Style.(make(~width=Cells(36), ~height=Percent(1.), ())),
                activity,
              ),
            ],
          ),
        ],
      ),
    ],
  );
};

let jsx_agent_workspace_root = () => {
  let sessions = [
    J.SectionTitle.make(~title="Sessions", ()),
    J.NavItem.make(~active=true, ~meta="now", ~label="ocaml-tui", ()),
    J.NavItem.make(~meta="12m", ~label="renderer-bugs", ()),
    J.NavItem.make(~meta="1h", ~label="release-notes", ()),
    J.NavItem.make(~meta="2h", ~label="perf-pass", ()),
    J.SectionTitle.make(~tone=Components.Info, ~title="Workspaces", ()),
    J.NavItem.make(~meta="main", ~label="opencaml", ()),
    J.NavItem.make(~meta="dirty", ~label="demo-kit", ()),
  ];
  let transcript = [
    J.Message.make(
      ~tone=Components.Info,
      ~author="User",
      ~time="14:12",
      ~body=
        "Build components so people can recreate this kind of terminal UI.",
      (),
    ),
    J.Message.make(
      ~tone=Components.Success,
      ~author="Assistant",
      ~time="14:13",
      ~body=
        "Added dashboard primitives: panels, badges, metric cards, tables, logs, tabs, and command bars.",
      (),
    ),
    J.Message.make(
      ~tone=Components.Accent,
      ~author="Assistant",
      ~time="14:16",
      ~body=
        "Now adding workspace primitives for chat-heavy layouts: side navigation, messages, timelines, and a composer.",
      (),
    ),
  ];
  let activity = [
    J.Timeline.make(
      ~entries=[
        (Components.Success, "tests", "10 passing"),
        (Components.Info, "build", "dune build @all"),
        (Components.Warning, "review", "image parity needs source pixels"),
        (Components.Accent, "example", "agent_workspace.exe"),
      ],
      (),
    ),
    J.Panel.make(
      ~title="Context",
      ~children=[
        J.KeyValue.make(
          ~label_width=9,
          ~pairs=[
            ("branch", "no git repo"),
            ("package", "tui"),
            ("layout", "Toffee flex"),
            ("target", "132x38"),
          ],
          (),
        ),
      ],
      (),
    ),
  ];

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
};

let jsx_agent_workspace_matches_direct_example = () => {
  let direct =
    render_node(~width=132, ~height=38, ~node=direct_agent_workspace_root());
  let wrapped =
    render_node(~width=132, ~height=38, ~node=jsx_agent_workspace_root());
  let wide_wrapped =
    render_node(~width=180, ~height=38, ~node=jsx_agent_workspace_root());

  Alcotest.(check(string))("agent workspace parity", direct, wrapped);
  Alcotest.(check(bool))(
    "session labels",
    true,
    contains_sub(wrapped, "ocaml-tui")
    && contains_sub(wrapped, "renderer-bugs"),
  );
  Alcotest.(check(bool))(
    "conversation and composer",
    true,
    contains_sub(wrapped, "Assistant")
    && contains_sub(wrapped, "Ask for code, tests, or a review"),
  );
  Alcotest.(check(bool))(
    "run state labels",
    true,
    contains_sub(wide_wrapped, "Run State")
    && contains_sub(wide_wrapped, "10 passing"),
  );
};

let input_editing = () => {
  let field = input(~id="field", ~value="ab", ());
  let renderer = Renderer.create(~width=8, ~height=1, field);
  Renderer.dispatch_key(renderer, Key.of_sequence("c")) |> ignore;
  Renderer.dispatch_key(renderer, Key.of_sequence("")) |> ignore;
  switch (Node.find_by_id("field", renderer.Renderer.root)) {
  | Some({ kind: Input(state), _ }) =>
    Alcotest.(check(string))("value", "ab", state.value)
  | _ => Alcotest.fail("input not found")
  };
};

let select_navigation = () => {
  let menu =
    select(
      ~id="menu",
      ~wrap=true,
      [option("One"), option("Two"), option("Three")],
    );

  let renderer = Renderer.create(~width=20, ~height=3, menu);
  Renderer.dispatch_key(renderer, Key.of_sequence("k")) |> ignore;
  switch (Node.find_by_id("menu", renderer.Renderer.root)) {
  | Some({ kind: Select(state), _ }) =>
    Alcotest.(check(int))("wrapped selection", 2, state.selected)
  | _ => Alcotest.fail("select not found")
  };
};

let scrollbox_keyboard_routing = () => {
  let scroller =
    scroll_box(
      ~id="scroll",
      ~style=Style.(make(~width=Cells(8), ~height=Cells(2), ())),
      [text("A"), text("B"), text("C")],
    );

  let renderer = Renderer.create(~width=8, ~height=2, scroller);
  Renderer.dispatch_key(renderer, Key.of_sequence("\027[B")) |> ignore;
  switch (Node.find_by_id("scroll", renderer.Renderer.root)) {
  | Some({ kind: Scroll_box(state), _ }) =>
    Alcotest.(check(int))("scroll y", 1, state.scroll_y);
    Alcotest.(check(string))(
      "scrolled snapshot",
      "B       \nC       ",
      Renderer.render_to_string(renderer),
    );
  | _ => Alcotest.fail("scrollbox not found")
  };
};

let key_parses_arrows = () => {
  let key = Key.of_sequence("\027[A");
  Alcotest.(check(string))("name", "up", key.name);
  Alcotest.(check(bool))("ctrl", false, key.ctrl);
};

let keymap_sequence = () => {
  let keymap = Keymap.create();
  let fired = ref(false);
  Keymap.register(keymap, ~key="dd", ~name="delete-line", ~run=() =>
    fired := true
  );
  Alcotest.(check(bool))(
    "pending",
    true,
    Keymap.dispatch(keymap, Key.of_sequence("d")) == Keymap.Pending,
  );
  Alcotest.(check(bool))(
    "handled",
    true,
    switch (Keymap.dispatch(keymap, Key.of_sequence("d"))) {
    | Keymap.Handled("delete-line") => true
    | _ => false
    },
  );
  Alcotest.(check(bool))("ran command", true, fired^);
};

let surface_ansi_respects_no_color = () => {
  let level =
    Color.detect_level(
      ~env=
        fun
        | "NO_COLOR" => Some("1")
        | _ => None,
      (),
    );
  let surface = Surface.create(~width=2, ~height=1, ());
  Surface.set(
    surface,
    ~x=0,
    ~y=0,
    ~style=Style.(make(~fg=Color.ansi(1), ())),
    "x",
  );
  Alcotest.(check(string))(
    "plain when no color",
    "x ",
    Surface.to_ansi(~level, surface),
  );
};

let control_bytes_are_not_rendered_from_text = () => {
  let renderer =
    Renderer.create(~width=24, ~height=1, text("\027]52;c;QUJD\007visible"));
  let plain = Renderer.render_to_string(renderer);
  let surface = Renderer.request_render(renderer);
  let ansi = Surface.to_ansi(~level=Color.No_color, surface);
  let styled_ansi = Surface.to_ansi(~level=Color.Ansi16, surface);
  let osc_prefix = "\027]52;c;";
  let assert_sanitized = (label, output) => {
    Alcotest.(check(bool))(
      label ++ " has no ESC",
      false,
      String.contains(output, Char.chr(0x1B)),
    );
    Alcotest.(check(bool))(
      label ++ " has no BEL",
      false,
      String.contains(output, Char.chr(0x07)),
    );
    Alcotest.(check(bool))(
      label ++ " keeps printable text",
      true,
      contains_sub(output, "]52;c;QUJDvisible"),
    );
  };

  assert_sanitized("plain", plain);
  assert_sanitized("ansi", ansi);
  Alcotest.(check(bool))(
    "styled ansi has no OSC prefix",
    false,
    contains_sub(styled_ansi, osc_prefix),
  );
  Alcotest.(check(bool))(
    "styled ansi has no BEL",
    false,
    String.contains(styled_ansi, Char.chr(0x07)),
  );
  Alcotest.(check(bool))(
    "styled ansi keeps printable text",
    true,
    contains_sub(styled_ansi, "]52;c;QUJDvisible"),
  );
};

let utf_width_helpers_handle_unicode = () => {
  Alcotest.(check(int))("ascii width", 5, Utf.string_width("hello"));
  Alcotest.(check(int))("wide width", 2, Utf.string_width("界"));
  Alcotest.(check(int))("combining mark width", 1, Utf.string_width("é"));
  Alcotest.(check(string))(
    "utf8 encoding 2-byte",
    "é",
    Utf.uchar_to_utf8(Uchar.of_int(0x00E9)),
  );
  Alcotest.(check(string))(
    "utf8 encoding 3-byte",
    "界",
    Utf.uchar_to_utf8(Uchar.of_int(0x754C)),
  );
  Alcotest.(check(string))(
    "utf8 encoding 4-byte",
    "😀",
    Utf.uchar_to_utf8(Uchar.of_int(0x1F600)),
  );
};

let table_component_fits_unicode = () => {
  let root = Components.table([("COL", 3)], [["abcdef"]]);
  let renderer = Renderer.create(~width=10, ~height=3, root);
  Alcotest.(check(string))(
    "table snapshot",
    "COL       \n───       \nab…       ",
    Renderer.render_to_string(renderer),
  );
};

let table_component_handles_uneven_rows = () => {
  let root =
    Components.table(
      [("A", 3), ("B", 2)],
      [["x"], ["one", "two", "ignored"]],
    );
  let output =
    Renderer.render_to_string(Renderer.create(~width=12, ~height=4, root));
  Alcotest.(check(bool))(
    "keeps short row",
    true,
    contains_sub(output, "x"),
  );
  Alcotest.(check(bool))(
    "truncates long cell and ignores extra cells",
    true,
    contains_sub(output, "one  t…"),
  );
};

let dashboard_components_render = () => {
  let root =
    Patterns.app_shell(
      ~title="Ops",
      ~badges=[(Components.Success, "live")],
      [
        Components.row([
          Patterns.metric_card(
            ~label="CPU",
            ~value="67%",
            ~progress=0.67,
            (),
          ),
          Components.panel(
            "Events",
            [
              Patterns.log_feed([
                ("12:00", "INFO", "started"),
                ("12:01", "OK", "ready"),
              ]),
            ],
          ),
        ]),
      ],
    );

  let output =
    Renderer.render_to_string(Renderer.create(~width=64, ~height=12, root));
  Alcotest.(check(bool))(
    "contains title",
    true,
    String.contains(output, 'O'),
  );
  Alcotest.(check(bool))(
    "contains metric",
    true,
    String.contains(output, 'C'),
  );
};

let vertical_rule_fills_height = () => {
  let root = vertical_rule(~style=Style.(make(~height=Cells(3), ())), ());
  let output =
    Renderer.render_to_string(Renderer.create(~width=2, ~height=3, root));
  Alcotest.(check(string))("rule", "│ \n│ \n│ ", output);
};

let opencode_helpers_render = () => {
  let root =
    box([
      Presets.Open_code.wordmark("opencode"),
      Patterns.rule_panel([
        Presets.Open_code.model_status(),
        Presets.Open_code.hint_bar([
          ("tab", "agents"),
          ("ctrl+p", "commands"),
        ]),
      ]),
    ]);

  let output =
    Renderer.render_to_string(Renderer.create(~width=80, ~height=10, root));
  Alcotest.(check(bool))("has rule", true, contains_sub(output, "│"));
  Alcotest.(check(bool))(
    "has model status",
    true,
    String.contains(output, 'B'),
  );
};

let modal_component_renders_overlay = () => {
  let root =
    box(
      ~style=Style.(make(~width=Cells(40), ~height=Cells(12), ())),
      [
        text("background"),
        Patterns.modal(
          ~id="help-modal",
          ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
          "Commands",
          [text("q quit"), text("? close")],
        ),
      ],
    );

  let renderer = Renderer.create(~width=40, ~height=12, root);
  let output = Renderer.render_to_string(renderer);
  Alcotest.(check(bool))(
    "modal node exists",
    true,
    Option.is_some(Node.find_by_id("help-modal", renderer.root)),
  );
  Alcotest.(check(bool))(
    "contains title",
    true,
    contains_sub(output, "Commands"),
  );
  Alcotest.(check(bool))(
    "contains body",
    true,
    contains_sub(output, "q quit"),
  );
};

let viewport_helpers = () => {
  let tiny = Viewport.make(~width=40, ~height=12);
  let compact = Viewport.make(~width=72, ~height=22);
  let regular = Viewport.make(~width=96, ~height=24);
  let wide = Viewport.make(~width=132, ~height=38);
  Alcotest.(check(int))(
    "width clamped",
    1,
    Viewport.make(~width=0, ~height=0).width,
  );
  Alcotest.(check(int))("area", 132 * 38, Viewport.area(wide));
  Alcotest.(check(bool))(
    "fits",
    true,
    Viewport.fits(~min_width=80, ~min_height=24, wide),
  );
  Alcotest.(check(bool))(
    "tiny",
    true,
    Viewport.breakpoint(tiny) == Viewport.Tiny,
  );
  Alcotest.(check(bool))(
    "compact",
    true,
    Viewport.breakpoint(compact) == Viewport.Compact,
  );
  Alcotest.(check(bool))(
    "regular",
    true,
    Viewport.breakpoint(regular) == Viewport.Regular,
  );
  Alcotest.(check(bool))(
    "wide",
    true,
    Viewport.breakpoint(wide) == Viewport.Wide,
  );
  Alcotest.(check(string))(
    "choose",
    "wide",
    Viewport.choose(
      wide,
      ~tiny="tiny",
      ~compact="compact",
      ~regular="regular",
      ~wide="wide",
    ),
  );
};

let terminal_viewport_uses_env = () => {
  let env =
    fun
    | "COLUMNS" => Some("120")
    | "LINES" => Some("40")
    | _ => None;
  let viewport = Terminal.viewport(~env, ~fallback_to_tty=false, ());
  Alcotest.(check(int))("columns", 120, viewport.width);
  Alcotest.(check(int))("rows", 40, viewport.height);
  Alcotest.(check(pair(int, int)))(
    "size",
    (120, 40),
    Terminal.size(~env, ~fallback_to_tty=false, ()),
  );
  Alcotest.(check(int))(
    "columns helper",
    120,
    Terminal.columns(~env, ~fallback_to_tty=false, ()),
  );
  Alcotest.(check(int))(
    "rows helper",
    40,
    Terminal.rows(~env, ~fallback_to_tty=false, ()),
  );
  let invalid_env =
    fun
    | "COLUMNS" => Some("0")
    | "LINES" => Some("wat")
    | _ => None;
  Alcotest.(check(pair(int, int)))(
    "fallback size",
    (80, 24),
    Terminal.size(~env=invalid_env, ~fallback_to_tty=false, ()),
  );
};

let renderer_viewport_and_resize = () => {
  let renderer = Renderer.create(~width=10, ~height=5, text("x"));
  Alcotest.(check(pair(int, int)))(
    "initial renderer size",
    (10, 5),
    Renderer.size(renderer),
  );
  Renderer.resize(renderer, ~width=30, ~height=9);
  Alcotest.(check(pair(int, int)))(
    "resized renderer",
    (30, 9),
    Renderer.size(renderer),
  );
  Renderer.resize_to_viewport(renderer, Viewport.make(~width=20, ~height=7));
  Alcotest.(check(pair(int, int)))(
    "viewport resize",
    (20, 7),
    Renderer.size(renderer),
  );
  Renderer.resize(renderer, ~width=0, ~height=0);
  Alcotest.(check(pair(int, int)))(
    "resize clamps",
    (1, 1),
    Renderer.size(renderer),
  );
};

let component_design_injects_theme = () => {
  let theme =
    fun
    | Theme.Fg_default => Color.ansi(1)
    | Theme.Fg_muted => Color.ansi(2)
    | Theme.Fg_emphasis => Color.ansi(3)
    | Theme.Bg_base => Color.ansi(4)
    | Theme.Bg_surface => Color.ansi(5)
    | Theme.Bg_overlay => Color.ansi(6)
    | Theme.Bg_selection => Color.ansi(7)
    | Theme.Accent_primary => Color.ansi(8)
    | Theme.Accent_secondary => Color.ansi(9)
    | Theme.Status_error => Color.ansi(10)
    | Theme.Status_warning => Color.ansi(11)
    | Theme.Status_success => Color.ansi(12)
    | Theme.Status_info => Color.ansi(13);

  let design = Components.make_design(~theme, ());
  let root =
    Components.badge(~id="badge", ~tone=Components.Success, ~design, "ok");
  switch (Node.find_by_id("badge", root)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "uses custom success color",
      true,
      node.style.fg == Some(Color.ansi(12)),
    );
    Alcotest.(check(bool))(
      "uses custom badge background",
      true,
      node.style.bg == Some(Color.ansi(7)),
    );
  | None => Alcotest.fail("badge not found")
  };
  let surface =
    Renderer.request_render(Renderer.create(~width=4, ~height=1, root));
  switch (Surface.get(surface, ~x=1, ~y=0)) {
  | Some(cell) =>
    Alcotest.(check(string))("badge label cell", "o", cell.Surface.text);
    Alcotest.(check(bool))(
      "rendered badge label background",
      true,
      cell.style.bg == Some(Color.ansi(7)),
    );
  | None => Alcotest.fail("badge label cell not rendered")
  };
  let light_design = Components.make_design(~theme=Theme.light, ());
  let light =
    Components.badge(
      ~id="light-badge",
      ~tone=Components.Success,
      ~design=light_design,
      "ok",
    );
  switch (Node.find_by_id("light-badge", light)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "uses light success color",
      true,
      node.style.fg == Some(Theme.light(Theme.Status_success)),
    )
  | None => Alcotest.fail("light badge not found")
  };
};

let component_design_rethemes_default_tones = () => {
  let design = Components.make_design();
  let light_design = Components.with_theme(~theme=Theme.light, design);
  let root =
    Components.badge(
      ~id="badge",
      ~tone=Components.Success,
      ~design=light_design,
      "ok",
    );
  switch (Node.find_by_id("badge", root)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "uses new theme success color",
      true,
      node.style.fg == Some(Theme.light(Theme.Status_success)),
    )
  | None => Alcotest.fail("badge not found")
  };
};

let component_design_retheme_preserves_custom_tones = () => {
  let tone_color = _tone => Color.ansi(5);
  let design = Components.make_design(~tone_color, ());
  let light_design = Components.with_theme(~theme=Theme.light, design);
  let root =
    Components.badge(
      ~id="badge",
      ~tone=Components.Success,
      ~design=light_design,
      "ok",
    );
  switch (Node.find_by_id("badge", root)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "preserves explicit tone color",
      true,
      node.style.fg == Some(Color.ansi(5)),
    )
  | None => Alcotest.fail("badge not found")
  };
};

let theme_helpers_cover_palettes_and_named_lookup = () => {
  switch (Theme.named("high-contrast")) {
  | Some(theme) =>
    Alcotest.(check(bool))(
      "named high contrast",
      true,
      theme(Theme.Accent_primary)
      == Theme.high_contrast_dark(Theme.Accent_primary),
    )
  | None => Alcotest.fail("theme not found")
  };
  Alcotest.(check(bool))(
    "missing theme",
    true,
    Option.is_none(Theme.named("missing")),
  );
  let palette = Theme.to_palette(Theme.dark);
  Alcotest.(check(bool))(
    "palette roundtrip",
    true,
    palette.Theme.fg_default == Theme.dark(Theme.Fg_default),
  );
  let custom =
    Theme.with_slot(Theme.Accent_primary, Color.ansi(3), Theme.light);
  Alcotest.(check(bool))(
    "override slot",
    true,
    custom(Theme.Accent_primary) == Color.ansi(3),
  );
  Alcotest.(check(bool))(
    "fallback slot",
    true,
    custom(Theme.Fg_default) == Theme.light(Theme.Fg_default),
  );
};

let component_design_style_helpers = () => {
  let design = Components.make_design(~theme=Theme.high_contrast_dark, ());
  let style =
    Components.style(
      ~design,
      ~fg=Theme.Accent_primary,
      ~bg=Theme.Bg_surface,
      ~attrs=[Attr.Bold],
      (),
    );
  Alcotest.(check(bool))(
    "style fg",
    true,
    style.fg == Some(Theme.high_contrast_dark(Theme.Accent_primary)),
  );
  Alcotest.(check(bool))(
    "style bg",
    true,
    style.bg == Some(Theme.high_contrast_dark(Theme.Bg_surface)),
  );
  Alcotest.(check(bool))("style attrs", true, style.attrs == [Attr.Bold]);
};

let new_component_primitives_render = () => {
  let root =
    Components.column([
      Components.divider(~id="divider", ~width=24, ~title="State", ()),
      Components.callout(
        ~id="callout",
        ~title="Notice",
        [text("queued for review")],
      ),
      Components.empty_state(
        ~id="empty",
        ~detail="No runs match this filter",
        ~action="[r] reset",
        "Nothing here",
      ),
      Components.toolbar(~id="toolbar", [("q", "uit"), ("/", "filter")]),
      Components.meter(~id="meter", ~label="CPU", ~value="67%", 0.67),
    ]);

  let renderer = Renderer.create(~width=48, ~height=18, root);
  let output = Renderer.render_to_string(renderer);
  Alcotest.(check(bool))(
    "divider id",
    true,
    Option.is_some(Node.find_by_id("divider", renderer.root)),
  );
  Alcotest.(check(bool))(
    "callout body",
    true,
    contains_sub(output, "queued for review"),
  );
  Alcotest.(check(bool))(
    "empty title",
    true,
    contains_sub(output, "Nothing here"),
  );
  Alcotest.(check(bool))("toolbar key", true, contains_sub(output, "[q]"));
  Alcotest.(check(bool))("meter label", true, contains_sub(output, "CPU"));
};

let app_shell_default_is_neutral = () => {
  let output =
    Renderer.render_to_string(
      Renderer.create(~width=32, ~height=6, Patterns.app_shell([])),
    );
  Alcotest.(check(bool))(
    "default app title",
    true,
    contains_sub(output, "App"),
  );
  Alcotest.(check(bool))(
    "no product title",
    false,
    contains_sub(output, "Symphony TUI"),
  );
};

let opencode_preset_has_moved_helper = () => {
  let root = Presets.Open_code.model_status();
  let output =
    Renderer.render_to_string(Renderer.create(~width=80, ~height=1, root));
  Alcotest.(check(bool))(
    "preset renders default model",
    true,
    contains_sub(output, "DeepSeek V4 Pro"),
  );
};

let component_compat_aliases_render = () => {
  let root =
    box([
      Components.header(~subtitle="keeps old call sites working", "Compat"),
      Components.modal(
        ~id="compat-modal",
        ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
        "Help",
        [text("q quit")],
      ),
      Components.model_status(),
    ]);

  let renderer = Renderer.create(~width=48, ~height=12, root);
  let output = Renderer.render_to_string(renderer);
  Alcotest.(check(bool))(
    "modal alias node exists",
    true,
    Option.is_some(Node.find_by_id("compat-modal", renderer.root)),
  );
  Alcotest.(check(bool))(
    "header alias renders",
    true,
    contains_sub(output, "Compat"),
  );
  Alcotest.(check(bool))(
    "preset alias renders",
    true,
    contains_sub(output, "DeepSeek V4 Pro"),
  );
};

let () =
  Alcotest.run(
    "tui",
    [
      (
        "render",
        [
          Alcotest.test_case("plain snapshot", `Quick, plain_snapshot),
          Alcotest.test_case("flex row", `Quick, flex_row_layout),
          Alcotest.test_case(
            "rich text inherits node paint",
            `Quick,
            rich_text_inherits_node_paint,
          ),
        ],
      ),
      (
        "jsx",
        [
          Alcotest.test_case(
            "text matches component",
            `Quick,
            jsx_text_matches_component_text,
          ),
          Alcotest.test_case(
            "box renders explicit text children",
            `Quick,
            jsx_box_renders_explicit_text_children,
          ),
          Alcotest.test_case(
            "element syntax renders message and panel",
            `Quick,
            jsx_element_syntax_renders_message_and_panel,
          ),
          Alcotest.test_case(
            "direct calls still render",
            `Quick,
            direct_component_calls_render_with_jsx_export,
          ),
          Alcotest.test_case(
            "component wrapper parity",
            `Quick,
            jsx_component_wrappers_match_direct_components,
          ),
          Alcotest.test_case(
            "pattern wrapper parity",
            `Quick,
            jsx_pattern_wrappers_match_direct_patterns,
          ),
          Alcotest.test_case(
            "agent workspace parity",
            `Quick,
            jsx_agent_workspace_matches_direct_example,
          ),
        ],
      ),
      (
        "widgets",
        [
          Alcotest.test_case("input editing", `Quick, input_editing),
          Alcotest.test_case("select navigation", `Quick, select_navigation),
          Alcotest.test_case(
            "scrollbox routing",
            `Quick,
            scrollbox_keyboard_routing,
          ),
        ],
      ),
      (
        "keys",
        [
          Alcotest.test_case("sequence", `Quick, keymap_sequence),
          Alcotest.test_case("arrow parser", `Quick, key_parses_arrows),
        ],
      ),
      (
        "ansi",
        [
          Alcotest.test_case(
            "no color",
            `Quick,
            surface_ansi_respects_no_color,
          ),
          Alcotest.test_case(
            "text control bytes",
            `Quick,
            control_bytes_are_not_rendered_from_text,
          ),
        ],
      ),
      (
        "utf",
        [
          Alcotest.test_case(
            "unicode width helpers",
            `Quick,
            utf_width_helpers_handle_unicode,
          ),
        ],
      ),
      (
        "components",
        [
          Alcotest.test_case(
            "table unicode fit",
            `Quick,
            table_component_fits_unicode,
          ),
          Alcotest.test_case(
            "table uneven rows",
            `Quick,
            table_component_handles_uneven_rows,
          ),
          Alcotest.test_case(
            "dashboard render",
            `Quick,
            dashboard_components_render,
          ),
          Alcotest.test_case(
            "vertical rule",
            `Quick,
            vertical_rule_fills_height,
          ),
          Alcotest.test_case(
            "opencode helpers",
            `Quick,
            opencode_helpers_render,
          ),
          Alcotest.test_case(
            "modal overlay",
            `Quick,
            modal_component_renders_overlay,
          ),
          Alcotest.test_case(
            "design injection",
            `Quick,
            component_design_injects_theme,
          ),
          Alcotest.test_case(
            "design retheme default tones",
            `Quick,
            component_design_rethemes_default_tones,
          ),
          Alcotest.test_case(
            "design retheme custom tones",
            `Quick,
            component_design_retheme_preserves_custom_tones,
          ),
          Alcotest.test_case(
            "theme helpers",
            `Quick,
            theme_helpers_cover_palettes_and_named_lookup,
          ),
          Alcotest.test_case(
            "design style helpers",
            `Quick,
            component_design_style_helpers,
          ),
          Alcotest.test_case(
            "new primitives",
            `Quick,
            new_component_primitives_render,
          ),
          Alcotest.test_case(
            "neutral app shell default",
            `Quick,
            app_shell_default_is_neutral,
          ),
          Alcotest.test_case(
            "opencode preset helper",
            `Quick,
            opencode_preset_has_moved_helper,
          ),
          Alcotest.test_case(
            "compat aliases",
            `Quick,
            component_compat_aliases_render,
          ),
        ],
      ),
      (
        "viewport",
        [
          Alcotest.test_case("helpers", `Quick, viewport_helpers),
          Alcotest.test_case(
            "terminal env",
            `Quick,
            terminal_viewport_uses_env,
          ),
          Alcotest.test_case(
            "renderer resize",
            `Quick,
            renderer_viewport_and_resize,
          ),
        ],
      ),
    ],
  );
