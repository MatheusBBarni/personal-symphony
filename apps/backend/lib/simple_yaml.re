type scalar =
  | String(string)
  | Int(int)
  | List(list(string))
  | Map(list((string, scalar)));

exception Parse_error(string);

let strip_quotes = s => {
  let s = Util.trim(s);
  let len = String.length(s);
  if (
    len >= 2 &&
    ((s.[0] == '"' && s.[len - 1] == '"') || (s.[0] == '\'' && s.[len - 1] == '\''))
  ) {
    String.sub(s, 1, len - 2);
  } else {
    s;
  };
};

let parse_list = value => {
  let value = Util.trim(value);
  let len = String.length(value);
  if (len >= 2 && value.[0] == '[' && value.[len - 1] == ']') {
    let inner = String.sub(value, 1, len - 2);
    inner
    |> String.split_on_char(',')
    |> List.map(s => strip_quotes(Util.trim(s)))
    |> List.filter(s => s != "");
  } else {
    raise(Parse_error("expected inline list: " ++ value));
  };
};

let scalar_of_string = value => {
  let value = Util.trim(value);
  if (value == "") {
    Map([]);
  } else if (String.length(value) >= 2 && value.[0] == '[') {
    List(parse_list(value));
  } else {
    switch (int_of_string_opt(value)) {
    | Some(i) => Int(i)
    | None => String(strip_quotes(value))
    };
  };
};

let indentation = line => {
  let rec loop = i =>
    if (i < String.length(line) && line.[i] == ' ') {
      loop(i + 1);
    } else {
      i;
    };
  loop(0);
};

let split_key_value = line =>
  switch (String.index_opt(line, ':')) {
  | None => raise(Parse_error("expected key:value line: " ++ line))
  | Some(i) =>
    let key = String.sub(line, 0, i) |> Util.trim;
    let value = String.sub(line, i + 1, String.length(line) - i - 1) |> Util.trim;
    if (key == "") {
      raise(Parse_error("empty key in line: " ++ line));
    };
    (key, value);
  };

let parse = lines => {
  let root = Hashtbl.create(16);
  let current_section = ref(None);
  let set_root = (k, v) => Hashtbl.replace(root, k, v);
  let add_to_section = (section, k, v) => {
    let existing =
      switch (Hashtbl.find_opt(root, section)) {
      | Some(Map(fields)) => fields
      | _ => []
      };
    Hashtbl.replace(root, section, Map([(k, v), ...List.remove_assoc(k, existing)]));
  };
  List.iter(
    raw_line => {
      let line = Util.trim(raw_line);
      if (line != "" && !Util.starts_with(~prefix="#", line)) {
        switch (indentation(raw_line)) {
        | 0 =>
          let (key, value) = split_key_value(line);
          if (value == "") {
            set_root(key, Map([]));
            current_section := Some(key);
          } else {
            set_root(key, scalar_of_string(value));
            current_section := None;
          };
        | n when n >= 2 =>
          switch (current_section^) {
          | None => raise(Parse_error("nested key without parent: " ++ line))
          | Some(section) =>
            let (key, value) = split_key_value(line);
            add_to_section(section, key, scalar_of_string(value));
          };
        | _ => raise(Parse_error("unsupported indentation: " ++ raw_line))
        };
      };
    },
    lines,
  );
  Hashtbl.fold((k, v, acc) => [(k, v), ...acc], root, []);
};

let get_map = (key, fields) =>
  switch (List.assoc_opt(key, fields)) {
  | Some(Map(fields)) => fields
  | _ => []
  };

let get_string = (key, fields) =>
  switch (List.assoc_opt(key, fields)) {
  | Some(String(s)) => Some(s)
  | Some(Int(i)) => Some(string_of_int(i))
  | _ => None
  };

let get_int = (key, fields) =>
  switch (List.assoc_opt(key, fields)) {
  | Some(Int(i)) => Some(i)
  | Some(String(s)) => int_of_string_opt(s)
  | _ => None
  };

let get_list = (key, fields) =>
  switch (List.assoc_opt(key, fields)) {
  | Some(List(xs)) => xs
  | _ => []
  };
