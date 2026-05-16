let make =
    (
      ~id=?,
      ~tone=Component_design.Neutral,
      ~detail=?,
      ~action=?,
      ~style=Style.default,
      ~design=?,
      title,
    ) => {
  let design = Component_design.resolve_design(design);
  let accent = Component_design.color_of_tone(~design, tone);
  let children =
    [
      Node.text(
        ~style=Style.(make(~fg=accent, ~attrs=[Attr.Bold], ())),
        title,
      ),
    ]
    @ (
      switch (detail) {
      | None => []
      | Some(detail) => [
          Node.text(
            ~style=
              Style.(
                make(
                  ~fg=Component_design.muted_fg_of(design),
                  ~attrs=[Attr.Dim],
                  (),
                )
              ),
            detail,
          ),
        ]
      }
    )
    @ (
      switch (action) {
      | None => []
      | Some(action) => [
          Node.text(
            ~style=
              Style.(
                make(
                  ~fg=Component_design.default_fg_of(design),
                  ~attrs=[Attr.Bold],
                  (),
                )
              ),
            action,
          ),
        ]
      }
    );

  Node.box(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~flex_direction=Column,
            ~align_items=Align_center,
            ~gap=1,
            ~padding=spacing_all(1),
            (),
          ),

        width: style.width,
        height: style.height,
        flex_grow: style.flex_grow,
        margin: style.margin,
      },
    children,
  );
};
