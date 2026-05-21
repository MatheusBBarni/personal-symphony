  let rule_panel =
      (
        ~id=?,
        ~tone=Components_core.Accent,
        ~style=Style.default,
        ~design=?,
        children,
      ) => {
    let design = Components_core.resolve_design(design);
    Components_core.box(
      ~id?,
      ~style=
        Style.{
          ...style,
          flex_direction: Row,
          gap: 1,
        },
      [
        Components_core.vertical_rule(
          ~style=
            Style.(
              make(
                ~width=Cells(1),
                ~height=Percent(1.),
                ~fg=Components_core.color_of_tone(~design, tone),
                ~attrs=[Attr.Bold],
                (),
              )
            ),
          (),
        ),
        Components_core.box(
          ~style=
            Style.(
              make(
                ~flex_grow=1.,
                ~height=Percent(1.),
                ~padding=spacing_xy(~x=1, ~y=0),
                ~bg=Components_core.surface_of(design),
                (),
              )
            ),
          children,
        ),
      ],
    );
  };

  let modal =
      (
        ~id=?,
        ~tone=Components_core.Accent,
        ~style=Style.default,
        ~bottom_title="Esc/? close",
        ~design=?,
        title,
        children,
      ) => {
    let design_value = Components_core.resolve_design(design);
    let modal_width =
      switch (style.width) {
      | Style.Auto => Style.Cells(64)
      | width => width
      };
    let modal_height =
      switch (style.height) {
      | Style.Auto => Style.Cells(16)
      | height => height
      };
    let content_style =
      Style.{
        ...style,
        width: modal_width,
        height: modal_height,
        flex_direction: Column,
        bg: Some(Components_core.surface_of(design_value)),
      };

    Components_core.box(
      ~id?,
      ~style=
        Style.(
          make(
            ~position=Absolute,
            ~left=0,
            ~right=0,
            ~top=0,
            ~bottom=0,
            ~width=Percent(1.),
            ~height=Percent(1.),
            ~justify_content=Justify_center,
            ~align_items=Align_center,
            (),
          )
        ),
      [
        Components_core.panel(
          ~tone,
          ~bottom_title,
          ~style=content_style,
          ~design?,
          title,
          children,
        ),
      ],
    );
  };

  let header = (~id=?, ~subtitle=?, ~badges=[], ~design=?, title) => {
    let design_value = Components_core.resolve_design(design);
    let title_line =
      Components_core.text(
        ~style=
          Style.(
            make(
              ~fg=Components_core.emphasis_fg_of(design_value),
              ~attrs=[Attr.Bold],
              (),
            )
          ),
        title,
      );

    let subtitle_line =
      switch (subtitle) {
      | None => []
      | Some(copy) => [
          Components_core.text(
            ~style=
              Style.(
                make(
                  ~fg=Components_core.muted_fg_of(design_value),
                  ~attrs=[Attr.Dim],
                  (),
                )
              ),
            copy,
          ),
        ]
      };

    let badge_nodes =
      badges
      |> List.map(((tone, label)) =>
           Components_core.badge(~tone, ~design?, label)
         );

    Components_core.box(
      ~id?,
      ~style=
        Style.(
          make(
            ~height=Cells(3),
            ~flex_direction=Row,
            ~justify_content=Space_between,
            ~align_items=Align_center,
            ~padding=spacing_xy(~x=2, ~y=0),
            (),
          )
        ),
      [
        Components_core.box(
          ~style=Style.(make(~flex_direction=Column, ())),
          [title_line, ...subtitle_line],
        ),
        Components_core.box(
          ~style=Style.(make(~flex_direction=Row, ~gap=1, ())),
          badge_nodes,
        ),
      ],
    );
  };

  let metric_card =
      (
        ~id=?,
        ~tone=Components_core.Info,
        ~detail=?,
        ~progress=?,
        ~sparkline as series=?,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~value,
        (),
      ) => {
    let design_value = Components_core.resolve_design(design);
    let accent = Components_core.color_of_tone(~design=design_value, tone);
    let children =
      [
        Components_core.text(
          ~style=
            Style.(
              make(
                ~fg=Components_core.muted_fg_of(design_value),
                ~attrs=[Attr.Dim],
                (),
              )
            ),
          label,
        ),
        Components_core.text(
          ~style=
            Style.(
              make(
                ~fg=Components_core.emphasis_fg_of(design_value),
                ~attrs=[Attr.Bold],
                (),
              )
            ),
          value,
        ),
      ]
      @ (
        switch (detail) {
        | None => []
        | Some(d) => [
            Components_core.text(~style=Style.(make(~fg=accent, ())), d),
          ]
        }
      )
      @ (
        switch (progress) {
        | None => []
        | Some(p) => [
            Components_core.progress_bar(
              ~style=Style.(make(~height=Cells(1), ())),
              p,
            ),
          ]
        }
      )
      @ (
        switch (series) {
        | None => []
        | Some(values) => [
            Components_core.sparkline(
              ~style=Style.(make(~fg=accent, ~height=Cells(1), ())),
              values,
            ),
          ]
        }
      );

    Components_core.panel(
      ~id?,
      ~tone,
      ~design?,
      ~style=
        Style.{
          ...style,
          height:
            switch (style.height) {
            | Auto => Cells(List.length(children) + 4)
            | other => other
            },
        },
      label,
      children,
    );
  };

  let log_feed = (~id=?, ~style=Style.default, ~design=?, entries) => {
    let design_value = Components_core.resolve_design(design);
    let tone_of_level =
      fun
      | "ERR"
      | "ERROR"
      | "FAIL" => Components_core.Error
      | "WARN"
      | "WARNING" => Components_core.Warning
      | "OK"
      | "DONE" => Components_core.Success
      | "INFO" => Components_core.Info
      | _ => Components_core.Neutral;

    let row = ((time, level, message)) =>
      Components_core.rich_text([
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Components_core.muted_fg_of(design_value),
                ~attrs=[Attr.Dim],
                (),
              )
            ),
          time ++ " ",
        ),
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=
                  Components_core.color_of_tone(
                    ~design=design_value,
                    tone_of_level(level),
                  ),
                ~attrs=[Attr.Bold],
                (),
              )
            ),
          Components_core.fit(5, level),
        ),
        Span.make(
          ~style=
            Style.(
              make(~fg=Components_core.default_fg_of(design_value), ())
            ),
          " " ++ message,
        ),
      ]);

    Components_core.scroll_box(
      ~id?,
      ~style=
        Style.{
          ...style,
          flex_direction: Column,
        },
      List.map(row, entries),
    );
  };

  let section_title =
      (
        ~id=?,
        ~tone=Components_core.Accent,
        ~style=Style.default,
        ~design=?,
        title,
      ) => {
    let design = Components_core.resolve_design(design);
    Node.text(
      ~id?,
      ~style=
        Style.{
          ...
            make(
              ~height=Cells(1),
              ~fg=Components_core.color_of_tone(~design, tone),
              ~attrs=[Attr.Bold],
              (),
            ),

          width: style.width,
          margin: style.margin,
        },
      title,
    );
  };

  let nav_item =
      (
        ~id=?,
        ~active=false,
        ~meta=?,
        ~tone=Components_core.Accent,
        ~style=Style.default,
        ~design=?,
        label,
      ) => {
    let design = Components_core.resolve_design(design);
    let marker = if (active) {"› "} else {"  "};
    let fg =
      if (active) {
        Components_core.color_of_tone(~design, tone);
      } else {
        Components_core.default_fg_of(design);
      };
    let attrs =
      if (active) {
        [Attr.Bold];
      } else {
        [];
      };
    let content =
      [Span.make(~style=Style.(make(~fg, ~attrs, ())), marker ++ label)]
      @ (
        switch (meta) {
        | None => []
        | Some(meta) => [
            Span.make(
              ~style=
                Style.(
                  make(
                    ~fg=Components_core.muted_fg_of(design),
                    ~attrs=[Attr.Dim],
                    (),
                  )
                ),
              "  " ++ meta,
            ),
          ]
        }
      );

    Components_core.rich_text(
      ~id?,
      ~style=
        Style.{
          ...style,
          height: Cells(1),
        },
      content,
    );
  };

  let message =
      (
        ~id=?,
        ~tone=Components_core.Neutral,
        ~time=?,
        ~style=Style.default,
        ~design=?,
        ~author,
        body,
      ) => {
    let design = Components_core.resolve_design(design);
    let accent = Components_core.color_of_tone(~design, tone);
    let header =
      Components_core.rich_text([
        Span.make(
          ~style=Style.(make(~fg=accent, ~attrs=[Attr.Bold], ())),
          author,
        ),
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Components_core.muted_fg_of(design),
                ~attrs=[Attr.Dim],
                (),
              )
            ),
          switch (time) {
          | None => ""
          | Some(value) => "  " ++ value
          },
        ),
      ]);

    let lines =
      body
      |> String.split_on_char('\n')
      |> List.map(line =>
           Components_core.text(
             ~style=
               Style.(make(~fg=Components_core.default_fg_of(design), ())),
             line,
           )
         );

    Components_core.box(
      ~id?,
      ~style=
        Style.{
          ...
            make(
              ~border=Single,
              ~border_fg=accent,
              ~padding=spacing_xy(~x=1, ~y=0),
              ~margin=spacing(~bottom=1, ()),
              (),
            ),

          width: style.width,
          height: style.height,
          flex_grow: style.flex_grow,
        },
      [header, ...lines],
    );
  };

  let timeline = (~id=?, ~style=Style.default, ~design=?, entries) => {
    let design = Components_core.resolve_design(design);
    let row = ((tone, label, detail)) =>
      Components_core.rich_text([
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Components_core.color_of_tone(~design, tone),
                ~attrs=[Attr.Bold],
                (),
              )
            ),
          "● ",
        ),
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Components_core.emphasis_fg_of(design),
                ~attrs=[Attr.Bold],
                (),
              )
            ),
          label,
        ),
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Components_core.muted_fg_of(design),
                ~attrs=[Attr.Dim],
                (),
              )
            ),
          "  " ++ detail,
        ),
      ]);

    Components_core.box(
      ~id?,
      ~style=
        Style.{
          ...style,
          flex_direction: Column,
        },
      List.map(row, entries),
    );
  };

  let composer =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~prompt=">",
        ~placeholder="Type a message",
        (),
      ) => {
    let design = Components_core.resolve_design(design);
    let accent =
      Components_core.color_of_tone(~design, Components_core.Accent);
    Components_core.box(
      ~id?,
      ~style=
        Style.{
          ...
            make(
              ~border=Rounded,
              ~border_fg=accent,
              ~height=Cells(3),
              ~padding=spacing_xy(~x=1, ~y=0),
              (),
            ),

          width: style.width,
          margin: style.margin,
        },
      [
        Components_core.box(
          ~style=Style.(make(~flex_direction=Row, ~gap=1, ())),
          [
            Components_core.text(
              ~style=Style.(make(~fg=accent, ~attrs=[Attr.Bold], ())),
              prompt,
            ),
            Components_core.input(
              ~style=Style.(make(~flex_grow=1., ())),
              ~placeholder,
              (),
            ),
          ],
        ),
      ],
    );
  };

  let command_bar = (~id=?, ~style=Style.default, ~design=?, items) => {
    let design = Components_core.resolve_design(design);
    let content =
      items
      |> List.map(((key, label)) => "[" ++ key ++ "]" ++ label)
      |> String.concat(" ");
    Node.text(
      ~id?,
      ~style=
        Style.{
          ...
            make(
              ~height=Cells(1),
              ~width=Percent(1.),
              ~bg=Components_core.overlay_of(design),
              ~fg=Components_core.default_fg_of(design),
              ~attrs=[Attr.Dim],
              (),
            ),

          margin: style.margin,
        },
      content,
    );
  };

  let footer = (~design=?, shortcuts) => command_bar(~design?, shortcuts);

  let app_shell =
      (
        ~id=?,
        ~title="App",
        ~subtitle=?,
        ~badges=[],
        ~footer_items=[("q", "uit"), ("?", "help"), ("Tab", "focus")],
        ~design=?,
        body,
      ) =>
    Components_core.box(
      ~id?,
      ~style=
        Style.(
          make(
            ~width=Percent(1.),
            ~height=Percent(1.),
            ~flex_direction=Column,
            (),
          )
        ),
      [
        header(~subtitle?, ~badges, ~design?, title),
        Components_core.box(
          ~style=
            Style.(
              make(
                ~flex_grow=1.,
                ~flex_direction=Column,
                ~padding=spacing_xy(~x=1, ~y=0),
                (),
              )
            ),
          body,
        ),
        command_bar(~design?, footer_items),
      ],
    );
