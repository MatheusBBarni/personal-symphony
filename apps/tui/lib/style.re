  type length =
    | Auto
    | Cells(int)
    | Percent(float);
  type spacing = {
    left: int,
    right: int,
    top: int,
    bottom: int,
  };
  type flex_direction =
    | Row
    | Column
    | Row_reverse
    | Column_reverse;
  type justify =
    | Justify_start
    | Justify_end
    | Justify_center
    | Space_between
    | Space_around
    | Space_evenly;
  type align =
    | Align_start
    | Align_end
    | Align_center
    | Align_stretch;
  type border_style =
    | Single
    | Rounded
    | Double
    | Heavy;
  type title_align =
    | Title_left
    | Title_center
    | Title_right;
  type position =
    | Relative
    | Absolute;

  type t = {
    fg: option(Color.t),
    bg: option(Color.t),
    attrs: list(Attr.t),
    width: length,
    height: length,
    min_width: length,
    min_height: length,
    flex_grow: float,
    flex_shrink: float,
    flex_direction,
    justify_content: justify,
    align_items: align,
    position,
    left: option(int),
    top: option(int),
    right: option(int),
    bottom: option(int),
    padding: spacing,
    margin: spacing,
    gap: int,
    border: option(border_style),
    border_fg: option(Color.t),
    title: option(string),
    title_align,
    bottom_title: option(string),
    bottom_title_align: title_align,
  };

  let spacing = (~left=0, ~right=0, ~top=0, ~bottom=0, ()) => {
    left,
    right,
    top,
    bottom,
  };

  let spacing_all = n => spacing(~left=n, ~right=n, ~top=n, ~bottom=n, ());
  let spacing_xy = (~x, ~y) =>
    spacing(~left=x, ~right=x, ~top=y, ~bottom=y, ());

  let default = {
    fg: None,
    bg: None,
    attrs: [],
    width: Auto,
    height: Auto,
    min_width: Cells(0),
    min_height: Cells(0),
    flex_grow: 0.,
    flex_shrink: 0.,
    flex_direction: Column,
    justify_content: Justify_start,
    align_items: Align_stretch,
    position: Relative,
    left: None,
    top: None,
    right: None,
    bottom: None,
    padding: spacing_all(0),
    margin: spacing_all(0),
    gap: 0,
    border: None,
    border_fg: None,
    title: None,
    title_align: Title_left,
    bottom_title: None,
    bottom_title_align: Title_left,
  };

  let make =
      (
        ~fg=?,
        ~bg=?,
        ~attrs=[],
        ~width=Auto,
        ~height=Auto,
        ~min_width=Cells(0),
        ~min_height=Cells(0),
        ~flex_grow=0.,
        ~flex_shrink=0.,
        ~flex_direction=Column,
        ~justify_content=Justify_start,
        ~align_items=Align_stretch,
        ~position=Relative,
        ~left=?,
        ~top=?,
        ~right=?,
        ~bottom=?,
        ~padding=spacing_all(0),
        ~margin=spacing_all(0),
        ~gap=0,
        ~border=?,
        ~border_fg=?,
        ~title=?,
        ~title_align=Title_left,
        ~bottom_title=?,
        ~bottom_title_align=Title_left,
        (),
      ) => {
    fg,
    bg,
    attrs,
    width,
    height,
    min_width,
    min_height,
    flex_grow,
    flex_shrink,
    flex_direction,
    justify_content,
    align_items,
    position,
    left,
    top,
    right,
    bottom,
    padding,
    margin,
    gap,
    border,
    border_fg,
    title,
    title_align,
    bottom_title,
    bottom_title_align,
  };

  let with_fg = (fg, t) => {
    ...t,
    fg: Some(fg),
  };
  let with_bg = (bg, t) => {
    ...t,
    bg: Some(bg),
  };
  let with_attrs = (attrs, t) => {
    ...t,
    attrs,
  };
  let add_attr = (attr, t) => {
    ...t,
    attrs: Attr.add(attr, t.attrs),
  };
  let with_width = (width, t) => {
    ...t,
    width,
  };
  let with_height = (height, t) => {
    ...t,
    height,
  };
  let with_size = (~width, ~height, t) => {
    ...t,
    width,
    height,
  };
  let with_border = (border, t) => {
    ...t,
    border: Some(border),
  };
  let without_border = t => {
    ...t,
    border: None,
  };

  let paint_equal = (a, b) =>
    Color.equal(
      Option.value(~default=Color.Default, a.fg),
      Option.value(~default=Color.Default, b.fg),
    )
    && Color.equal(
         Option.value(~default=Color.Default, a.bg),
         Option.value(~default=Color.Default, b.bg),
       )
    && a.attrs == b.attrs;

  let border_width = t =>
    switch (t.border) {
    | Some(_) => 1
    | None => 0
    };

  let to_ansi = (~level=Color.detect_level(), t) =>
    if (level == Color.No_color) {
      "";
    } else {
      let codes = ref(["0"]);
      switch (t.fg) {
      | None => ()
      | Some(c) =>
        codes := [Color.fg_code(Color.degrade(level, c)), ...codes^]
      };
      switch (t.bg) {
      | None => ()
      | Some(c) =>
        codes := [Color.bg_code(Color.degrade(level, c)), ...codes^]
      };
      List.iter(attr => codes := [Attr.code(attr), ...codes^], t.attrs);
      "\027[" ++ String.concat(";", List.rev(codes^)) ++ "m";
    };
