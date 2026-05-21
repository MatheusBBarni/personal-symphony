type t =
  | Terminal_console
  | Web_dashboard;

let select = (~web) => web ? Web_dashboard : Terminal_console;

let to_string = fun
| Terminal_console => "terminal_console"
| Web_dashboard => "web_dashboard";
