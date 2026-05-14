open Tui
open Tui.Components

let metric_row =
  Components.row
    ~style:Style.(make ~height:(Cells 9) ~gap:1 ())
    [
      Components.metric_card ~tone:Success ~label:"Revenue" ~value:"$128.4k"
        ~style:Style.(make ~width:(Cells 30) ())
        ~detail:"+12.8% vs last hour" ~progress:0.72
        ~sparkline:[ 4.; 6.; 5.; 8.; 9.; 11.; 10.; 14.; 13.; 16. ] ();
      Components.metric_card ~tone:Info ~label:"Latency" ~value:"42ms"
        ~style:Style.(make ~width:(Cells 30) ())
        ~detail:"p95 edge response" ~progress:0.42
        ~sparkline:[ 7.; 6.; 6.; 5.; 4.; 4.; 5.; 3.; 3.; 2. ] ();
      Components.metric_card ~tone:Warning ~label:"Queue" ~value:"1,204"
        ~style:Style.(make ~width:(Cells 30) ())
        ~detail:"jobs waiting" ~progress:0.61
        ~sparkline:[ 2.; 3.; 4.; 8.; 5.; 7.; 9.; 11.; 10.; 12. ] ();
    ]

let sidebar =
  [
    Components.tab_bar [ ("Overview", true); ("Services", false); ("Incidents", false) ];
    Components.panel "Systems"
      ~style:Style.(make ~height:(Cells 10) ())
      [
        select ~style:Style.(make ~height:(Cells 6) ())
          [
            option ~description:"all regions nominal" "Production";
            option ~description:"2 warnings" "Workers";
            option ~description:"healthy" "Database";
            option ~description:"scaling up" "Edge cache";
          ];
      ];
    Components.panel "Runbook"
      ~style:Style.(make ~flex_grow:1. ())
      [
        Components.key_value ~label_width:10
          [
            ("Owner", "Platform");
            ("Region", "iad + fra");
            ("SLO", "99.95%");
            ("Window", "13:00-15:00");
            ("Escalate", "#ops-war-room");
          ];
      ];
  ]

let main_grid =
  [
    metric_row;
    Components.row
      ~style:Style.(make ~flex_grow:1. ~gap:1 ())
      [
        Components.panel "Service Health"
          ~style:Style.(make ~flex_grow:1. ())
          [
            Components.table
              [ ("SERVICE", 16); ("REGION", 8); ("STATUS", 8); ("RPS", 7); ("ERR", 5) ]
              [
                [ "api-gateway"; "iad"; "OK"; "18.2k"; "0.03" ];
                [ "checkout"; "iad"; "WARN"; "6.4k"; "0.41" ];
                [ "scheduler"; "fra"; "OK"; "1.1k"; "0.00" ];
                [ "webhooks"; "sfo"; "OK"; "3.7k"; "0.08" ];
                [ "search"; "iad"; "OK"; "8.9k"; "0.02" ];
              ];
          ];
        Components.panel "Live Events"
          ~tone:Info
          ~style:Style.(make ~width:(Cells 44) ())
          [
            Components.log_feed
              ~style:Style.(make ~height:(Cells 13) ())
              [
                ("14:05:02", "INFO", "checkout deploy reached 42%");
                ("14:05:18", "WARN", "worker queue above 1k for 3m");
                ("14:06:04", "OK", "iad edge cache scaled to 18 nodes");
                ("14:06:41", "INFO", "database failover drill started");
                ("14:07:03", "OK", "p95 latency recovered below 50ms");
                ("14:07:58", "INFO", "scheduled report rendered");
              ];
          ];
      ];
    Components.panel "Trace Detail"
      ~tone:Accent
      ~style:Style.(make ~height:(Cells 8) ())
      [
        Components.key_value ~label_width:14
          [
            ("trace_id", "req_8LzYmK2sP1");
            ("route", "POST /v1/orders");
            ("span", "payment.authorize");
            ("duration", "41.8ms");
            ("next action", "watch retry budget");
          ];
      ];
  ]

let () =
  let root =
    Components.app_shell ~title:"Operations Console"
      ~subtitle:"global production control plane"
      ~badges:[ (Success, "live"); (Info, "iad"); (Warning, "queue") ]
      ~footer_items:[ ("q", "uit"); ("r", "efresh"); ("/", "filter"); ("?", "help"); ("Tab", "focus") ]
      [ Components.split ~left_width:32 sidebar main_grid ]
  in
  let renderer = Renderer.create ~width:132 ~height:38 root in
  print_endline (Renderer.render_to_string renderer)
