  let style_with = (~fg=?, ~bg=?, ~attrs=?, base) => {
    let base =
      switch (fg) {
      | None => base
      | Some(fg) => Style.with_fg(fg, base)
      };
    let base =
      switch (bg) {
      | None => base
      | Some(bg) => Style.with_bg(bg, base)
      };
    switch (attrs) {
    | None => base
    | Some(attrs) => Style.with_attrs(attrs, base)
    };
  };

  type border_chars = {
    tl: string,
    tr: string,
    bl: string,
    br: string,
    h: string,
    v: string,
  };

  let border_chars =
    fun
    | Style.Single => {
        tl: "┌",
        tr: "┐",
        bl: "└",
        br: "┘",
        h: "─",
        v: "│",
      }
    | Style.Rounded => {
        tl: "╭",
        tr: "╮",
        bl: "╰",
        br: "╯",
        h: "─",
        v: "│",
      }
    | Style.Double => {
        tl: "╔",
        tr: "╗",
        bl: "╚",
        br: "╝",
        h: "═",
        v: "║",
      }
    | Style.Heavy => {
        tl: "┏",
        tr: "┓",
        bl: "┗",
        br: "┛",
        h: "━",
        v: "┃",
      };

  let write_clipped = (surface, clip, x, y, style, text) =>
    ignore(Surface.write(~clip, surface, ~x, ~y, ~style, text));

  let draw_title = (surface, clip, rect: Geometry.rect, style, align, title) => {
    let width = Utf.string_width(title) + 2;
    if (rect.Geometry.width > 4 && width < rect.width) {
      let x =
        switch (align) {
        | Style.Title_left => rect.x + 2
        | Style.Title_center => rect.x + (rect.width - width) / 2
        | Style.Title_right => rect.x + rect.width - width - 1
        };

      write_clipped(surface, clip, x, rect.y, style, " " ++ title ++ " ");
    };
  };

  let draw_bottom_title =
      (surface, clip, rect: Geometry.rect, style, align, title) => {
    let width = Utf.string_width(title) + 2;
    if (rect.Geometry.width > 4 && width < rect.width) {
      let x =
        switch (align) {
        | Style.Title_left => rect.x + 2
        | Style.Title_center => rect.x + (rect.width - width) / 2
        | Style.Title_right => rect.x + rect.width - width - 1
        };

      write_clipped(
        surface,
        clip,
        x,
        rect.y + rect.height - 1,
        style,
        " " ++ title ++ " ",
      );
    };
  };

  let draw_border = (surface, clip, rect: Geometry.rect, style) =>
    switch (style.Style.border) {
    | None => ()
    | Some(border) when rect.width >= 2 && rect.height >= 2 =>
      let chars = border_chars(border);
      let border_style =
        switch (style.border_fg) {
        | None => style
        | Some(fg) => Style.with_fg(fg, style)
        };

      Surface.set(
        ~clip,
        surface,
        ~x=rect.x,
        ~y=rect.y,
        ~style=border_style,
        chars.tl,
      );
      Surface.set(
        ~clip,
        surface,
        ~x=rect.x + rect.width - 1,
        ~y=rect.y,
        ~style=border_style,
        chars.tr,
      );
      Surface.set(
        ~clip,
        surface,
        ~x=rect.x,
        ~y=rect.y + rect.height - 1,
        ~style=border_style,
        chars.bl,
      );
      Surface.set(
        ~clip,
        surface,
        ~x=rect.x + rect.width - 1,
        ~y=rect.y + rect.height - 1,
        ~style=border_style,
        chars.br,
      );
      for (x in rect.x + 1 to rect.x + rect.width - 2) {
        Surface.set(
          ~clip,
          surface,
          ~x,
          ~y=rect.y,
          ~style=border_style,
          chars.h,
        );
        Surface.set(
          ~clip,
          surface,
          ~x,
          ~y=rect.y + rect.height - 1,
          ~style=border_style,
          chars.h,
        );
      };
      for (y in rect.y + 1 to rect.y + rect.height - 2) {
        Surface.set(
          ~clip,
          surface,
          ~x=rect.x,
          ~y,
          ~style=border_style,
          chars.v,
        );
        Surface.set(
          ~clip,
          surface,
          ~x=rect.x + rect.width - 1,
          ~y,
          ~style=border_style,
          chars.v,
        );
      };
      Option.iter(
        draw_title(surface, clip, rect, border_style, style.title_align),
        style.title,
      );
      Option.iter(
        draw_bottom_title(
          surface,
          clip,
          rect,
          border_style,
          style.bottom_title_align,
        ),
        style.bottom_title,
      );
    | _ => ()
    };

  let fill_background = (surface, clip, rect: Geometry.rect, style) =>
    switch (style.Style.bg) {
    | None => ()
    | Some(_) => Surface.fill_rect(~clip, surface, rect, ~style)
    };

  let render_text = (surface, clip, rect: Geometry.rect, spans) => {
    let x = ref(rect.Geometry.x);
    let y = ref(rect.y);
    List.iter(
      span => {
        let (nx, ny) =
          Surface.write(
            ~clip,
            surface,
            ~x=x^,
            ~y=y^,
            ~style=span.Span.style,
            span.text,
          );
        x := nx;
        y := ny;
      },
      spans,
    );
  };

  let render_input =
      (
        surface,
        clip,
        rect: Geometry.rect,
        node_style,
        state: Node.input_state,
        focused,
      ) => {
    Surface.fill_rect(~clip, surface, rect, ~style=node_style);
    let text_style =
      if (state.Node.value == "") {
        Style.add_attr(Attr.Dim, node_style);
      } else {
        node_style;
      };

    let text =
      if (state.value == "") {
        state.placeholder;
      } else {
        state.value;
      };
    write_clipped(surface, clip, rect.x, rect.y, text_style, text);
    if (focused && rect.width > 0) {
      let cursor_x = rect.x + min(rect.width - 1, state.cursor);
      let cursor_style = Style.add_attr(Attr.Inverse, node_style);
      let ch =
        if (state.cursor < String.length(state.value)) {
          String.make(1, state.value.[state.cursor]);
        } else {
          " ";
        };

      Surface.set(
        ~clip,
        surface,
        ~x=cursor_x,
        ~y=rect.y,
        ~style=cursor_style,
        ch,
      );
    };
  };

  let ensure_select_visible = (state: Node.select_state, height) => {
    if (state.Node.selected < state.scroll) {
      state.scroll = state.selected;
    };
    if (state.selected >= state.scroll + height) {
      state.scroll = state.selected - height + 1;
    };
    state.scroll = max(0, state.scroll);
  };

  let render_select =
      (
        surface,
        clip,
        rect: Geometry.rect,
        node_style,
        state: Node.select_state,
        focused,
      ) => {
    Surface.fill_rect(~clip, surface, rect, ~style=node_style);
    let height = max(0, rect.Geometry.height);
    ensure_select_visible(state, height);
    let selected_bg =
      Option.value(~default=Color.ansi(4), node_style.Style.bg)
      |> (_ => Color.indexed(60));

    for (row in 0 to height - 1) {
      let index = state.Node.scroll + row;
      switch (List.nth_opt(state.options, index)) {
      | None => ()
      | Some(option) =>
        let selected = index == state.selected;
        let row_style =
          if (selected) {
            node_style
            |> Style.with_bg(selected_bg)
            |> Style.add_attr(if (focused) {Attr.Bold} else {Attr.Inverse});
          } else {
            node_style;
          };

        let y = rect.y + row;
        Surface.fill_rect(
          ~clip,
          surface,
          Geometry.rect(~x=rect.x, ~y, ~width=rect.width, ~height=1),
          ~style=row_style,
        );
        let prefix = if (selected) {"> "} else {"  "};
        let description =
          if (state.show_description && option.description != "") {
            " - " ++ option.description;
          } else {
            "";
          };

        write_clipped(
          surface,
          clip,
          rect.x,
          y,
          row_style,
          prefix ++ option.name ++ description,
        );
      };
    };
  };

  let render_progress =
      (surface, clip, rect: Geometry.rect, style, state: Node.progress_state) => {
    Surface.fill_rect(~clip, surface, rect, ~style);
    if (rect.Geometry.width > 0) {
      let label =
        switch (state.Node.label) {
        | Some(label) => label
        | None => Printf.sprintf("%3.0f%%", state.fraction *. 100.)
        };

      let label_width = Utf.string_width(label) + 1;
      let bar_width = max(1, rect.width - label_width);
      let filled =
        int_of_float(Float.floor(state.fraction *. float(bar_width)));
      let full_style = style |> Style.with_fg(Color.ansi(2));
      let empty_style = style |> Style.add_attr(Attr.Dim);
      for (i in 0 to bar_width - 1) {
        let (ch, cell_style) =
          if (i < filled) {
            ("█", full_style);
          } else {
            ("░", empty_style);
          };
        Surface.set(
          ~clip,
          surface,
          ~x=rect.x + i,
          ~y=rect.y,
          ~style=cell_style,
          ch,
        );
      };
      write_clipped(
        surface,
        clip,
        rect.x + bar_width + 1,
        rect.y,
        style,
        label,
      );
    };
  };

  let render_sparkline = (surface, clip, rect: Geometry.rect, style, values) => {
    let frames = [|"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"|];
    switch (values) {
    | [] => ()
    | _ =>
      let min_v = List.fold_left(min, infinity, values);
      let max_v = List.fold_left(max, neg_infinity, values);
      let span =
        if (Float.equal(min_v, max_v)) {
          1.;
        } else {
          max_v -. min_v;
        };
      values
      |> List.iteri((i, value) =>
           if (i < rect.Geometry.width) {
             let bucket =
               int_of_float(Float.floor((value -. min_v) /. span *. 7.))
               |> max(0)
               |> min(7);
             Surface.set(
               ~clip,
               surface,
               ~x=rect.x + i,
               ~y=rect.y,
               ~style,
               frames[bucket],
             );
           }
         );
    };
  };

  let render_vertical_rule = (surface, clip, rect: Geometry.rect, style, char) =>
    for (y in rect.Geometry.y to rect.y + rect.height - 1) {
      Surface.set(~clip, surface, ~x=rect.x, ~y, ~style, char);
    };

  let rec render_node = (surface, positioned: Layout.positioned) => {
    let node = positioned.node;
    fill_background(surface, positioned.clip, positioned.rect, node.style);
    draw_border(surface, positioned.clip, positioned.rect, node.style);
    switch (node.kind) {
    | Text(spans) =>
      render_text(surface, positioned.clip, positioned.content, spans)
    | Vertical_rule(char) =>
      render_vertical_rule(
        surface,
        positioned.clip,
        positioned.content,
        node.style,
        char,
      )
    | Input(state) =>
      render_input(
        surface,
        positioned.clip,
        positioned.content,
        node.style,
        state,
        node.focused,
      )
    | Select(state) =>
      render_select(
        surface,
        positioned.clip,
        positioned.content,
        node.style,
        state,
        node.focused,
      )
    | Progress_bar(state) =>
      render_progress(
        surface,
        positioned.clip,
        positioned.content,
        node.style,
        state,
      )
    | Sparkline(values) =>
      render_sparkline(
        surface,
        positioned.clip,
        positioned.content,
        node.style,
        values,
      )
    | Box
    | Scroll_box(_)
    | Spacer => ()
    };
    List.iter(render_node(surface), positioned.children);
  };

  let render = (root, ~width, ~height) => {
    let surface = Surface.create(~width, ~height, ());
    let positioned = Layout.compute(root, ~width, ~height);
    render_node(surface, positioned);
    surface;
  };
