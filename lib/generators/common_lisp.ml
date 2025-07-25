open Sx

let escape_string s =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter (function
    | '"' -> Buffer.add_string buf "\\\""
    | '\\' -> Buffer.add_string buf "\\\\"
    | '\n' -> Buffer.add_string buf "\\n"
    | '\r' -> Buffer.add_string buf "\\r"
    | '\t' -> Buffer.add_string buf "\\t"
    | c -> Buffer.add_char buf c) s;
  Buffer.add_char buf '"';
  Buffer.contents buf

let rec ast_to_sexp = function
  | Ast.Null _ -> Ast.Atom "nil"
  | Ast.Bool (true, _) -> Ast.Atom "t"
  | Ast.Bool (false, _) -> Ast.Atom "nil" (* common lisp boolean syntax *)
  | Ast.Int (i, _) -> Ast.Atom (string_of_int i)
  | Ast.Float (f, _) -> Ast.Atom (string_of_float f)
  | Ast.String (s, _) -> Ast.Atom (escape_string s)
  | Ast.List (values, _) ->
      let converted = List.map ast_to_sexp values in
      Ast.List converted
  | Ast.Assoc (assoc, _) ->
      let pairs = List.map (fun (key, value) ->
        Ast.List [Ast.Atom (escape_string key); ast_to_sexp value]
      ) assoc in
      Ast.List pairs

let generate ?(formatting=Ast.Pretty) ast =
  let sexp = ast_to_sexp ast in
  Ast.sexp_to_string ~formatting sexp