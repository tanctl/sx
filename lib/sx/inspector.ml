
let format_position pos =
  if pos = Position.dummy then ""
  else " @ " ^ Position.to_string pos

let rec format_value ?(indent=0) ?(is_last=true) ?(key=None) value =
  let prefix = 
    if indent = 0 then ""
    else
      let spaces = String.make (indent - 2) ' ' in
      let connector = if is_last then "└─ " else "├─ " in
      spaces ^ connector
  in
  
  let key_part = match key with
    | None -> ""
    | Some k -> "\"" ^ k ^ "\" -> "
  in
  
  let pos_info = format_position (Ast.position_of value) in
  
  match value with
  | Ast.Null _ -> 
      prefix ^ key_part ^ "Null" ^ pos_info
  | Ast.Bool (b, _) ->
      prefix ^ key_part ^ "Bool(" ^ string_of_bool b ^ ")" ^ pos_info
  | Ast.Int (i, _) ->
      prefix ^ key_part ^ "Int(" ^ string_of_int i ^ ")" ^ pos_info
  | Ast.Float (f, _) ->
      prefix ^ key_part ^ "Float(" ^ string_of_float f ^ ")" ^ pos_info
  | Ast.String (s, _) ->
      prefix ^ key_part ^ "String(\"" ^ s ^ "\")" ^ pos_info
  | Ast.List (values, _) ->
      let header = prefix ^ key_part ^ "List" ^ pos_info in
      if values = [] then
        header ^ " []"
      else
        let child_indent = indent + 2 in
        let child_lines = List.mapi (fun i v ->
          let is_last_child = i = List.length values - 1 in
          format_value ~indent:child_indent ~is_last:is_last_child v
        ) values in
        header ^ "\n" ^ String.concat "\n" child_lines
  | Ast.Assoc (pairs, _) ->
      let header = prefix ^ key_part ^ "Assoc" ^ pos_info in
      if pairs = [] then
        header ^ " {}"
      else
        let child_indent = indent + 2 in
        let child_lines = List.mapi (fun i (k, v) ->
          let is_last_child = i = List.length pairs - 1 in
          format_value ~indent:child_indent ~is_last:is_last_child ~key:(Some k) v
        ) pairs in
        header ^ "\n" ^ String.concat "\n" child_lines

let dump_ast ast =
  format_value ast

let print_ast ast =
  Printf.printf "%s\n" (dump_ast ast);
  flush stdout