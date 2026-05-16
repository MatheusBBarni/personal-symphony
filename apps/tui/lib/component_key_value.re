let make = (~id=?, ~label_width=12, ~style=Style.default, ~design=?, pairs) => {
  let design = Component_design.resolve_design(design);
  let rows =
    pairs
    |> List.map(((key, value)) => {
         let key_text =
           if (String.length(key) >= label_width) {
             key;
           } else {
             key ++ String.make(label_width - String.length(key), ' ');
           };
         Node.rich_text([
           Span.make(
             ~style=
               Style.(
                 make(
                   ~fg=Component_design.muted_fg_of(design),
                   ~attrs=[Attr.Dim],
                   (),
                 )
               ),
             key_text,
           ),
           Span.make(
             ~style=
               Style.(make(~fg=Component_design.default_fg_of(design), ())),
             value,
           ),
         ]);
       });

  Node.box(
    ~id?,
    ~style=
      Style.{
        ...style,
        flex_direction: Column,
      },
    rows,
  );
};
