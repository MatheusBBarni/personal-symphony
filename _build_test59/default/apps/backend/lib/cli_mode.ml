type t = Terminal_console | Web_dashboard

let select ~web = if web then Web_dashboard else Terminal_console

let to_string = function Terminal_console -> "terminal_console" | Web_dashboard -> "web_dashboard"
