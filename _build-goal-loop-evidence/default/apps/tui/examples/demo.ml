open Tui

let panel title children =
  box
    ~style:
      Style.(
        make ~border:Rounded ~border_fg:(Theme.dark Theme.Accent_primary)
          ~title ~padding:(spacing_all 1) ~margin:(spacing_all 1)
          ~flex_grow:1. ())
    children

let () =
  let menu =
    select
      ~style:Style.(make ~width:(Cells 28) ~height:(Cells 6) ())
      [
        option ~description:"Buffered, diffed cells" "Renderer";
        option ~description:"Toffee flexbox layout" "Layout";
        option ~description:"Input, select, bars" "Widgets";
        option ~description:"Layered shortcuts" "Keymap";
      ]
  in
  let root =
    box
      ~style:Style.(make ~width:(Percent 1.) ~height:(Percent 1.) ~flex_direction:Column ())
      [
        box
          ~style:Style.(make ~height:(Cells 3) ~padding:(spacing_xy ~x:2 ~y:1) ())
          [ text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_emphasis) ~attrs:[ Attr.Bold ] ()) "Symphony TUI" ];
        box
          ~style:Style.(make ~flex_grow:1. ~flex_direction:Row ())
          [
            panel "Components" [ menu ];
            panel "Status"
              [
                text "OCaml-native component tree";
                progress_bar ~label:"build" 0.72;
                sparkline [ 3.; 5.; 4.; 9.; 6.; 8.; 12.; 10.; 13.; 11. ];
                input ~style:Style.(make ~width:(Cells 24) ()) ~placeholder:"type here" ();
              ];
          ];
        Patterns.footer [ ("q", "uit"); ("/", "search"); ("?", "help"); ("Tab", "focus") ];
      ]
  in
  let renderer = Renderer.create ~width:96 ~height:24 root in
  print_endline (Renderer.render_to_string renderer)
