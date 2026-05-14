open Tui
open Tui.Components
open Tui.Patterns

let sessions =
  [
    section_title "Sessions";
    nav_item ~active:true ~meta:"now" "ocaml-tui";
    nav_item ~meta:"12m" "renderer-bugs";
    nav_item ~meta:"1h" "release-notes";
    nav_item ~meta:"2h" "perf-pass";
    section_title ~tone:Info "Workspaces";
    nav_item ~meta:"main" "opencaml";
    nav_item ~meta:"dirty" "demo-kit";
  ]

let transcript =
  [
    message ~tone:Info ~author:"User" ~time:"14:12"
      "Build components so people can recreate this kind of terminal UI.";
    message ~tone:Success ~author:"Assistant" ~time:"14:13"
      "Added dashboard primitives: panels, badges, metric cards, tables, logs, tabs, and command bars.";
    message ~tone:Accent ~author:"Assistant" ~time:"14:16"
      "Now adding workspace primitives for chat-heavy layouts: side navigation, messages, timelines, and a composer.";
  ]

let activity =
  [
    timeline
      [
        (Success, "tests", "10 passing");
        (Info, "build", "dune build @all");
        (Warning, "review", "image parity needs source pixels");
        (Accent, "example", "agent_workspace.exe");
      ];
    panel "Context"
      [
        key_value ~label_width:9
          [
            ("branch", "no git repo");
            ("package", "tui");
            ("layout", "Toffee flex");
            ("target", "132x38");
          ];
      ];
  ]

let () =
  let root =
    app_shell ~title:"Agent Workspace"
      ~subtitle:"message-first terminal interface"
      ~badges:[ (Success, "online"); (Accent, "model"); (Info, "tools") ]
      ~footer_items:[ ("q", "uit"); ("n", "ew"); ("/", "search"); ("?", "help"); ("Tab", "focus") ]
      [
        split ~left_width:28
          [ panel "Navigator" ~style:Style.(make ~height:(Percent 1.) ()) sessions ]
          [
            box ~style:Style.(make ~flex_direction:Row ~gap:1 ~height:(Percent 1.) ())
              [
                panel "Conversation"
                  ~style:Style.(make ~flex_grow:1. ~height:(Percent 1.) ())
                  [
                    scroll_box ~style:Style.(make ~flex_grow:1. ()) transcript;
                    composer ~placeholder:"Ask for code, tests, or a review" ();
                  ];
                panel "Run State"
                  ~tone:Info
                  ~style:Style.(make ~width:(Cells 36) ~height:(Percent 1.) ())
                  activity;
              ];
          ];
      ]
  in
  let renderer = Renderer.create ~width:132 ~height:38 root in
  print_endline (Renderer.render_to_string renderer)
