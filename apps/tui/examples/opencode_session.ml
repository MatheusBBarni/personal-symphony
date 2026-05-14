open Tui
open Tui.Components

let clamp low high value = max low (min high value)

let conversation width =
  let compact = width < 78 in
  [
    command_block ~style:Style.(make ~height:(Cells 4) ()) "cat package.json";
    rich_text
      [
        Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "│  ";
        Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Status_warning) ~attrs:[ Attr.Italic ] ()) "Thinking:";
        Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ())
          (if compact then " Reading package.json." else " The user wants to see the contents of package.json. Let me read it.");
      ];
    rich_text
      [
        Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "   → Read package.json";
      ];
    text
      ~style:Style.(make ~fg:(Theme.dark Theme.Status_error) ())
      (if compact then "   File not found: package.json"
       else "   File not found: apps/tui/package.json");
    (if compact then model_status ~model:"DeepSeek V4" ~provider:"OpenCode" () else model_status ());
  ]

let composer height =
  rule_panel ~tone:Accent
    ~style:Style.(make ~height:(Cells height) ())
    [
      text ~style:Style.(make ~fg:(Theme.dark Theme.Status_info) ~attrs:[ Attr.Inverse ] ()) " ";
      model_status ();
    ]

let left_footer compact =
  box
    ~style:Style.(make ~height:(Cells 2) ~flex_direction:Row ~justify_content:Space_between ~padding:(spacing_xy ~x:2 ~y:0) ())
    (if compact then
       [ hint_bar [ ("esc", "interrupt"); ("tab", "agents") ] ]
     else
       [
         hint_bar [ (".........", "esc interrupt") ];
         hint_bar [ ("tab", "agents"); ("ctrl+p", "commands") ];
       ])

let right_rail width =
  box
    ~style:
      Style.(
        make ~width:(Cells width) ~height:(Percent 1.)
          ~padding:(spacing_xy ~x:2 ~y:1) ~bg:(Theme.dark Theme.Bg_surface) ())
    [
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_emphasis) ~attrs:[ Attr.Bold ] ())
        (if width < 34 then "New session" else "New session - 2026-05-13T18:37:20.");
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_emphasis) ~attrs:[ Attr.Bold ] ()) "287Z";
      spacer ~style:Style.(make ~height:(Cells 2) ()) ();
      section_title "Context";
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "0 tokens";
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "0% used";
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "$0.00 spent";
      spacer ~style:Style.(make ~height:(Cells 2) ()) ();
      section_title "LSP";
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "LSPs are disabled";
      spacer ~style:Style.(make ~flex_grow:1. ()) ();
      text ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "apps/tui";
      rich_text
        [
          Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Status_success) ~attrs:[ Attr.Bold ] ()) "• ";
          Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_emphasis) ~attrs:[ Attr.Bold ] ()) "OpenCode ";
          Span.make ~style:Style.(make ~fg:(Theme.dark Theme.Fg_muted) ()) "1.14.48";
        ];
    ]

let root viewport =
  let width = viewport.Viewport.width in
  let height = viewport.Viewport.height in
  let rail_width = if width >= 104 then Some (clamp 34 44 (width / 4)) else None in
  let left_width = match rail_width with None -> width | Some rail -> width - rail in
  let compact = left_width < 78 in
  let composer_height = if height < 24 then 4 else 5 in
  let left =
    box
      ~style:
        Style.(
          make ~flex_grow:1. ~height:(Percent 1.) ~padding:(spacing_xy ~x:2 ~y:1)
            ~bg:(Theme.dark Theme.Bg_base) ())
      [
        box ~style:Style.(make ~flex_grow:1. ~gap:1 ()) (conversation left_width);
        composer composer_height;
        left_footer compact;
      ]
  in
  let children =
    match rail_width with
    | None -> [ left ]
    | Some rail -> [ left; right_rail rail ]
  in
  box
    ~style:
      Style.(
        make ~width:(Percent 1.) ~height:(Percent 1.) ~flex_direction:Row
          ~bg:(Theme.dark Theme.Bg_base) ())
    children

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
