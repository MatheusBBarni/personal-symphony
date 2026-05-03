exception Template_render_error of string

let render ~issue ~attempt template =
  let len = String.length template in
  let buf = Buffer.create len in
  let rec loop i =
    if i >= len then Buffer.contents buf
    else if i + 1 < len && template.[i] = '{' && template.[i + 1] = '{' then (
      match String.index_from_opt template (i + 2) '}' with
      | None -> raise (Template_render_error "unterminated interpolation")
      | Some close when close + 1 < len && template.[close + 1] = '}' ->
          let expr = String.sub template (i + 2) (close - i - 2) |> Util.trim in
          let value =
            match expr with
            | "attempt" -> Option.value (Option.map string_of_int attempt) ~default:""
            | _ -> (
                match Util.drop_prefix ~prefix:"issue." expr with
                | Some field -> (
                    match Issue.field issue field with
                    | Some value -> value
                    | None -> raise (Template_render_error ("unknown issue field: " ^ field)))
                | None -> raise (Template_render_error ("unknown template variable: " ^ expr)))
          in
          Buffer.add_string buf value;
          loop (close + 2)
      | _ -> raise (Template_render_error "unterminated interpolation"))
    else (
      Buffer.add_char buf template.[i];
      loop (i + 1))
  in
  loop 0
