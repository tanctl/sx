type t = {
  filename : string;
  line : int;
  column : int;
}

let make ~filename ~line ~column = { filename; line; column }

let dummy = { filename = "<unknown>"; line = 1; column = 1 }

let to_string pos =
  Printf.sprintf "%s:%d:%d" pos.filename pos.line pos.column

let compare pos1 pos2 =
  let cmp = String.compare pos1.filename pos2.filename in
  if cmp <> 0 then cmp
  else
    let cmp = Int.compare pos1.line pos2.line in
    if cmp <> 0 then cmp else Int.compare pos1.column pos2.column