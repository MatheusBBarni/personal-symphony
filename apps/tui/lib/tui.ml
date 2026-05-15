module Geometry = struct
  type point = { x : int; y : int }
  type rect = { x : int; y : int; width : int; height : int }

  let point ~x ~y = { x; y }
  let rect ~x ~y ~width ~height = { x; y; width; height }
  let empty = { x = 0; y = 0; width = 0; height = 0 }
  let right r = r.x + r.width
  let bottom r = r.y + r.height
  let is_empty r = r.width <= 0 || r.height <= 0

  let contains r x y =
    (not (is_empty r)) && x >= r.x && y >= r.y && x < right r && y < bottom r

  let intersect a b =
    let x1 = max a.x b.x in
    let y1 = max a.y b.y in
    let x2 = min (right a) (right b) in
    let y2 = min (bottom a) (bottom b) in
    if x2 <= x1 || y2 <= y1 then empty
    else { x = x1; y = y1; width = x2 - x1; height = y2 - y1 }
end

module Attr = struct
  type t =
    | Bold
    | Dim
    | Italic
    | Underline
    | Blink
    | Inverse
    | Hidden
    | Strike

  let code = function
    | Bold -> "1"
    | Dim -> "2"
    | Italic -> "3"
    | Underline -> "4"
    | Blink -> "5"
    | Inverse -> "7"
    | Hidden -> "8"
    | Strike -> "9"

  let mem attr attrs = List.exists (( = ) attr) attrs
  let add attr attrs = if mem attr attrs then attrs else attr :: attrs
end

module Color = struct
  type t =
    | Default
    | Ansi of int
    | Indexed of int
    | RGB of int * int * int

  type level = No_color | Ansi16 | Ansi256 | Truecolor

  let clamp lo hi v = max lo (min hi v)
  let rgb r g b = RGB (clamp 0 255 r, clamp 0 255 g, clamp 0 255 b)
  let ansi n = Ansi (clamp 0 15 n)
  let indexed n = Indexed (clamp 0 255 n)

  let detect_level ?(env = Sys.getenv_opt) () =
    match env "NO_COLOR" with
    | Some _ -> No_color
    | None -> (
        match env "COLORTERM" with
        | Some ("truecolor" | "24bit") -> Truecolor
        | _ -> (
            match env "TERM" with
            | Some term when String.contains term '2' && String.ends_with ~suffix:"256color" term ->
                Ansi256
            | _ -> Ansi16))

  let fg_code = function
    | Default -> "39"
    | Ansi n when n < 8 -> string_of_int (30 + n)
    | Ansi n -> string_of_int (90 + (n - 8))
    | Indexed n -> "38;5;" ^ string_of_int n
    | RGB (r, g, b) ->
        Printf.sprintf "38;2;%d;%d;%d" (clamp 0 255 r) (clamp 0 255 g)
          (clamp 0 255 b)

  let bg_code = function
    | Default -> "49"
    | Ansi n when n < 8 -> string_of_int (40 + n)
    | Ansi n -> string_of_int (100 + (n - 8))
    | Indexed n -> "48;5;" ^ string_of_int n
    | RGB (r, g, b) ->
        Printf.sprintf "48;2;%d;%d;%d" (clamp 0 255 r) (clamp 0 255 g)
          (clamp 0 255 b)

  let degrade level = function
    | Default -> Default
    | Ansi n -> Ansi n
    | Indexed n -> if level = Ansi16 then Ansi (n mod 16) else Indexed n
    | RGB (r, g, b) -> (
        match level with
        | Truecolor -> RGB (r, g, b)
        | Ansi256 ->
            let bucket v = int_of_float (Float.round ((float v /. 255.) *. 5.)) in
            Indexed (16 + (36 * bucket r) + (6 * bucket g) + bucket b)
        | Ansi16 ->
            let bright = if r + g + b > 382 then 8 else 0 in
            let base =
              if r >= g && r >= b then 1
              else if g >= r && g >= b then 2
              else if b >= r && b >= g then 4
              else 7
            in
            Ansi (bright + base)
        | No_color -> Default)

  let equal = ( = )
end

module Theme = struct
  type slot =
    | Fg_default
    | Fg_muted
    | Fg_emphasis
    | Bg_base
    | Bg_surface
    | Bg_overlay
    | Bg_selection
    | Accent_primary
    | Accent_secondary
    | Status_error
    | Status_warning
    | Status_success
    | Status_info

  type t = slot -> Color.t

  let dark = function
    | Fg_default -> Color.rgb 192 202 245
    | Fg_muted -> Color.rgb 86 95 137
    | Fg_emphasis -> Color.rgb 224 224 224
    | Bg_base -> Color.rgb 26 27 38
    | Bg_surface -> Color.rgb 36 40 59
    | Bg_overlay -> Color.rgb 65 72 104
    | Bg_selection -> Color.rgb 54 74 130
    | Accent_primary -> Color.rgb 122 162 247
    | Accent_secondary -> Color.rgb 187 154 247
    | Status_error -> Color.rgb 247 118 142
    | Status_warning -> Color.rgb 224 175 104
    | Status_success -> Color.rgb 158 206 106
    | Status_info -> Color.rgb 125 207 255

  let light = function
    | Fg_default -> Color.rgb 52 59 88
    | Fg_muted -> Color.rgb 110 118 147
    | Fg_emphasis -> Color.rgb 20 23 35
    | Bg_base -> Color.rgb 239 241 245
    | Bg_surface -> Color.rgb 230 233 239
    | Bg_overlay -> Color.rgb 204 208 218
    | Bg_selection -> Color.rgb 172 188 255
    | Accent_primary -> Color.rgb 30 102 245
    | Accent_secondary -> Color.rgb 136 57 239
    | Status_error -> Color.rgb 210 15 57
    | Status_warning -> Color.rgb 223 142 29
    | Status_success -> Color.rgb 64 160 43
    | Status_info -> Color.rgb 4 165 229
end

module Style = struct
  type length = Auto | Cells of int | Percent of float
  type spacing = { left : int; right : int; top : int; bottom : int }
  type flex_direction = Row | Column | Row_reverse | Column_reverse
  type justify = Justify_start | Justify_end | Justify_center | Space_between | Space_around | Space_evenly
  type align = Align_start | Align_end | Align_center | Align_stretch
  type border_style = Single | Rounded | Double | Heavy
  type title_align = Title_left | Title_center | Title_right
  type position = Relative | Absolute

  type t = {
    fg : Color.t option;
    bg : Color.t option;
    attrs : Attr.t list;
    width : length;
    height : length;
    min_width : length;
    min_height : length;
    flex_grow : float;
    flex_shrink : float;
    flex_direction : flex_direction;
    justify_content : justify;
    align_items : align;
    position : position;
    left : int option;
    top : int option;
    right : int option;
    bottom : int option;
    padding : spacing;
    margin : spacing;
    gap : int;
    border : border_style option;
    border_fg : Color.t option;
    title : string option;
    title_align : title_align;
    bottom_title : string option;
    bottom_title_align : title_align;
  }

  let spacing ?(left = 0) ?(right = 0) ?(top = 0) ?(bottom = 0) () =
    { left; right; top; bottom }

  let spacing_all n = spacing ~left:n ~right:n ~top:n ~bottom:n ()
  let spacing_xy ~x ~y = spacing ~left:x ~right:x ~top:y ~bottom:y ()

  let default =
    {
      fg = None;
      bg = None;
      attrs = [];
      width = Auto;
      height = Auto;
      min_width = Cells 0;
      min_height = Cells 0;
      flex_grow = 0.;
      flex_shrink = 0.;
      flex_direction = Column;
      justify_content = Justify_start;
      align_items = Align_stretch;
      position = Relative;
      left = None;
      top = None;
      right = None;
      bottom = None;
      padding = spacing_all 0;
      margin = spacing_all 0;
      gap = 0;
      border = None;
      border_fg = None;
      title = None;
      title_align = Title_left;
      bottom_title = None;
      bottom_title_align = Title_left;
    }

  let make ?fg ?bg ?(attrs = []) ?(width = Auto) ?(height = Auto)
      ?(min_width = Cells 0) ?(min_height = Cells 0) ?(flex_grow = 0.)
      ?(flex_shrink = 0.) ?(flex_direction = Column)
      ?(justify_content = Justify_start) ?(align_items = Align_stretch)
      ?(position = Relative) ?left ?top ?right ?bottom
      ?(padding = spacing_all 0) ?(margin = spacing_all 0) ?(gap = 0) ?border
      ?border_fg ?title ?(title_align = Title_left) ?bottom_title
      ?(bottom_title_align = Title_left) () =
    {
      fg;
      bg;
      attrs;
      width;
      height;
      min_width;
      min_height;
      flex_grow;
      flex_shrink;
      flex_direction;
      justify_content;
      align_items;
      position;
      left;
      top;
      right;
      bottom;
      padding;
      margin;
      gap;
      border;
      border_fg;
      title;
      title_align;
      bottom_title;
      bottom_title_align;
    }

  let with_fg fg t = { t with fg = Some fg }
  let with_bg bg t = { t with bg = Some bg }
  let with_attrs attrs t = { t with attrs }
  let add_attr attr t = { t with attrs = Attr.add attr t.attrs }
  let with_width width t = { t with width }
  let with_height height t = { t with height }
  let with_size ~width ~height t = { t with width; height }
  let with_border border t = { t with border = Some border }
  let without_border t = { t with border = None }

  let paint_equal a b =
    Color.equal (Option.value ~default:Color.Default a.fg)
      (Option.value ~default:Color.Default b.fg)
    && Color.equal (Option.value ~default:Color.Default a.bg)
         (Option.value ~default:Color.Default b.bg)
    && a.attrs = b.attrs

  let border_width t = match t.border with Some _ -> 1 | None -> 0

  let to_ansi ?(level = Color.detect_level ()) t =
    if level = Color.No_color then ""
    else
      let codes = ref [ "0" ] in
      (match t.fg with
      | None -> ()
      | Some c -> codes := Color.fg_code (Color.degrade level c) :: !codes);
      (match t.bg with
      | None -> ()
      | Some c -> codes := Color.bg_code (Color.degrade level c) :: !codes);
      List.iter (fun attr -> codes := Attr.code attr :: !codes) t.attrs;
      "\027[" ^ String.concat ";" (List.rev !codes) ^ "m"
end

module Utf = struct
  let uchar_to_utf8 u =
    let n = Uchar.to_int u in
    if n <= 0x7F then String.make 1 (Char.chr n)
    else if n <= 0x7FF then
      String.init 2 (function
        | 0 -> Char.chr (0xC0 lor (n lsr 6))
        | _ -> Char.chr (0x80 lor (n land 0x3F)))
    else if n <= 0xFFFF then
      String.init 3 (function
        | 0 -> Char.chr (0xE0 lor (n lsr 12))
        | 1 -> Char.chr (0x80 lor ((n lsr 6) land 0x3F))
        | _ -> Char.chr (0x80 lor (n land 0x3F)))
    else
      String.init 4 (function
        | 0 -> Char.chr (0xF0 lor (n lsr 18))
        | 1 -> Char.chr (0x80 lor ((n lsr 12) land 0x3F))
        | 2 -> Char.chr (0x80 lor ((n lsr 6) land 0x3F))
        | _ -> Char.chr (0x80 lor (n land 0x3F)))

  let is_combining n =
    (n >= 0x0300 && n <= 0x036F)
    || (n >= 0x1AB0 && n <= 0x1AFF)
    || (n >= 0x1DC0 && n <= 0x1DFF)
    || (n >= 0x20D0 && n <= 0x20FF)
    || (n >= 0xFE20 && n <= 0xFE2F)

  let is_wide n =
    (n >= 0x1100 && n <= 0x115F)
    || n = 0x2329 || n = 0x232A
    || (n >= 0x2E80 && n <= 0xA4CF)
    || (n >= 0xAC00 && n <= 0xD7A3)
    || (n >= 0xF900 && n <= 0xFAFF)
    || (n >= 0xFE10 && n <= 0xFE19)
    || (n >= 0xFE30 && n <= 0xFE6F)
    || (n >= 0xFF00 && n <= 0xFF60)
    || (n >= 0xFFE0 && n <= 0xFFE6)
    || (n >= 0x1F300 && n <= 0x1FAFF)

  let uchar_width u =
    let n = Uchar.to_int u in
    if n = 0 || n < 32 || (n >= 0x7F && n < 0xA0) || is_combining n then 0
    else if is_wide n then 2
    else 1

  let string_width s =
    Uutf.String.fold_utf_8
      (fun acc _ -> function
        | `Uchar u -> acc + uchar_width u
        | `Malformed _ -> acc + 1)
      0 s

  let lines s = String.split_on_char '\n' s
  let longest_line_width s = lines s |> List.fold_left (fun acc line -> max acc (string_width line)) 0
  let line_count s = max 1 (List.length (lines s))
end

module Surface = struct
  type cell = { text : string; style : Style.t }
  type t = { width : int; height : int; cells : cell array }

  let blank ?(style = Style.default) () = { text = " "; style }
  let create ?(style = Style.default) ~width ~height () = { width; height; cells = Array.make (width * height) (blank ~style ()) }
  let bounds t = Geometry.rect ~x:0 ~y:0 ~width:t.width ~height:t.height
  let index t x y = (y * t.width) + x
  let in_bounds t x y = x >= 0 && y >= 0 && x < t.width && y < t.height

  let set ?clip t ~x ~y ~style text =
    let clip = Option.value ~default:(bounds t) clip in
    if in_bounds t x y && Geometry.contains clip x y then t.cells.(index t x y) <- { text; style }

  let get t ~x ~y = if in_bounds t x y then Some t.cells.(index t x y) else None

  let fill_rect ?clip t rect ~style =
    let clip = Option.value ~default:(bounds t) clip |> Geometry.intersect rect in
    for y = clip.y to Geometry.bottom clip - 1 do
      for x = clip.x to Geometry.right clip - 1 do
        set t ~x ~y ~style " "
      done
    done

  let write ?clip t ~x ~y ~style text =
    let start_x = x in
    let cx = ref x in
    let cy = ref y in
    let put text width =
      if width > 0 then (
        set ?clip t ~x:!cx ~y:!cy ~style text;
        if width = 2 then set ?clip t ~x:(!cx + 1) ~y:!cy ~style " ";
        cx := !cx + width)
    in
    Uutf.String.fold_utf_8
      (fun () _ -> function
        | `Uchar u when Uchar.to_int u = 0x0A ->
            cx := start_x;
            incr cy
        | `Uchar u ->
            let width = Utf.uchar_width u in
            put (Utf.uchar_to_utf8 u) width
        | `Malformed _ -> put "?" 1)
      () text;
    (!cx, !cy)

  let to_plain t =
    let out = Stdlib.Buffer.create (t.width * t.height) in
    for y = 0 to t.height - 1 do
      for x = 0 to t.width - 1 do
        Stdlib.Buffer.add_string out t.cells.(index t x y).text
      done;
      if y < t.height - 1 then Stdlib.Buffer.add_char out '\n'
    done;
    Stdlib.Buffer.contents out

  let to_ansi ?(level = Color.detect_level ()) t =
    if level = Color.No_color then to_plain t
    else
      let out = Stdlib.Buffer.create (t.width * t.height * 2) in
      let current = ref None in
      for y = 0 to t.height - 1 do
        for x = 0 to t.width - 1 do
          let cell = t.cells.(index t x y) in
          (match !current with
          | Some style when Style.paint_equal style cell.style -> ()
          | _ ->
              Stdlib.Buffer.add_string out (Style.to_ansi ~level cell.style);
              current := Some cell.style);
          Stdlib.Buffer.add_string out cell.text
        done;
        if y < t.height - 1 then Stdlib.Buffer.add_char out '\n'
      done;
      Stdlib.Buffer.add_string out "\027[0m";
      Stdlib.Buffer.contents out

  let diff_to_ansi ?(level = Color.detect_level ()) before after =
    let out = Stdlib.Buffer.create 256 in
    for y = 0 to min before.height after.height - 1 do
      for x = 0 to min before.width after.width - 1 do
        let a = before.cells.(index before x y) in
        let b = after.cells.(index after x y) in
        if a.text <> b.text || not (Style.paint_equal a.style b.style) then (
          Stdlib.Buffer.add_string out (Printf.sprintf "\027[%d;%dH" (y + 1) (x + 1));
          Stdlib.Buffer.add_string out (Style.to_ansi ~level b.style);
          Stdlib.Buffer.add_string out b.text)
      done
    done;
    Stdlib.Buffer.add_string out "\027[0m";
    Stdlib.Buffer.contents out
end

module Span = struct
  type t = { text : string; style : Style.t }
  let make ?(style = Style.default) text = { text; style }
  let plain text = make text
end

module Key = struct
  type event = {
    name : string;
    sequence : string;
    ctrl : bool;
    shift : bool;
    alt : bool;
  }

  let make ?(ctrl = false) ?(shift = false) ?(alt = false) ~name ~sequence () =
    { name; sequence; ctrl; shift; alt }

  let ctrl_name c = String.make 1 (Char.chr (Char.code 'a' + Char.code c - 1))

  let of_sequence = function
    | "\r" | "\n" -> make ~name:"return" ~sequence:"\n" ()
    | "\t" -> make ~name:"tab" ~sequence:"\t" ()
    | "\027" -> make ~name:"escape" ~sequence:"\027" ()
    | "\127" | "\b" -> make ~name:"backspace" ~sequence:"\127" ()
    | "\027[A" -> make ~name:"up" ~sequence:"\027[A" ()
    | "\027[B" -> make ~name:"down" ~sequence:"\027[B" ()
    | "\027[C" -> make ~name:"right" ~sequence:"\027[C" ()
    | "\027[D" -> make ~name:"left" ~sequence:"\027[D" ()
    | "\027[5~" -> make ~name:"pageup" ~sequence:"\027[5~" ()
    | "\027[6~" -> make ~name:"pagedown" ~sequence:"\027[6~" ()
    | "\027[H" | "\027[1~" -> make ~name:"home" ~sequence:"\027[H" ()
    | "\027[F" | "\027[4~" -> make ~name:"end" ~sequence:"\027[F" ()
    | seq when String.length seq = 1 ->
        let c = seq.[0] in
        let code = Char.code c in
        if code >= 1 && code <= 26 then make ~ctrl:true ~name:(ctrl_name c) ~sequence:seq ()
        else if c = ' ' then make ~name:"space" ~sequence:seq ()
        else make ~name:(String.make 1 c) ~sequence:seq ()
    | seq when String.length seq = 2 && seq.[0] = '\027' ->
        make ~alt:true ~name:(String.make 1 seq.[1]) ~sequence:seq ()
    | seq -> make ~name:"unknown" ~sequence:seq ()

  let read_sequence fd =
    let first = Bytes.create 1 in
    match Unix.read fd first 0 1 with
    | 0 -> None
    | _ ->
        let out = Stdlib.Buffer.create 8 in
        Stdlib.Buffer.add_char out (Bytes.get first 0);
        if Bytes.get first 0 = '\027' then (
          let more = Bytes.create 1 in
          let rec drain () =
            match Unix.select [ fd ] [] [] 0.005 with
            | [], _, _ -> ()
            | _ -> (
                match Unix.read fd more 0 1 with
                | 0 -> ()
                | _ ->
                    Stdlib.Buffer.add_char out (Bytes.get more 0);
                    drain ())
          in
          drain ());
        Some (Stdlib.Buffer.contents out)

  let read fd = Option.map of_sequence (read_sequence fd)
end

module Keymap = struct
  type stroke = { name : string; ctrl : bool; shift : bool; alt : bool }
  type command = { name : string; description : string option; run : unit -> unit }
  type binding = { keys : stroke list; command : command }
  type dispatch_result = Handled of string | Pending | Unhandled
  type t = { mutable bindings : binding list; mutable pending : stroke list }

  let create () = { bindings = []; pending = [] }
  let stroke ?(ctrl = false) ?(shift = false) ?(alt = false) name = { name; ctrl; shift; alt }
  let of_event (event : Key.event) = { name = event.name; ctrl = event.ctrl; shift = event.shift; alt = event.alt }

  let normalize_name = function
    | "enter" -> "return"
    | "esc" -> "escape"
    | " " -> "space"
    | s -> String.lowercase_ascii s

  let parse_token token =
    let parts = String.split_on_char '+' (String.lowercase_ascii token) in
    let ctrl = List.mem "ctrl" parts || List.mem "control" parts in
    let shift = List.mem "shift" parts in
    let alt = List.mem "alt" parts || List.mem "meta" parts in
    let key =
      parts
      |> List.filter (fun p -> not (List.mem p [ "ctrl"; "control"; "shift"; "alt"; "meta" ]))
      |> function
      | [ k ] -> normalize_name k
      | [] -> normalize_name token
      | ks -> normalize_name (String.concat "+" ks)
    in
    stroke ~ctrl ~shift ~alt key

  let parse_sequence s =
    let s = String.trim s in
    if String.contains s ' ' then
      s |> String.split_on_char ' ' |> List.filter (( <> ) "") |> List.map parse_token
    else if String.contains s '+' || String.length s <= 1 then [ parse_token s ]
    else
      let known =
        [ "escape"; "return"; "enter"; "tab"; "backspace"; "up"; "down"; "left"; "right"; "pageup"; "pagedown"; "home"; "end" ]
      in
      if List.mem (String.lowercase_ascii s) known then [ parse_token s ]
      else List.init (String.length s) (fun i -> stroke (String.make 1 s.[i]))

  let register ?description t ~key ~name ~run =
    let command = { name; description; run } in
    t.bindings <- { keys = parse_sequence key; command } :: t.bindings

  let is_prefix prefix keys =
    let rec loop a b =
      match (a, b) with
      | [], _ -> true
      | x :: xs, y :: ys when x = y -> loop xs ys
      | _ -> false
    in
    loop prefix keys

  let dispatch t event =
    let next = t.pending @ [ of_event event ] in
    let exact = List.find_opt (fun binding -> binding.keys = next) t.bindings in
    match exact with
    | Some binding ->
        t.pending <- [];
        binding.command.run ();
        Handled binding.command.name
    | None ->
        if List.exists (fun binding -> is_prefix next binding.keys) t.bindings then (
          t.pending <- next;
          Pending)
        else (
          t.pending <- [];
          Unhandled)

  let active_keys t =
    t.bindings
    |> List.filter_map (fun binding ->
           if is_prefix t.pending binding.keys then
             List.nth_opt binding.keys (List.length t.pending)
           else None)
end

module Node = struct
  type input_state = {
    mutable value : string;
    placeholder : string;
    max_length : int;
    mutable cursor : int;
    on_input : (string -> unit) option;
    on_enter : (string -> unit) option;
  }

  type select_option = { name : string; description : string; value : string option }

  type select_state = {
    options : select_option list;
    mutable selected : int;
    mutable scroll : int;
    wrap : bool;
    show_description : bool;
    fast_scroll_step : int;
    on_change : (int -> select_option -> unit) option;
    on_select : (int -> select_option -> unit) option;
  }

  type scroll_state = { mutable scroll_x : int; mutable scroll_y : int; sticky_bottom : bool }
  type progress_state = { fraction : float; label : string option }

  type kind =
    | Text of Span.t list
    | Vertical_rule of string
    | Box
    | Input of input_state
    | Select of select_state
    | Scroll_box of scroll_state
    | Progress_bar of progress_state
    | Sparkline of float list
    | Spacer

  type t = {
    id : string;
    kind : kind;
    style : Style.t;
    children : t list;
    focusable : bool;
    mutable focused : bool;
  }

  let next_id =
    let counter = ref 0 in
    fun prefix ->
      incr counter;
      Printf.sprintf "%s-%d" prefix !counter

  let make ?id ?(style = Style.default) ?(children = []) ?(focusable = false) kind =
    { id = Option.value ~default:(next_id "node") id; kind; style; children; focusable; focused = false }

  let text ?id ?(style = Style.default) content = make ?id ~style (Text [ Span.make ~style content ])
  let rich_text ?id ?(style = Style.default) spans = make ?id ~style (Text spans)
  let vertical_rule ?id ?(style = Style.default) ?(char = "│") () =
    make ?id ~style (Vertical_rule char)
  let box ?id ?(style = Style.default) children = make ?id ~style ~children Box
  let spacer ?id ?(style = Style.default) () = make ?id ~style Spacer

  let input ?id ?(style = Style.default) ?(value = "") ?(placeholder = "") ?(max_length = 1000) ?on_input ?on_enter () =
    let state = { value; placeholder; max_length; cursor = String.length value; on_input; on_enter } in
    make ?id ~style ~focusable:true (Input state)

  let option ?value ?(description = "") name = { name; description; value }

  let select ?id ?(style = Style.default) ?(selected = 0) ?(wrap = false) ?(show_description = true)
      ?(fast_scroll_step = 5) ?on_change ?on_select options =
    let state = { options; selected; scroll = 0; wrap; show_description; fast_scroll_step; on_change; on_select } in
    make ?id ~style ~focusable:true (Select state)

  let scroll_box ?id ?(style = Style.default) ?(scroll_x = 0) ?(scroll_y = 0) ?(sticky_bottom = false) children =
    make ?id ~style ~children ~focusable:true (Scroll_box { scroll_x; scroll_y; sticky_bottom })

  let progress_bar ?id ?(style = Style.default) ?label fraction =
    make ?id ~style (Progress_bar { fraction = max 0. (min 1. fraction); label })

  let sparkline ?id ?(style = Style.default) values = make ?id ~style (Sparkline values)

  let plain_text = function
    | Text spans -> spans |> List.map (fun span -> span.Span.text) |> String.concat ""
    | Vertical_rule char -> char
    | _ -> ""

  let rec find_by_id id node =
    if node.id = id then Some node
    else node.children |> List.find_map (find_by_id id)

  let rec focusables node =
    let own = if node.focusable then [ node ] else [] in
    own @ List.concat_map focusables node.children

  let set_focus root id =
    let all = focusables root in
    List.iter (fun node -> node.focused <- node.id = id) all;
    List.exists (fun node -> node.id = id) all

  let focus_first root =
    match focusables root with
    | [] -> None
    | node :: _ ->
        ignore (set_focus root node.id);
        Some node.id

  let focus_next root current =
    let all = focusables root in
    match all with
    | [] -> None
    | _ ->
        let index =
          match current with
          | None -> -1
          | Some id -> (
              match List.find_index (fun node -> node.id = id) all with Some i -> i | None -> -1)
        in
        let next = List.nth all ((index + 1) mod List.length all) in
        ignore (set_focus root next.id);
        Some next.id

  let selected_option state = List.nth_opt state.options state.selected

  let clamp_select state =
    let count = List.length state.options in
    if count = 0 then state.selected <- 0
    else state.selected <- max 0 (min (count - 1) state.selected)

  let move_select state delta =
    let count = List.length state.options in
    if count > 0 then (
      let next = state.selected + delta in
      state.selected <-
        (if state.wrap then (next mod count + count) mod count else max 0 (min (count - 1) next));
      match (state.on_change, selected_option state) with
      | Some f, Some option -> f state.selected option
      | _ -> ())

  let insert_at s index text =
    String.sub s 0 index ^ text ^ String.sub s index (String.length s - index)

  let remove_before s index =
    if index <= 0 then s else String.sub s 0 (index - 1) ^ String.sub s index (String.length s - index)

  let remove_at s index =
    if index < 0 || index >= String.length s then s
    else String.sub s 0 index ^ String.sub s (index + 1) (String.length s - index - 1)

  let handle_key node (key : Key.event) =
    match node.kind with
    | Input state -> (
        match key.name with
        | "left" ->
            state.cursor <- max 0 (state.cursor - 1);
            true
        | "right" ->
            state.cursor <- min (String.length state.value) (state.cursor + 1);
            true
        | "home" ->
            state.cursor <- 0;
            true
        | "end" ->
            state.cursor <- String.length state.value;
            true
        | "backspace" ->
            state.value <- remove_before state.value state.cursor;
            state.cursor <- max 0 (state.cursor - 1);
            Option.iter (fun f -> f state.value) state.on_input;
            true
        | "delete" ->
            state.value <- remove_at state.value state.cursor;
            Option.iter (fun f -> f state.value) state.on_input;
            true
        | "return" ->
            Option.iter (fun f -> f state.value) state.on_enter;
            true
        | name when (not key.ctrl) && (not key.alt) && String.length name = 1 ->
            if String.length state.value < state.max_length then (
              state.value <- insert_at state.value state.cursor name;
              state.cursor <- state.cursor + 1;
              Option.iter (fun f -> f state.value) state.on_input);
            true
        | _ -> false)
    | Select state -> (
        clamp_select state;
        match key.name with
        | "up" | "k" ->
            move_select state (-1);
            true
        | "down" | "j" ->
            move_select state 1;
            true
        | "pageup" ->
            move_select state (-state.fast_scroll_step);
            true
        | "pagedown" ->
            move_select state state.fast_scroll_step;
            true
        | "return" ->
            (match (state.on_select, selected_option state) with
            | Some f, Some option -> f state.selected option
            | _ -> ());
            true
        | _ -> false)
    | Scroll_box state -> (
        match key.name with
        | "up" | "k" ->
            state.scroll_y <- max 0 (state.scroll_y - 1);
            true
        | "down" | "j" ->
            state.scroll_y <- state.scroll_y + 1;
            true
        | "left" | "h" ->
            state.scroll_x <- max 0 (state.scroll_x - 1);
            true
        | "right" | "l" ->
            state.scroll_x <- state.scroll_x + 1;
            true
        | _ -> false)
    | _ -> false
end

module Layout = struct
  module T = Toffee
  module TG = Toffee.Geometry

  type positioned = {
    node : Node.t;
    rect : Geometry.rect;
    content : Geometry.rect;
    clip : Geometry.rect;
    children : positioned list;
  }

  let ok = function Ok v -> v | Error err -> invalid_arg (Toffee.Error.to_string err)
  let f i = float_of_int i
  let round f = int_of_float (Float.round f)

  let to_dimension = function
    | Style.Auto -> T.Style.Dimension.auto
    | Style.Cells n -> T.Style.Dimension.px (f n)
    | Style.Percent p -> T.Style.Dimension.percent p

  let to_length = function
    | Style.Auto -> T.Style.Length_percentage.zero
    | Style.Cells n -> T.Style.Length_percentage.px (f n)
    | Style.Percent p -> T.Style.Length_percentage.percent p

  let to_length_auto = function
    | Style.Auto -> T.Style.Length_percentage_auto.auto
    | Style.Cells n -> T.Style.Length_percentage_auto.px (f n)
    | Style.Percent p -> T.Style.Length_percentage_auto.percent p

  let rect_of_spacing (s : Style.spacing) ~auto =
    if auto then
      TG.Rect.
        {
          left = T.Style.Length_percentage_auto.px (f s.Style.left);
          right = T.Style.Length_percentage_auto.px (f s.right);
          top = T.Style.Length_percentage_auto.px (f s.top);
          bottom = T.Style.Length_percentage_auto.px (f s.bottom);
        }
    else
      TG.Rect.
        {
          left = T.Style.Length_percentage.px (f s.Style.left);
          right = T.Style.Length_percentage.px (f s.right);
          top = T.Style.Length_percentage.px (f s.top);
          bottom = T.Style.Length_percentage.px (f s.bottom);
        }

  let border_rect style =
    let width = Style.border_width style |> f in
    TG.Rect.
      {
        left = T.Style.Length_percentage.px width;
        right = T.Style.Length_percentage.px width;
        top = T.Style.Length_percentage.px width;
        bottom = T.Style.Length_percentage.px width;
      }

  let to_flex_direction = function
    | Style.Row -> T.Style.Flex_direction.Row
    | Style.Column -> T.Style.Flex_direction.Column
    | Style.Row_reverse -> T.Style.Flex_direction.Row_reverse
    | Style.Column_reverse -> T.Style.Flex_direction.Column_reverse

  let to_justify = function
    | Style.Justify_start -> T.Style.Align_content.Flex_start
    | Style.Justify_end -> T.Style.Align_content.Flex_end
    | Style.Justify_center -> T.Style.Align_content.Center
    | Style.Space_between -> T.Style.Align_content.Space_between
    | Style.Space_around -> T.Style.Align_content.Space_around
    | Style.Space_evenly -> T.Style.Align_content.Space_evenly

  let to_align = function
    | Style.Align_start -> T.Style.Align_items.Flex_start
    | Style.Align_end -> T.Style.Align_items.Flex_end
    | Style.Align_center -> T.Style.Align_items.Center
    | Style.Align_stretch -> T.Style.Align_items.Stretch

  let to_position = function Style.Relative -> T.Style.Position.Relative | Style.Absolute -> T.Style.Position.Absolute

  let to_inset style =
    TG.Rect.
      {
        left = Option.fold ~none:T.Style.Length_percentage_auto.auto ~some:(fun n -> T.Style.Length_percentage_auto.px (f n)) style.Style.left;
        right = Option.fold ~none:T.Style.Length_percentage_auto.auto ~some:(fun n -> T.Style.Length_percentage_auto.px (f n)) style.right;
        top = Option.fold ~none:T.Style.Length_percentage_auto.auto ~some:(fun n -> T.Style.Length_percentage_auto.px (f n)) style.top;
        bottom = Option.fold ~none:T.Style.Length_percentage_auto.auto ~some:(fun n -> T.Style.Length_percentage_auto.px (f n)) style.bottom;
      }

  let toffee_style style =
    T.Style.make
      ~display:T.Style.Display.Flex
      ~position:(to_position style.Style.position)
      ~inset:(to_inset style)
      ~size:TG.Size.{ width = to_dimension style.width; height = to_dimension style.height }
      ~min_size:TG.Size.{ width = to_dimension style.min_width; height = to_dimension style.min_height }
      ~margin:(rect_of_spacing style.margin ~auto:true)
      ~padding:(rect_of_spacing style.padding ~auto:false)
      ~border:(border_rect style)
      ~gap:TG.Size.{ width = to_length (Style.Cells style.gap); height = to_length (Style.Cells style.gap) }
      ~flex_direction:(to_flex_direction style.flex_direction)
      ~justify_content:(to_justify style.justify_content)
      ~align_items:(to_align style.align_items)
      ~flex_grow:style.flex_grow ~flex_shrink:style.flex_shrink ()

  let intrinsic_size node =
    match node.Node.kind with
    | Text spans ->
        let text = spans |> List.map (fun span -> span.Span.text) |> String.concat "" in
        (Utf.longest_line_width text, Utf.line_count text)
    | Vertical_rule char -> (max 1 (Utf.string_width char), 1)
    | Input state ->
        (max 1 (max (Utf.string_width state.value) (Utf.string_width state.placeholder) + 1), 1)
    | Select state ->
        let item_width option =
          Utf.string_width option.Node.name
          + if state.show_description && option.description <> "" then Utf.string_width option.description + 3 else 0
        in
        let width = List.fold_left (fun acc option -> max acc (item_width option + 2)) 1 state.options in
        let height = max 1 (min 8 (List.length state.options)) in
        (width, height)
    | Progress_bar _ -> (20, 1)
    | Sparkline values -> (max 1 (List.length values), 1)
    | Box | Scroll_box _ | Spacer -> (0, 0)

  let measure known _available _node_id context _style =
    let width, height =
      match context with Some node -> intrinsic_size node | None -> (0, 0)
    in
    TG.Size.
      {
        width = Option.value ~default:(f width) known.width;
        height = Option.value ~default:(f height) known.height;
      }

  let compute root ~width ~height =
    let tree = T.new_tree () in
    let node_ids = Hashtbl.create 32 in
    let rec build is_root node =
      let style =
        if is_root then Style.with_size ~width:(Style.Cells width) ~height:(Style.Cells height) node.Node.style
        else node.style
      in
      let child_ids = node.children |> List.map (build false) |> Array.of_list in
      let id =
        if Array.length child_ids = 0 then T.new_leaf_with_context tree (toffee_style style) node |> ok
        else T.new_with_children tree (toffee_style style) child_ids |> ok
      in
      ignore (T.set_node_context tree id (Some node) |> ok);
      Hashtbl.add node_ids node.Node.id id;
      id
    in
    let root_id = build true root in
    let available = TG.Size.{ width = T.Available_space.of_length (f width); height = T.Available_space.of_length (f height) } in
    T.compute_layout_with_measure tree root_id available measure |> ok;
    let rec collect (origin : Geometry.point) clip node =
      let id = Hashtbl.find node_ids node.Node.id in
      let layout = T.layout tree id |> ok in
      let margin = layout.margin in
      let rect =
        Geometry.rect
          ~x:(origin.Geometry.x + round (layout.location.x +. margin.left))
          ~y:(origin.y + round (layout.location.y +. margin.top))
          ~width:(max 0 (round layout.size.width))
          ~height:(max 0 (round layout.size.height))
      in
      let content =
        Geometry.rect
          ~x:(origin.x + round (T.Layout.content_box_x layout))
          ~y:(origin.y + round (T.Layout.content_box_y layout))
          ~width:(max 0 (round (T.Layout.content_box_width layout)))
          ~height:(max 0 (round (T.Layout.content_box_height layout)))
      in
      let own_clip = Geometry.intersect clip rect in
      let child_clip = Geometry.intersect clip content in
      let child_origin, child_clip =
        match node.kind with
        | Scroll_box state ->
            (Geometry.point ~x:(rect.x - state.scroll_x) ~y:(rect.y - state.scroll_y), child_clip)
        | _ -> (Geometry.point ~x:rect.x ~y:rect.y, child_clip)
      in
      let children = List.map (collect child_origin child_clip) node.children in
      { node; rect; content; clip = own_clip; children }
    in
    collect (Geometry.point ~x:0 ~y:0) (Geometry.rect ~x:0 ~y:0 ~width ~height) root
end

module Render = struct
  let style_with ?fg ?bg ?attrs base =
    let base = match fg with None -> base | Some fg -> Style.with_fg fg base in
    let base = match bg with None -> base | Some bg -> Style.with_bg bg base in
    match attrs with None -> base | Some attrs -> Style.with_attrs attrs base

  type border_chars = { tl : string; tr : string; bl : string; br : string; h : string; v : string }

  let border_chars = function
    | Style.Single -> { tl = "┌"; tr = "┐"; bl = "└"; br = "┘"; h = "─"; v = "│" }
    | Style.Rounded -> { tl = "╭"; tr = "╮"; bl = "╰"; br = "╯"; h = "─"; v = "│" }
    | Style.Double -> { tl = "╔"; tr = "╗"; bl = "╚"; br = "╝"; h = "═"; v = "║" }
    | Style.Heavy -> { tl = "┏"; tr = "┓"; bl = "┗"; br = "┛"; h = "━"; v = "┃" }

  let write_clipped surface clip x y style text =
    ignore (Surface.write ~clip surface ~x ~y ~style text)

  let draw_title surface clip (rect : Geometry.rect) style align title =
    let width = Utf.string_width title + 2 in
    if rect.Geometry.width > 4 && width < rect.width then
      let x =
        match align with
        | Style.Title_left -> rect.x + 2
        | Style.Title_center -> rect.x + ((rect.width - width) / 2)
        | Style.Title_right -> rect.x + rect.width - width - 1
      in
      write_clipped surface clip x rect.y style (" " ^ title ^ " ")

  let draw_bottom_title surface clip (rect : Geometry.rect) style align title =
    let width = Utf.string_width title + 2 in
    if rect.Geometry.width > 4 && width < rect.width then
      let x =
        match align with
        | Style.Title_left -> rect.x + 2
        | Style.Title_center -> rect.x + ((rect.width - width) / 2)
        | Style.Title_right -> rect.x + rect.width - width - 1
      in
      write_clipped surface clip x (rect.y + rect.height - 1) style (" " ^ title ^ " ")

  let draw_border surface clip (rect : Geometry.rect) style =
    match style.Style.border with
    | None -> ()
    | Some border when rect.width >= 2 && rect.height >= 2 ->
        let chars = border_chars border in
        let border_style =
          match style.border_fg with None -> style | Some fg -> Style.with_fg fg style
        in
        Surface.set ~clip surface ~x:rect.x ~y:rect.y ~style:border_style chars.tl;
        Surface.set ~clip surface ~x:(rect.x + rect.width - 1) ~y:rect.y ~style:border_style chars.tr;
        Surface.set ~clip surface ~x:rect.x ~y:(rect.y + rect.height - 1) ~style:border_style chars.bl;
        Surface.set ~clip surface ~x:(rect.x + rect.width - 1) ~y:(rect.y + rect.height - 1) ~style:border_style chars.br;
        for x = rect.x + 1 to rect.x + rect.width - 2 do
          Surface.set ~clip surface ~x ~y:rect.y ~style:border_style chars.h;
          Surface.set ~clip surface ~x ~y:(rect.y + rect.height - 1) ~style:border_style chars.h
        done;
        for y = rect.y + 1 to rect.y + rect.height - 2 do
          Surface.set ~clip surface ~x:rect.x ~y ~style:border_style chars.v;
          Surface.set ~clip surface ~x:(rect.x + rect.width - 1) ~y ~style:border_style chars.v
        done;
        Option.iter (draw_title surface clip rect border_style style.title_align) style.title;
        Option.iter (draw_bottom_title surface clip rect border_style style.bottom_title_align) style.bottom_title
    | _ -> ()

  let fill_background surface clip (rect : Geometry.rect) style =
    match style.Style.bg with
    | None -> ()
    | Some _ -> Surface.fill_rect ~clip surface rect ~style

  let render_text surface clip (rect : Geometry.rect) spans =
    let x = ref rect.Geometry.x in
    let y = ref rect.y in
    List.iter
      (fun span ->
        let nx, ny = Surface.write ~clip surface ~x:!x ~y:!y ~style:span.Span.style span.text in
        x := nx;
        y := ny)
      spans

  let render_input surface clip (rect : Geometry.rect) node_style (state : Node.input_state) focused =
    Surface.fill_rect ~clip surface rect ~style:node_style;
    let text_style =
      if state.Node.value = "" then Style.add_attr Attr.Dim node_style else node_style
    in
    let text = if state.value = "" then state.placeholder else state.value in
    write_clipped surface clip rect.x rect.y text_style text;
    if focused && rect.width > 0 then
      let cursor_x = rect.x + min (rect.width - 1) state.cursor in
      let cursor_style = Style.add_attr Attr.Inverse node_style in
      let ch =
        if state.cursor < String.length state.value then String.make 1 state.value.[state.cursor]
        else " "
      in
      Surface.set ~clip surface ~x:cursor_x ~y:rect.y ~style:cursor_style ch

  let ensure_select_visible (state : Node.select_state) height =
    if state.Node.selected < state.scroll then state.scroll <- state.selected;
    if state.selected >= state.scroll + height then state.scroll <- state.selected - height + 1;
    state.scroll <- max 0 state.scroll

  let render_select surface clip (rect : Geometry.rect) node_style (state : Node.select_state) focused =
    Surface.fill_rect ~clip surface rect ~style:node_style;
    let height = max 0 rect.Geometry.height in
    ensure_select_visible state height;
    let selected_bg =
      Option.value ~default:(Color.ansi 4) node_style.Style.bg |> fun _ -> Color.indexed 60
    in
    for row = 0 to height - 1 do
      let index = state.Node.scroll + row in
      match List.nth_opt state.options index with
      | None -> ()
      | Some option ->
          let selected = index = state.selected in
          let row_style =
            if selected then
              node_style |> Style.with_bg selected_bg |> Style.add_attr (if focused then Attr.Bold else Attr.Inverse)
            else node_style
          in
          let y = rect.y + row in
          Surface.fill_rect ~clip surface (Geometry.rect ~x:rect.x ~y ~width:rect.width ~height:1) ~style:row_style;
          let prefix = if selected then "> " else "  " in
          let description =
            if state.show_description && option.description <> "" then " - " ^ option.description else ""
          in
          write_clipped surface clip rect.x y row_style (prefix ^ option.name ^ description)
    done

  let render_progress surface clip (rect : Geometry.rect) style (state : Node.progress_state) =
    Surface.fill_rect ~clip surface rect ~style;
    if rect.Geometry.width > 0 then
      let label =
        match state.Node.label with
        | Some label -> label
        | None -> Printf.sprintf "%3.0f%%" (state.fraction *. 100.)
      in
      let label_width = Utf.string_width label + 1 in
      let bar_width = max 1 (rect.width - label_width) in
      let filled = int_of_float (Float.floor (state.fraction *. float bar_width)) in
      let full_style = style |> Style.with_fg (Color.ansi 2) in
      let empty_style = style |> Style.add_attr Attr.Dim in
      for i = 0 to bar_width - 1 do
        let ch, cell_style = if i < filled then ("█", full_style) else ("░", empty_style) in
        Surface.set ~clip surface ~x:(rect.x + i) ~y:rect.y ~style:cell_style ch
      done;
      write_clipped surface clip (rect.x + bar_width + 1) rect.y style label

  let render_sparkline surface clip (rect : Geometry.rect) style values =
    let frames = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |] in
    match values with
    | [] -> ()
    | _ ->
        let min_v = List.fold_left min infinity values in
        let max_v = List.fold_left max neg_infinity values in
        let span = if Float.equal min_v max_v then 1. else max_v -. min_v in
        values
        |> List.iteri (fun i value ->
               if i < rect.Geometry.width then
                 let bucket = int_of_float (Float.floor (((value -. min_v) /. span) *. 7.)) |> max 0 |> min 7 in
                 Surface.set ~clip surface ~x:(rect.x + i) ~y:rect.y ~style frames.(bucket))

  let render_vertical_rule surface clip (rect : Geometry.rect) style char =
    for y = rect.Geometry.y to rect.y + rect.height - 1 do
      Surface.set ~clip surface ~x:rect.x ~y ~style char
    done

  let rec render_node surface (positioned : Layout.positioned) =
    let node = positioned.node in
    fill_background surface positioned.clip positioned.rect node.style;
    draw_border surface positioned.clip positioned.rect node.style;
    (match node.kind with
    | Text spans -> render_text surface positioned.clip positioned.content spans
    | Vertical_rule char -> render_vertical_rule surface positioned.clip positioned.content node.style char
    | Input state -> render_input surface positioned.clip positioned.content node.style state node.focused
    | Select state -> render_select surface positioned.clip positioned.content node.style state node.focused
    | Progress_bar state -> render_progress surface positioned.clip positioned.content node.style state
    | Sparkline values -> render_sparkline surface positioned.clip positioned.content node.style values
    | Box | Scroll_box _ | Spacer -> ());
    List.iter (render_node surface) positioned.children

  let render root ~width ~height =
    let surface = Surface.create ~width ~height () in
    let positioned = Layout.compute root ~width ~height in
    render_node surface positioned;
    surface
end

module Viewport = struct
  type t = { width : int; height : int }
  type breakpoint = Tiny | Compact | Regular | Wide
  type orientation = Portrait | Landscape | Square

  let make ~width ~height = { width = max 1 width; height = max 1 height }
  let size t = (t.width, t.height)
  let area t = t.width * t.height
  let fits ?(min_width = 1) ?(min_height = 1) t = t.width >= min_width && t.height >= min_height

  let orientation t =
    if t.width = t.height then Square else if t.width > t.height then Landscape else Portrait

  let breakpoint t =
    if t.width < 60 || t.height < 18 then Tiny
    else if t.width < 80 || t.height < 24 then Compact
    else if t.width >= 120 && t.height >= 30 then Wide
    else Regular

  let breakpoint_name = function Tiny -> "tiny" | Compact -> "compact" | Regular -> "regular" | Wide -> "wide"
  let is_tiny t = breakpoint t = Tiny
  let is_compact t = breakpoint t = Compact
  let is_regular t = breakpoint t = Regular
  let is_wide t = breakpoint t = Wide

  let choose t ~tiny ~compact ~regular ~wide =
    match breakpoint t with Tiny -> tiny | Compact -> compact | Regular -> regular | Wide -> wide
end

module Terminal = struct
  type screen_mode = Alternate_screen | Main_screen

  let output seq =
    output_string stdout seq;
    flush stdout

  let enter_alternate () = output "\027[?1049h\027[?25l"
  let leave_alternate () = output "\027[?25h\027[?1049l\027[0m"

  let positive_int_env env name =
    match Option.bind (env name) int_of_string_opt with Some n when n > 0 -> Some n | _ -> None

  let parse_stty_size line =
    match String.split_on_char ' ' (String.trim line) |> List.filter (( <> ) "") with
    | [ rows; columns ] -> (
        match (int_of_string_opt columns, int_of_string_opt rows) with
        | Some width, Some height when width > 0 && height > 0 -> Some (width, height)
        | _ -> None)
    | _ -> None

  let query_tty_size () =
    let channel = Unix.open_process_in "stty size < /dev/tty 2>/dev/null" in
    Fun.protect
      ~finally:(fun () -> ignore (Unix.close_process_in channel))
      (fun () ->
        match input_line channel with
        | line -> parse_stty_size line
        | exception End_of_file -> None)

  let viewport ?(env = Sys.getenv_opt) ?(fallback_to_tty = true) () =
    match (positive_int_env env "COLUMNS", positive_int_env env "LINES") with
    | Some width, Some height -> Viewport.make ~width ~height
    | _ -> (
        match (if fallback_to_tty then query_tty_size () else None) with
        | Some (width, height) -> Viewport.make ~width ~height
        | None -> Viewport.make ~width:80 ~height:24)

  let size ?env ?fallback_to_tty () = Viewport.size (viewport ?env ?fallback_to_tty ())
  let columns ?env ?fallback_to_tty () = (viewport ?env ?fallback_to_tty ()).width
  let rows ?env ?fallback_to_tty () = (viewport ?env ?fallback_to_tty ()).height
  let is_interactive ?(fd = Unix.stdout) () = try Unix.isatty fd with Unix.Unix_error _ -> false
  let color_level ?(env = Sys.getenv_opt) () = Color.detect_level ~env ()
  let supports_color ?env () = color_level ?env () <> Color.No_color

  let with_raw fd f =
    let original = Unix.tcgetattr fd in
    let raw = { original with Unix.c_icanon = false; c_echo = false; c_vmin = 1; c_vtime = 0 } in
    Fun.protect
      ~finally:(fun () -> Unix.tcsetattr fd Unix.TCSANOW original)
      (fun () ->
        Unix.tcsetattr fd Unix.TCSANOW raw;
        f ())
end

module Renderer = struct
  type config = {
    exit_on_ctrl_c : bool;
    target_fps : int;
    screen_mode : Terminal.screen_mode;
  }

  type t = {
    mutable root : Node.t;
    mutable width : int;
    mutable height : int;
    config : config;
    mutable previous : Surface.t option;
    mutable focused_id : string option;
    keymap : Keymap.t;
    mutable destroyed : bool;
  }

  let default_config = { exit_on_ctrl_c = true; target_fps = 30; screen_mode = Terminal.Alternate_screen }

  let create ?width ?height ?(config = default_config) root =
    let width, height =
      match (width, height) with
      | Some w, Some h -> (w, h)
      | _ -> Terminal.size ()
    in
    let focused_id = Node.focus_first root in
    { root; width; height; config; previous = None; focused_id; keymap = Keymap.create (); destroyed = false }

  let set_root t root =
    t.root <- root;
    t.focused_id <- Node.focus_first root;
    t.previous <- None

  let viewport t = Viewport.make ~width:t.width ~height:t.height
  let size t = Viewport.size (viewport t)

  let resize t ~width ~height =
    let width = max 1 width in
    let height = max 1 height in
    if t.width <> width || t.height <> height then (
      t.width <- width;
      t.height <- height;
      t.previous <- None)

  let resize_to_viewport t viewport = resize t ~width:viewport.Viewport.width ~height:viewport.Viewport.height
  let resize_to_terminal ?env ?fallback_to_tty t = resize_to_viewport t (Terminal.viewport ?env ?fallback_to_tty ())

  let focus t id = if Node.set_focus t.root id then t.focused_id <- Some id
  let focus_next t = t.focused_id <- Node.focus_next t.root t.focused_id
  let request_render t = Render.render t.root ~width:t.width ~height:t.height
  let render_to_string ?(ansi = false) t = let surface = request_render t in if ansi then Surface.to_ansi surface else Surface.to_plain surface

  let render t =
    let next = request_render t in
    let output =
      match t.previous with
      | None -> "\027[H" ^ Surface.to_ansi next
      | Some previous -> Surface.diff_to_ansi previous next
    in
    output_string stdout output;
    flush stdout;
    t.previous <- Some next

  let dispatch_key t key =
    if t.config.exit_on_ctrl_c && key.Key.ctrl && key.name = "c" then (
      t.destroyed <- true;
      true)
    else if key.name = "tab" then (
      focus_next t;
      true)
    else
      match Option.bind t.focused_id (fun id -> Node.find_by_id id t.root) with
      | Some node when Node.handle_key node key -> true
      | _ -> (
          match Keymap.dispatch t.keymap key with Keymap.Handled _ | Pending -> true | Unhandled -> false)

  let destroy t = t.destroyed <- true

  let run t =
    let fd = Unix.descr_of_in_channel stdin in
    let frame_delay = if t.config.target_fps <= 0 then 0.033 else 1. /. float t.config.target_fps in
    Fun.protect
      ~finally:(fun () ->
        if t.config.screen_mode = Terminal.Alternate_screen then Terminal.leave_alternate ())
      (fun () ->
        if t.config.screen_mode = Terminal.Alternate_screen then Terminal.enter_alternate ();
        Terminal.with_raw fd (fun () ->
            render t;
            while not t.destroyed do
              (match Key.read fd with Some key -> ignore (dispatch_key t key) | None -> ());
              render t;
              Unix.sleepf frame_delay
            done))
end

module Components_core = struct
  type tone =
    | Neutral
    | Accent
    | Info
    | Success
    | Warning
    | Error

  type design = { theme : Theme.t; tone_color : tone -> Color.t }

  let default_tone_color theme = function
    | Neutral -> theme Theme.Fg_muted
    | Accent -> theme Theme.Accent_primary
    | Info -> theme Theme.Status_info
    | Success -> theme Theme.Status_success
    | Warning -> theme Theme.Status_warning
    | Error -> theme Theme.Status_error

  let make_design ?(theme = Theme.dark) ?tone_color () =
    let tone_color =
      match tone_color with
      | Some tone_color -> tone_color
      | None -> default_tone_color theme
    in
    { theme; tone_color }

  let default_design = make_design ()
  let resolve_design = function None -> default_design | Some design -> design
  let theme_color design slot = design.theme slot
  let color_of_tone ?design tone = (resolve_design design).tone_color tone
  let surface_of design = theme_color design Theme.Bg_surface
  let overlay_of design = theme_color design Theme.Bg_overlay
  let default_fg_of design = theme_color design Theme.Fg_default
  let muted_fg_of design = theme_color design Theme.Fg_muted
  let emphasis_fg_of design = theme_color design Theme.Fg_emphasis

  let surface = surface_of default_design
  let overlay = overlay_of default_design
  let default_fg = default_fg_of default_design
  let muted_fg = muted_fg_of default_design
  let emphasis_fg = emphasis_fg_of default_design

  let text = Node.text
  let rich_text = Node.rich_text
  let vertical_rule = Node.vertical_rule
  let box = Node.box
  let input = Node.input
  let option = Node.option
  let select = Node.select
  let scroll_box = Node.scroll_box
  let progress_bar = Node.progress_bar
  let sparkline = Node.sparkline
  let spacer = Node.spacer

  let repeat s n =
    if n <= 0 then "" else String.concat "" (List.init n (fun _ -> s))

  let row ?id ?(style = Style.default) ?(gap = 1) children =
    box ?id ~style:Style.{ style with flex_direction = Row; gap } children

  let column ?id ?(style = Style.default) ?(gap = 0) children =
    box ?id ~style:Style.{ style with flex_direction = Column; gap } children

  let panel ?id ?(tone = Accent) ?(title_align = Style.Title_left) ?bottom_title
      ?(style = Style.default) ?design title children =
    let design = resolve_design design in
    box ?id
      ~style:
        Style.
          {
            (make ~border:Rounded ~title ~title_align ?bottom_title
               ~border_fg:(color_of_tone ~design tone) ~padding:(spacing_all 1) ())
            with
            width = style.width;
            height = style.height;
            min_width = style.min_width;
            min_height = style.min_height;
            flex_grow = style.flex_grow;
            flex_shrink = style.flex_shrink;
            flex_direction = style.flex_direction;
            justify_content = style.justify_content;
            align_items = style.align_items;
            position = style.position;
            left = style.left;
            top = style.top;
            right = style.right;
            bottom = style.bottom;
            margin = style.margin;
            gap = style.gap;
            fg = (match style.fg with Some _ -> style.fg | None -> Some (default_fg_of design));
            bg = style.bg;
            attrs = style.attrs;
          }
      children

  let badge ?id ?(tone = Neutral) ?(style = Style.default) ?design label =
    let design = resolve_design design in
    let fg = color_of_tone ~design tone in
    box ?id
      ~style:
        Style.
          {
            (make ~height:(Cells 1) ~padding:(spacing_xy ~x:1 ~y:0)
               ~fg ~attrs:[ Attr.Bold ] ())
            with
            margin = style.margin;
            width = style.width;
          }
      [ text ~style:Style.(make ~fg ~attrs:[ Attr.Bold ] ()) label ]

  let tab_bar ?id ?(style = Style.default) ?design tabs =
    let design = resolve_design design in
    let tab (label, active) =
      let fg = if active then emphasis_fg_of design else muted_fg_of design in
      let attrs = if active then [ Attr.Bold; Attr.Underline ] else [ Attr.Dim ] in
      text ~style:Style.(make ~fg ~attrs ()) label
    in
    box ?id
      ~style:
        Style.
          {
            (make ~height:(Cells 1) ~flex_direction:Row ~gap:2 ())
            with
            width = style.width;
            margin = style.margin;
          }
      (List.map tab tabs)

  let key_value ?id ?(label_width = 12) ?(style = Style.default) ?design pairs =
    let design = resolve_design design in
    let rows =
      pairs
      |> List.map (fun (key, value) ->
             let key_text = if String.length key >= label_width then key else key ^ String.make (label_width - String.length key) ' ' in
             rich_text
               [
                 Span.make ~style:Style.(make ~fg:(muted_fg_of design) ~attrs:[ Attr.Dim ] ()) key_text;
                 Span.make ~style:Style.(make ~fg:(default_fg_of design) ()) value;
               ])
    in
    box ?id ~style:Style.{ style with flex_direction = Column } rows

  let fit width text =
    if width <= 0 then ""
    else
      let text_width = Utf.string_width text in
      if text_width <= width then text ^ String.make (width - text_width) ' '
      else
        let limit = max 0 (width - 1) in
        let used = ref 0 in
        let out = Stdlib.Buffer.create width in
        Uutf.String.fold_utf_8
          (fun () _ -> function
            | `Uchar u ->
                let cell_width = Utf.uchar_width u in
                if !used + cell_width <= limit then (
                  Stdlib.Buffer.add_string out (Utf.uchar_to_utf8 u);
                  used := !used + cell_width)
            | `Malformed _ ->
                if !used + 1 <= limit then (
                  Stdlib.Buffer.add_char out '?';
                  incr used))
          () text;
        let clipped = Stdlib.Buffer.contents out ^ "…" in
        clipped ^ String.make (max 0 (width - Utf.string_width clipped)) ' '

  let table ?id ?(style = Style.default) ?(header_tone = Accent) ?design columns rows =
    let design = resolve_design design in
    let widths = List.map snd columns in
    let line cells =
      List.map2 (fun width cell -> fit width cell) widths cells |> String.concat "  "
    in
    let header_style = Style.(make ~fg:(color_of_tone ~design header_tone) ~attrs:[ Attr.Bold ] ()) in
    let row_style = Style.(make ~fg:(default_fg_of design) ()) in
    let header = text ~style:header_style (line (List.map fst columns)) in
    let divider =
      text ~style:Style.(make ~fg:(muted_fg_of design) ~attrs:[ Attr.Dim ] ())
        (line (List.map (fun (_, width) -> repeat "─" width) columns))
    in
    let body = rows |> List.map (fun cells -> text ~style:row_style (line cells)) in
    box ?id ~style:Style.{ style with flex_direction = Column } (header :: divider :: body)

  let split ?id ?(style = Style.default) ?(left_width = 32) left right =
    box ?id
      ~style:Style.{ style with flex_direction = Row; gap = 1 }
      [
        box ~style:Style.(make ~width:(Cells left_width) ~height:(Percent 1.) ()) left;
        box ~style:Style.(make ~flex_grow:1. ~height:(Percent 1.) ()) right;
      ]
end

module Patterns = struct
  let rule_panel ?id ?(tone = Components_core.Accent) ?(style = Style.default) ?design children =
    let design = Components_core.resolve_design design in
    Components_core.box ?id
      ~style:Style.{ style with flex_direction = Row; gap = 1 }
      [
        Components_core.vertical_rule
          ~style:
            Style.(
              make ~width:(Cells 1) ~height:(Percent 1.)
                ~fg:(Components_core.color_of_tone ~design tone)
                ~attrs:[ Attr.Bold ] ())
          ();
        Components_core.box
          ~style:
            Style.(
              make ~flex_grow:1. ~height:(Percent 1.)
                ~padding:(spacing_xy ~x:1 ~y:0) ~bg:(Components_core.surface_of design)
                ())
          children;
      ]

  let modal ?id ?(tone = Components_core.Accent) ?(style = Style.default)
      ?(bottom_title = "Esc/? close") ?design title children =
    let design_value = Components_core.resolve_design design in
    let modal_width = match style.width with Style.Auto -> Style.Cells 64 | width -> width in
    let modal_height = match style.height with Style.Auto -> Style.Cells 16 | height -> height in
    let content_style =
      Style.
        {
          style with
          width = modal_width;
          height = modal_height;
          flex_direction = Column;
          bg = Some (Components_core.surface_of design_value);
        }
    in
    Components_core.box ?id
      ~style:
        Style.(
          make ~position:Absolute ~left:0 ~right:0 ~top:0 ~bottom:0
            ~width:(Percent 1.) ~height:(Percent 1.) ~justify_content:Justify_center
            ~align_items:Align_center ())
      [ Components_core.panel ~tone ~bottom_title ~style:content_style ?design title children ]

  let header ?id ?subtitle ?(badges = []) ?design title =
    let design_value = Components_core.resolve_design design in
    let title_line =
      Components_core.text
        ~style:Style.(make ~fg:(Components_core.emphasis_fg_of design_value) ~attrs:[ Attr.Bold ] ())
        title
    in
    let subtitle_line =
      match subtitle with
      | None -> []
      | Some copy ->
          [
            Components_core.text
              ~style:Style.(make ~fg:(Components_core.muted_fg_of design_value) ~attrs:[ Attr.Dim ] ())
              copy;
          ]
    in
    let badge_nodes =
      badges |> List.map (fun (tone, label) -> Components_core.badge ~tone ?design label)
    in
    Components_core.box ?id
      ~style:Style.(make ~height:(Cells 3) ~flex_direction:Row ~justify_content:Space_between ~align_items:Align_center ~padding:(spacing_xy ~x:2 ~y:0) ())
      [
        Components_core.box ~style:Style.(make ~flex_direction:Column ()) (title_line :: subtitle_line);
        Components_core.box ~style:Style.(make ~flex_direction:Row ~gap:1 ()) badge_nodes;
      ]

  let metric_card ?id ?(tone = Components_core.Info) ?detail ?progress ?sparkline:series
      ?(style = Style.default) ?design ~label ~value () =
    let design_value = Components_core.resolve_design design in
    let accent = Components_core.color_of_tone ~design:design_value tone in
    let children =
      [
        Components_core.text
          ~style:Style.(make ~fg:(Components_core.muted_fg_of design_value) ~attrs:[ Attr.Dim ] ())
          label;
        Components_core.text
          ~style:Style.(make ~fg:(Components_core.emphasis_fg_of design_value) ~attrs:[ Attr.Bold ] ())
          value;
      ]
      @ (match detail with None -> [] | Some d -> [ Components_core.text ~style:Style.(make ~fg:accent ()) d ])
      @ (match progress with None -> [] | Some p -> [ Components_core.progress_bar ~style:Style.(make ~height:(Cells 1) ()) p ])
      @
      match series with
      | None -> []
      | Some values -> [ Components_core.sparkline ~style:Style.(make ~fg:accent ~height:(Cells 1) ()) values ]
    in
    Components_core.panel ?id ~tone ?design
      ~style:
        Style.
          {
            style with
            height =
              (match style.height with Auto -> Cells (List.length children + 4) | other -> other);
          }
      label children

  let log_feed ?id ?(style = Style.default) ?design entries =
    let design_value = Components_core.resolve_design design in
    let tone_of_level = function
      | "ERR" | "ERROR" | "FAIL" -> Components_core.Error
      | "WARN" | "WARNING" -> Components_core.Warning
      | "OK" | "DONE" -> Components_core.Success
      | "INFO" -> Components_core.Info
      | _ -> Components_core.Neutral
    in
    let row (time, level, message) =
      Components_core.rich_text
        [
          Span.make
            ~style:Style.(make ~fg:(Components_core.muted_fg_of design_value) ~attrs:[ Attr.Dim ] ())
            (time ^ " ");
          Span.make
            ~style:
              Style.(
                make
                  ~fg:(Components_core.color_of_tone ~design:design_value (tone_of_level level))
                  ~attrs:[ Attr.Bold ] ())
            (Components_core.fit 5 level);
          Span.make ~style:Style.(make ~fg:(Components_core.default_fg_of design_value) ()) (" " ^ message);
        ]
    in
    Components_core.scroll_box ?id ~style:Style.{ style with flex_direction = Column } (List.map row entries)

  let section_title ?id ?(tone = Components_core.Accent) ?(style = Style.default) ?design title =
    let design = Components_core.resolve_design design in
    Node.text ?id
      ~style:
        Style.
          {
            (make ~height:(Cells 1) ~fg:(Components_core.color_of_tone ~design tone)
               ~attrs:[ Attr.Bold ] ())
            with
            width = style.width;
            margin = style.margin;
          }
      title

  let nav_item ?id ?(active = false) ?meta ?(tone = Components_core.Accent)
      ?(style = Style.default) ?design label =
    let design = Components_core.resolve_design design in
    let marker = if active then "› " else "  " in
    let fg = if active then Components_core.color_of_tone ~design tone else Components_core.default_fg_of design in
    let attrs = if active then [ Attr.Bold ] else [] in
    let content =
      [
        Span.make ~style:Style.(make ~fg ~attrs ()) (marker ^ label);
      ]
      @
      match meta with
      | None -> []
      | Some meta ->
          [
            Span.make
              ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ~attrs:[ Attr.Dim ] ())
              ("  " ^ meta);
          ]
    in
    Components_core.rich_text ?id ~style:Style.{ style with height = Cells 1 } content

  let message ?id ?(tone = Components_core.Neutral) ?time ?(style = Style.default) ?design ~author body =
    let design = Components_core.resolve_design design in
    let accent = Components_core.color_of_tone ~design tone in
    let header =
      Components_core.rich_text
        [
          Span.make ~style:Style.(make ~fg:accent ~attrs:[ Attr.Bold ] ()) author;
          Span.make
            ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ~attrs:[ Attr.Dim ] ())
            (match time with None -> "" | Some value -> "  " ^ value);
        ]
    in
    let lines =
      body
      |> String.split_on_char '\n'
      |> List.map (fun line ->
             Components_core.text ~style:Style.(make ~fg:(Components_core.default_fg_of design) ()) line)
    in
    Components_core.box ?id
      ~style:
        Style.
          {
            (make ~border:Single ~border_fg:accent ~padding:(spacing_xy ~x:1 ~y:0)
               ~margin:(spacing ~bottom:1 ()) ())
            with
            width = style.width;
            height = style.height;
            flex_grow = style.flex_grow;
          }
      (header :: lines)

  let timeline ?id ?(style = Style.default) ?design entries =
    let design = Components_core.resolve_design design in
    let row (tone, label, detail) =
      Components_core.rich_text
        [
          Span.make
            ~style:
              Style.(
                make ~fg:(Components_core.color_of_tone ~design tone) ~attrs:[ Attr.Bold ] ())
            "● ";
          Span.make
            ~style:Style.(make ~fg:(Components_core.emphasis_fg_of design) ~attrs:[ Attr.Bold ] ())
            label;
          Span.make
            ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ~attrs:[ Attr.Dim ] ())
            ("  " ^ detail);
        ]
    in
    Components_core.box ?id ~style:Style.{ style with flex_direction = Column } (List.map row entries)

  let composer ?id ?(style = Style.default) ?design ?(prompt = ">")
      ?(placeholder = "Type a message") () =
    let design = Components_core.resolve_design design in
    let accent = Components_core.color_of_tone ~design Components_core.Accent in
    Components_core.box ?id
      ~style:
        Style.
          {
            (make ~border:Rounded ~border_fg:accent ~height:(Cells 3)
               ~padding:(spacing_xy ~x:1 ~y:0) ())
            with
            width = style.width;
            margin = style.margin;
          }
      [
        Components_core.box ~style:Style.(make ~flex_direction:Row ~gap:1 ())
          [
            Components_core.text ~style:Style.(make ~fg:accent ~attrs:[ Attr.Bold ] ()) prompt;
            Components_core.input ~style:Style.(make ~flex_grow:1. ()) ~placeholder ();
          ];
      ]

  let command_bar ?id ?(style = Style.default) ?design items =
    let design = Components_core.resolve_design design in
    let content = items |> List.map (fun (key, label) -> "[" ^ key ^ "]" ^ label) |> String.concat " " in
    Node.text ?id
      ~style:
        Style.
          {
            (make ~height:(Cells 1) ~width:(Percent 1.)
               ~bg:(Components_core.overlay_of design) ~fg:(Components_core.default_fg_of design)
               ~attrs:[ Attr.Dim ] ())
            with
            margin = style.margin;
          }
      content

  let footer ?design shortcuts =
    command_bar ?design shortcuts

  let app_shell ?id ?(title = "App") ?subtitle ?(badges = [])
      ?(footer_items = [ ("q", "uit"); ("?", "help"); ("Tab", "focus") ])
      ?design body =
    Components_core.box ?id
      ~style:Style.(make ~width:(Percent 1.) ~height:(Percent 1.) ~flex_direction:Column ())
      [
        header ?subtitle ~badges ?design title;
        Components_core.box
          ~style:Style.(make ~flex_grow:1. ~flex_direction:Column ~padding:(spacing_xy ~x:1 ~y:0) ())
          body;
        command_bar ?design footer_items;
      ]
end

module Presets = struct
  module Open_code = struct
    let glyph = function
      | 'o' -> [ "████"; "█  █"; "█  █"; "█  █"; "████" ]
      | 'p' -> [ "███ "; "█  █"; "███ "; "█   "; "█   " ]
      | 'e' -> [ "████"; "█   "; "███ "; "█   "; "████" ]
      | 'n' -> [ "█  █"; "██ █"; "█ ██"; "█  █"; "█  █" ]
      | 'c' -> [ "████"; "█   "; "█   "; "█   "; "████" ]
      | 'd' -> [ "███ "; "█  █"; "█  █"; "█  █"; "███ " ]
      | 'a' -> [ " ██ "; "█  █"; "████"; "█  █"; "█  █" ]
      | 'g' -> [ "████"; "█   "; "█ ██"; "█  █"; "████" ]
      | 't' -> [ "████"; " ██ "; " ██ "; " ██ "; " ██ " ]
      | 'w' -> [ "█  █"; "█  █"; "█  █"; "████"; "█  █" ]
      | 'r' -> [ "███ "; "█  █"; "███ "; "█ █ "; "█  █" ]
      | 'k' -> [ "█  █"; "█ █ "; "██  "; "█ █ "; "█  █" ]
      | 's' -> [ "████"; "█   "; "████"; "   █"; "████" ]
      | 'i' -> [ "███"; " █ "; " █ "; " █ "; "███" ]
      | ' ' -> [ "  "; "  "; "  "; "  "; "  " ]
      | _ -> [ "██"; "██"; "██"; "██"; "██" ]

    let wordmark ?id ?(style = Style.default) ?design label =
      let design = Components_core.resolve_design design in
      let rows = Array.make 5 "" in
      label
      |> String.lowercase_ascii
      |> String.iter (fun ch ->
             glyph ch
             |> List.iteri (fun i part ->
                    rows.(i) <- rows.(i) ^ part ^ " "));
      Components_core.box ?id ~style:Style.{ style with flex_direction = Column }
        (Array.to_list rows
        |> List.map (fun line ->
               Components_core.text
                 ~style:Style.(make ~fg:(Components_core.emphasis_fg_of design) ~attrs:[ Attr.Bold ] ())
                 line))

    let model_status ?id ?(style = Style.default) ?design ?(mode = "Build")
        ?(model = "DeepSeek V4 Pro") ?(provider = "OpenCode Go")
        ?(effort = "high") () =
      let design = Components_core.resolve_design design in
      Components_core.rich_text ?id ~style
        [
          Span.make
            ~style:
              Style.(
                make ~fg:(Components_core.theme_color design Theme.Accent_secondary)
                  ~attrs:[ Attr.Bold ] ())
            mode;
          Span.make ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ()) " · ";
          Span.make
            ~style:Style.(make ~fg:(Components_core.default_fg_of design) ~attrs:[ Attr.Bold ] ())
            model;
          Span.make ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ())
            (" " ^ provider ^ " · ");
          Span.make
            ~style:
              Style.(
                make ~fg:(Components_core.theme_color design Theme.Status_warning)
                  ~attrs:[ Attr.Bold ] ())
            effort;
        ]

    let command_block ?id ?(tone = Components_core.Accent) ?(style = Style.default)
        ?design command =
      let design_value = Components_core.resolve_design design in
      Patterns.rule_panel ?id ~tone ?design
        ~style:Style.{ style with height = (match style.height with Auto -> Cells 4 | h -> h) }
        [
          Components_core.text
            ~style:Style.(make ~fg:(Components_core.default_fg_of design_value) ())
            command;
        ]

    let hint_bar ?id ?(style = Style.default) ?design items =
      let design = Components_core.resolve_design design in
      let spans =
        items
        |> List.concat_map (fun (key, label) ->
               [
                 Span.make
                   ~style:
                     Style.(
                       make ~fg:(Components_core.default_fg_of design) ~attrs:[ Attr.Bold ] ())
                   key;
                 Span.make ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ())
                   (" " ^ label ^ "   ");
               ])
      in
      Components_core.rich_text ?id ~style spans

    let tip ?id ?(style = Style.default) ?design message =
      let design = Components_core.resolve_design design in
      Components_core.rich_text ?id ~style
        [
          Span.make
            ~style:
              Style.(
                make ~fg:(Components_core.theme_color design Theme.Status_warning)
                  ~attrs:[ Attr.Bold ] ())
            "● Tip ";
          Span.make ~style:Style.(make ~fg:(Components_core.muted_fg_of design) ()) message;
        ]
  end
end

module Components = struct
  include Components_core

  let rule_panel = Patterns.rule_panel
  let modal = Patterns.modal
  let header = Patterns.header
  let metric_card = Patterns.metric_card
  let log_feed = Patterns.log_feed
  let section_title = Patterns.section_title
  let nav_item = Patterns.nav_item
  let message = Patterns.message
  let timeline = Patterns.timeline
  let composer = Patterns.composer
  let command_bar = Patterns.command_bar
  let footer = Patterns.footer
  let app_shell = Patterns.app_shell
  let wordmark = Presets.Open_code.wordmark
  let model_status = Presets.Open_code.model_status
  let command_block = Presets.Open_code.command_block
  let hint_bar = Presets.Open_code.hint_bar
  let tip = Presets.Open_code.tip
end

let text = Components.text
let rich_text = Components.rich_text
let vertical_rule = Components.vertical_rule
let box = Components.box
let input = Components.input
let option = Components.option
let select = Components.select
let scroll_box = Components.scroll_box
let progress_bar = Components.progress_bar
let sparkline = Components.sparkline
let modal = Patterns.modal
let terminal_viewport = Terminal.viewport
let terminal_size = Terminal.size
