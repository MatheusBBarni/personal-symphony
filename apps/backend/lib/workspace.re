type t = {
  path: string,
  workspace_key: string,
  created_now: bool,
};

exception Workspace_error(string);

let is_sanitary = c =>
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  (c >= '0' && c <= '9') ||
  c == '.' || c == '_' || c == '-';

let sanitize = identifier =>
  String.map(c => is_sanitary(c) ? c : '_', identifier);

let is_inside = (~root, ~path) => {
  let root = Unix.realpath(root);
  let path = Unix.realpath(path);
  path == root || Util.starts_with(~prefix=root ++ Filename.dir_sep, path);
};

let create_for_issue = (~root, identifier) => {
  Util.mkdir_p(root);
  let workspace_key = sanitize(identifier);
  let path = Filename.concat(root, workspace_key);
  let created_now =
    if (Sys.file_exists(path)) {
      if (!Sys.is_directory(path)) {
        raise(Workspace_error(path ++ " exists and is not a directory"));
      };
      false;
    } else {
      Unix.mkdir(path, 0o755);
      true;
    };
  if (!is_inside(~root, ~path)) {
    raise(Workspace_error("workspace escaped configured root"));
  };
  {path: Unix.realpath(path), workspace_key, created_now};
};
