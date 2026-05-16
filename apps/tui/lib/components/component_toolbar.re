let make = (~id=?, ~style=Style.default, ~design=?, items) => {
  let design = Component_design.resolve_design(design);
  let spans =
    items
    |> List.concat_map(((key, label)) => [
         Span.make(
           ~style=
             Style.(
               make(
                 ~fg=Component_design.emphasis_fg_of(design),
                 ~attrs=[Attr.Bold],
                 (),
               )
             ),
           "[" ++ key ++ "]",
         ),
         Span.make(
           ~style=
             Style.(
               make(
                 ~fg=Component_design.muted_fg_of(design),
                 ~attrs=[Attr.Dim],
                 (),
               )
             ),
           label ++ " ",
         ),
       ]);

  Node.rich_text(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~height=Cells(1),
            ~fg=Component_design.default_fg_of(design),
            (),
          ),

        width: style.width,
        margin: style.margin,
      },
    spans,
  );
};
