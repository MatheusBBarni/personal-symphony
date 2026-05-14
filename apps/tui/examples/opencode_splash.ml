open Tui
open Tui.Components
open Tui.Patterns
open Tui.Presets.Open_code

let clamp low high value = max low (min high value)

let prompt width =
  rule_panel ~tone:Accent
    ~style:Style.(make ~width:(Cells width) ~height:(Cells 5) ())
    [
      rich_text
        [
          Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Status_info) ~attrs:[ Attr.Inverse ] ()) "A";
          Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "sk anything... \"Fix broken tests\"";
        ];
      model_status ();
    ]

let footer =
  Components.row
    ~style:Style.(make ~height:(Cells 1) ~width:(Percent 1.) ~justify_content:Space_between ~padding:(spacing_xy ~x:2 ~y:0) ())
    [
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "apps/tui";
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "1.14.48";
    ]

let root viewport =
  let width = viewport.Viewport.width in
  let height = viewport.Viewport.height in
  let prompt_width =
    clamp 28 (max 1 (width - 8)) (int_of_float (float width *. 0.78))
  in
  let show_wordmark = width >= 96 && height >= 27 in
  let tip_text =
    if width < 84 then "Run /share to create a public link."
    else "Run /share to create a public link to your conversation at opencode."
  in
  let middle =
    [
      (if show_wordmark then
         wordmark
           ~style:Style.(make ~margin:(spacing ~bottom:2 ()) ())
           "opencode"
       else spacer ~style:Style.(make ~height:(Cells 1) ()) ());
      prompt prompt_width;
      box
        ~style:Style.(make ~width:(Cells prompt_width) ~align_items:Align_end ())
        [ hint_bar [ ("tab", "agents"); ("ctrl+p", "commands") ] ];
    ]
  in
  box
    ~style:
      Style.(
        make ~width:(Percent 1.) ~height:(Percent 1.) ~flex_direction:Column
          ~bg:(Theme.dark Theme.Bg_base) ())
    [
      spacer ~style:Style.(make ~flex_grow:(if show_wordmark then 1.2 else 0.7) ()) ();
      box
        ~style:Style.(make ~width:(Percent 1.) ~align_items:Align_center ~gap:1 ())
        middle;
      spacer ~style:Style.(make ~flex_grow:0.5 ()) ();
      box
        ~style:Style.(make ~width:(Percent 1.) ~align_items:Align_center ())
        [ tip tip_text ];
      spacer ~style:Style.(make ~flex_grow:1. ()) ();
      footer;
    ]

let run_preview renderer =
  let input = Unix.descr_of_in_channel stdin in
  let output = Unix.descr_of_out_channel stdout in
  if Terminal.is_interactive ~fd:input () && Terminal.is_interactive ~fd:output () then
    Fun.protect
      ~finally:Terminal.leave_alternate
      (fun () ->
        Terminal.enter_alternate ();
        Renderer.render renderer;
        Terminal.with_raw input (fun () -> ignore (Key.read input)))
  else print_string (Renderer.render_to_string ~ansi:true renderer)

let () =
  let viewport = Terminal.viewport () in
  let renderer =
    Renderer.create ~width:viewport.width ~height:viewport.height (root viewport)
  in
  run_preview renderer
