@send external toLowerCase: string => string = "toLowerCase"
@send external trim: string => string = "trim"
external nullableString: string => Nullable.t<string> = "%identity"

let normalizedString = value => {
  switch value->nullableString->Nullable.toOption {
  | None => None
  | Some(value) =>
    let normalized = value->trim
    switch normalized->toLowerCase {
    | "" | "null" | "undefined" => None
    | _ => Some(normalized)
    }
  }
}

let trackerKindOrDefault = value =>
  switch normalizedString(value) {
  | Some(value) => value
  | None => "github"
  }
