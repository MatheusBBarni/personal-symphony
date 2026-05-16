let make =
    (
      ~id=?,
      ~tone=Component_design.Accent,
      ~title_align=Style.Title_left,
      ~bottom_title=?,
      ~style=Style.default,
      ~design=?,
      title,
      children,
    ) => {
  let design = Component_design.resolve_design(design);
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~border=Rounded,
            ~title,
            ~title_align,
            ~bottom_title?,
            ~border_fg=Component_design.color_of_tone(~design, tone),
            ~padding=spacing_all(1),
            (),
          ),

        width: style.width,
        height: style.height,
        min_width: style.min_width,
        min_height: style.min_height,
        flex_grow: style.flex_grow,
        flex_shrink: style.flex_shrink,
        flex_direction: style.flex_direction,
        justify_content: style.justify_content,
        align_items: style.align_items,
        position: style.position,
        left: style.left,
        top: style.top,
        right: style.right,
        bottom: style.bottom,
        margin: style.margin,
        gap: style.gap,
        fg:
          switch (style.fg) {
          | Some(_) => style.fg
          | None => Some(Component_design.default_fg_of(design))
          },
        bg: style.bg,
        attrs: style.attrs,
      },
    children,
  );
};
