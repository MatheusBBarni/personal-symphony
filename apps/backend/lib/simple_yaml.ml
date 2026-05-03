type scalar = String of string | Int of int | List of string list | Map of (string * scalar) list

exception Parse_error of string

let strip_quotes s =
  let s = Util.trim s in
  let len = String.length s in
  if len >= 2 && ((s.[0] = '"' && s.[len - 1] = '"') || (s.[0] = '\'' && s.[len - 1] = '\''))
  then String.sub s 1 (len - 2)
  else s

let parse_list value =
  let value = Util.trim value in
  let len = String.length value in
  if len >= 2 && value.[0] = '[' && value.[len - 1] = ']' then
    let inner = String.sub value 1 (len - 2) in
    inner |> String.split_on_char ',' |> List.map (fun s -> strip_quotes (Util.trim s))
    |> List.filter (fun s -> s <> "")
  else
    raise (Parse_error ("expected inline list: " ^ value))

let scalar_of_string value =
  let value = Util.trim value in
  if value = "" then Map []
  else if String.length value >= 2 && value.[0] = '[' then List (parse_list value)
  else match int_of_string_opt value with Some i -> Int i | None -> String (strip_quotes value)

let indentation line =
  let rec loop i = if i < String.length line && line.[i] = ' ' then loop (i + 1) else i in
  loop 0

let split_key_value line =
  match String.index_opt line ':' with
  | None -> raise (Parse_error ("expected key:value line: " ^ line))
  | Some i ->
      let key = String.sub line 0 i |> Util.trim in
      let value = String.sub line (i + 1) (String.length line - i - 1) |> Util.trim in
      if key = "" then raise (Parse_error ("empty key in line: " ^ line));
      (key, value)

let parse lines =
  let root = Hashtbl.create 16 in
  let current_section = ref None in
  let set_root k v = Hashtbl.replace root k v in
  let add_to_section section k v =
    let existing =
      match Hashtbl.find_opt root section with Some (Map fields) -> fields | _ -> []
    in
    Hashtbl.replace root section (Map ((k, v) :: List.remove_assoc k existing))
  in
  List.iter
    (fun raw_line ->
      let line = Util.trim raw_line in
      if line <> "" && not (Util.starts_with ~prefix:"#" line) then
        match indentation raw_line with
        | 0 ->
            let key, value = split_key_value line in
            if value = "" then (
              set_root key (Map []);
              current_section := Some key)
            else (
              set_root key (scalar_of_string value);
              current_section := None)
        | n when n >= 2 -> (
            match !current_section with
            | None -> raise (Parse_error ("nested key without parent: " ^ line))
            | Some section ->
                let key, value = split_key_value line in
                add_to_section section key (scalar_of_string value))
        | _ -> raise (Parse_error ("unsupported indentation: " ^ raw_line)))
    lines;
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) root []

let get_map key fields =
  match List.assoc_opt key fields with Some (Map fields) -> fields | _ -> []

let get_string key fields =
  match List.assoc_opt key fields with Some (String s) -> Some s | Some (Int i) -> Some (string_of_int i) | _ -> None

let get_int key fields =
  match List.assoc_opt key fields with Some (Int i) -> Some i | Some (String s) -> int_of_string_opt s | _ -> None

let get_list key fields =
  match List.assoc_opt key fields with Some (List xs) -> xs | _ -> []
