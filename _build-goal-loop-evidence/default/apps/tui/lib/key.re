  type event = {
    name: string,
    sequence: string,
    ctrl: bool,
    shift: bool,
    alt: bool,
  };

  let make = (~ctrl=false, ~shift=false, ~alt=false, ~name, ~sequence, ()) => {
    name,
    sequence,
    ctrl,
    shift,
    alt,
  };

  let ctrl_name = c =>
    String.make(1, Char.chr(Char.code('a') + Char.code(c) - 1));

  let of_sequence =
    fun
    | "\r"
    | "\n" => make(~name="return", ~sequence="\n", ())
    | "\t" => make(~name="tab", ~sequence="\t", ())
    | "\027" => make(~name="escape", ~sequence="\027", ())
    | ""
    | "\b" => make(~name="backspace", ~sequence="", ())
    | "\027[A" => make(~name="up", ~sequence="\027[A", ())
    | "\027[B" => make(~name="down", ~sequence="\027[B", ())
    | "\027[C" => make(~name="right", ~sequence="\027[C", ())
    | "\027[D" => make(~name="left", ~sequence="\027[D", ())
    | "\027[5~" => make(~name="pageup", ~sequence="\027[5~", ())
    | "\027[6~" => make(~name="pagedown", ~sequence="\027[6~", ())
    | "\027[H"
    | "\027[1~" => make(~name="home", ~sequence="\027[H", ())
    | "\027[F"
    | "\027[4~" => make(~name="end", ~sequence="\027[F", ())
    | seq when String.length(seq) == 1 => {
        let c = seq.[0];
        let code = Char.code(c);
        if (code >= 1 && code <= 26) {
          make(~ctrl=true, ~name=ctrl_name(c), ~sequence=seq, ());
        } else if (c == ' ') {
          make(~name="space", ~sequence=seq, ());
        } else {
          make(~name=String.make(1, c), ~sequence=seq, ());
        };
      }
    | seq when String.length(seq) == 2 && seq.[0] == '\027' =>
      make(~alt=true, ~name=String.make(1, seq.[1]), ~sequence=seq, ())
    | seq => make(~name="unknown", ~sequence=seq, ());

  let read_sequence = fd => {
    let first = Bytes.create(1);
    switch (Unix.read(fd, first, 0, 1)) {
    | 0 => None
    | _ =>
      let out = Stdlib.Buffer.create(8);
      Stdlib.Buffer.add_char(out, Bytes.get(first, 0));
      if (Bytes.get(first, 0) == '\027') {
        let more = Bytes.create(1);
        let rec drain = () =>
          switch (Unix.select([fd], [], [], 0.005)) {
          | ([], _, _) => ()
          | _ =>
            switch (Unix.read(fd, more, 0, 1)) {
            | 0 => ()
            | _ =>
              Stdlib.Buffer.add_char(out, Bytes.get(more, 0));
              drain();
            }
          };

        drain();
      };
      Some(Stdlib.Buffer.contents(out));
    };
  };

  let read = fd => Option.map(of_sequence, read_sequence(fd));
