type t = {
  path: string,
  dir: string,
  config: list((string, Simple_yaml.scalar)),
  prompt_template: string,
};

type error =
  | Missing_workflow_file(string)
  | Workflow_parse_error(string)
  | Workflow_front_matter_not_a_map;

exception Error(error);

let string_of_error = fun
| Missing_workflow_file(path) => "missing_workflow_file: " ++ path
| Workflow_parse_error(msg) => "workflow_parse_error: " ++ msg
| Workflow_front_matter_not_a_map => "workflow_front_matter_not_a_map";

let split_front_matter = content => {
  let rec drop_leading_blank = fun
  | [line, ...rest] when Util.trim(line) == "" => drop_leading_blank(rest)
  | lines => lines;
  let lines = Util.split_lines(content) |> drop_leading_blank;
  switch (lines) {
  | [first, ...rest] when Util.trim(first) == "---" =>
    let rec collect_front = (acc, lines) =>
      switch (lines) {
      | [] => raise(Error(Workflow_parse_error("unterminated front matter")))
      | [line, ...tail] when Util.trim(line) == "---" => (List.rev(acc), tail)
      | [line, ...tail] => collect_front([line, ...acc], tail)
      };
    let (front, body) = collect_front([], rest);
    (front, String.concat("\n", body) |> Util.trim);
  | _ => ([], Util.trim(content))
  };
};

let load = path => {
  if (!Sys.file_exists(path)) {
    raise(Error(Missing_workflow_file(path)));
  };
  let content = Util.read_file(path);
  let (front, prompt_template) = split_front_matter(content);
  let config =
    try(Simple_yaml.parse(front)) {
    | Simple_yaml.Parse_error(msg) => raise(Error(Workflow_parse_error(msg)))
    };
  {
    path,
    dir: Filename.dirname(Unix.realpath(path)),
    config,
    prompt_template,
  };
};
