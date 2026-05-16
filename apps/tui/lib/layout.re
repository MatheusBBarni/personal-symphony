  module T = Toffee;
  module TG = Toffee.Geometry;

  type positioned = {
    node: Node.t,
    rect: Geometry.rect,
    content: Geometry.rect,
    clip: Geometry.rect,
    children: list(positioned),
  };

  let ok =
    fun
    | Ok(v) => v
    | Error(err) => invalid_arg(Toffee.Error.to_string(err));
  let f = i => float_of_int(i);
  let round = f => int_of_float(Float.round(f));

  let to_dimension =
    fun
    | Style.Auto => T.Style.Dimension.auto
    | Style.Cells(n) => T.Style.Dimension.px(f(n))
    | Style.Percent(p) => T.Style.Dimension.percent(p);

  let to_length =
    fun
    | Style.Auto => T.Style.Length_percentage.zero
    | Style.Cells(n) => T.Style.Length_percentage.px(f(n))
    | Style.Percent(p) => T.Style.Length_percentage.percent(p);

  let to_length_auto =
    fun
    | Style.Auto => T.Style.Length_percentage_auto.auto
    | Style.Cells(n) => T.Style.Length_percentage_auto.px(f(n))
    | Style.Percent(p) => T.Style.Length_percentage_auto.percent(p);

  let rect_of_spacing = (s: Style.spacing, ~auto) =>
    if (auto) {
      TG.Rect.{
        left: T.Style.Length_percentage_auto.px(f(s.Style.left)),
        right: T.Style.Length_percentage_auto.px(f(s.right)),
        top: T.Style.Length_percentage_auto.px(f(s.top)),
        bottom: T.Style.Length_percentage_auto.px(f(s.bottom)),
      };
    } else {
      TG.Rect.{
        left: T.Style.Length_percentage.px(f(s.Style.left)),
        right: T.Style.Length_percentage.px(f(s.right)),
        top: T.Style.Length_percentage.px(f(s.top)),
        bottom: T.Style.Length_percentage.px(f(s.bottom)),
      };
    };

  let border_rect = style => {
    let width = Style.border_width(style) |> f;
    TG.Rect.{
      left: T.Style.Length_percentage.px(width),
      right: T.Style.Length_percentage.px(width),
      top: T.Style.Length_percentage.px(width),
      bottom: T.Style.Length_percentage.px(width),
    };
  };

  let to_flex_direction =
    fun
    | Style.Row => T.Style.Flex_direction.Row
    | Style.Column => T.Style.Flex_direction.Column
    | Style.Row_reverse => T.Style.Flex_direction.Row_reverse
    | Style.Column_reverse => T.Style.Flex_direction.Column_reverse;

  let to_justify =
    fun
    | Style.Justify_start => T.Style.Align_content.Flex_start
    | Style.Justify_end => T.Style.Align_content.Flex_end
    | Style.Justify_center => T.Style.Align_content.Center
    | Style.Space_between => T.Style.Align_content.Space_between
    | Style.Space_around => T.Style.Align_content.Space_around
    | Style.Space_evenly => T.Style.Align_content.Space_evenly;

  let to_align =
    fun
    | Style.Align_start => T.Style.Align_items.Flex_start
    | Style.Align_end => T.Style.Align_items.Flex_end
    | Style.Align_center => T.Style.Align_items.Center
    | Style.Align_stretch => T.Style.Align_items.Stretch;

  let to_position =
    fun
    | Style.Relative => T.Style.Position.Relative
    | Style.Absolute => T.Style.Position.Absolute;

  let to_inset = style =>
    TG.Rect.{
      left:
        Option.fold(
          ~none=T.Style.Length_percentage_auto.auto,
          ~some=n => T.Style.Length_percentage_auto.px(f(n)),
          style.Style.left,
        ),
      right:
        Option.fold(
          ~none=T.Style.Length_percentage_auto.auto,
          ~some=n => T.Style.Length_percentage_auto.px(f(n)),
          style.right,
        ),
      top:
        Option.fold(
          ~none=T.Style.Length_percentage_auto.auto,
          ~some=n => T.Style.Length_percentage_auto.px(f(n)),
          style.top,
        ),
      bottom:
        Option.fold(
          ~none=T.Style.Length_percentage_auto.auto,
          ~some=n => T.Style.Length_percentage_auto.px(f(n)),
          style.bottom,
        ),
    };

  let toffee_style = style =>
    T.Style.make(
      ~display=T.Style.Display.Flex,
      ~position=to_position(style.Style.position),
      ~inset=to_inset(style),
      ~size=
        TG.Size.{
          width: to_dimension(style.width),
          height: to_dimension(style.height),
        },
      ~min_size=
        TG.Size.{
          width: to_dimension(style.min_width),
          height: to_dimension(style.min_height),
        },
      ~margin=rect_of_spacing(style.margin, ~auto=true),
      ~padding=rect_of_spacing(style.padding, ~auto=false),
      ~border=border_rect(style),
      ~gap=
        TG.Size.{
          width: to_length(Style.Cells(style.gap)),
          height: to_length(Style.Cells(style.gap)),
        },
      ~flex_direction=to_flex_direction(style.flex_direction),
      ~justify_content=to_justify(style.justify_content),
      ~align_items=to_align(style.align_items),
      ~flex_grow=style.flex_grow,
      ~flex_shrink=style.flex_shrink,
      (),
    );

  let intrinsic_size = node =>
    switch (node.Node.kind) {
    | Text(spans) =>
      let text =
        spans |> List.map(span => span.Span.text) |> String.concat("");
      (Utf.longest_line_width(text), Utf.line_count(text));
    | Vertical_rule(char) => (max(1, Utf.string_width(char)), 1)
    | Input(state) => (
        max(
          1,
          max(
            Utf.string_width(state.value),
            Utf.string_width(state.placeholder),
          )
          + 1,
        ),
        1,
      )
    | Select(state) =>
      let item_width = option =>
        Utf.string_width(option.Node.name)
        + (
          if (state.show_description && option.description != "") {
            Utf.string_width(option.description) + 3;
          } else {
            0;
          }
        );

      let width =
        List.fold_left(
          (acc, option) => max(acc, item_width(option) + 2),
          1,
          state.options,
        );
      let height = max(1, min(8, List.length(state.options)));
      (width, height);
    | Progress_bar(_) => (20, 1)
    | Sparkline(values) => (max(1, List.length(values)), 1)
    | Box
    | Scroll_box(_)
    | Spacer => (0, 0)
    };

  let measure = (known, _available, _node_id, context, _style) => {
    let (width, height) =
      switch (context) {
      | Some(node) => intrinsic_size(node)
      | None => (0, 0)
      };

    TG.Size.{
      width: Option.value(~default=f(width), known.width),
      height: Option.value(~default=f(height), known.height),
    };
  };

  let compute = (root, ~width, ~height) => {
    let tree = T.new_tree();
    let node_ids = Hashtbl.create(32);
    let rec build = (is_root, node) => {
      let style =
        if (is_root) {
          Style.with_size(
            ~width=Style.Cells(width),
            ~height=Style.Cells(height),
            node.Node.style,
          );
        } else {
          node.style;
        };

      let child_ids =
        node.children |> List.map(build(false)) |> Array.of_list;
      let id =
        if (Array.length(child_ids) == 0) {
          T.new_leaf_with_context(tree, toffee_style(style), node) |> ok;
        } else {
          T.new_with_children(tree, toffee_style(style), child_ids) |> ok;
        };

      ignore(T.set_node_context(tree, id, Some(node)) |> ok);
      Hashtbl.add(node_ids, node.Node.id, id);
      id;
    };

    let root_id = build(true, root);
    let available =
      TG.Size.{
        width: T.Available_space.of_length(f(width)),
        height: T.Available_space.of_length(f(height)),
      };
    T.compute_layout_with_measure(tree, root_id, available, measure) |> ok;
    let rec collect = (origin: Geometry.point, clip, node) => {
      let id = Hashtbl.find(node_ids, node.Node.id);
      let layout = T.layout(tree, id) |> ok;
      let margin = layout.margin;
      let rect =
        Geometry.rect(
          ~x=origin.Geometry.x + round(layout.location.x +. margin.left),
          ~y=origin.y + round(layout.location.y +. margin.top),
          ~width=max(0, round(layout.size.width)),
          ~height=max(0, round(layout.size.height)),
        );

      let content =
        Geometry.rect(
          ~x=origin.x + round(T.Layout.content_box_x(layout)),
          ~y=origin.y + round(T.Layout.content_box_y(layout)),
          ~width=max(0, round(T.Layout.content_box_width(layout))),
          ~height=max(0, round(T.Layout.content_box_height(layout))),
        );

      let own_clip = Geometry.intersect(clip, rect);
      let child_clip = Geometry.intersect(clip, content);
      let (child_origin, child_clip) =
        switch (node.kind) {
        | Scroll_box(state) => (
            Geometry.point(
              ~x=rect.x - state.scroll_x,
              ~y=rect.y - state.scroll_y,
            ),
            child_clip,
          )
        | _ => (Geometry.point(~x=rect.x, ~y=rect.y), child_clip)
        };

      let children =
        List.map(collect(child_origin, child_clip), node.children);
      {
        node,
        rect,
        content,
        clip: own_clip,
        children,
      };
    };

    collect(
      Geometry.point(~x=0, ~y=0),
      Geometry.rect(~x=0, ~y=0, ~width, ~height),
      root,
    );
  };
