exception Template_render_error(string);

let render = (~issue, ~attempt, template) => {
  let len = String.length(template);
  let buf = Buffer.create(len);
  let rec loop = i =>
    if (i >= len) {
      Buffer.contents(buf);
    } else if (i + 1 < len && template.[i] == '{' && template.[i + 1] == '{') {
      switch (String.index_from_opt(template, i + 2, '}')) {
      | None => raise(Template_render_error("unterminated interpolation"))
      | Some(close)
        when close + 1 < len && template.[close + 1] == '}'
        => {
        let expr = String.sub(template, i + 2, close - i - 2) |> Util.trim;
        let value =
          switch (expr) {
          | "attempt" => Option.value(Option.map(string_of_int, attempt), ~default="")
          | _ =>
            switch (Util.drop_prefix(~prefix="issue.", expr)) {
            | Some(field) =>
              switch (Issue.field(issue, field)) {
              | Some(value) => value
              | None =>
                raise(Template_render_error("unknown issue field: " ++ field))
              }
            | None =>
              raise(Template_render_error("unknown template variable: " ++ expr))
            }
          };
        Buffer.add_string(buf, value);
        loop(close + 2);
      }
      | _ => raise(Template_render_error("unterminated interpolation"))
      };
    } else {
      Buffer.add_char(buf, template.[i]);
      loop(i + 1);
    };
  loop(0);
};
