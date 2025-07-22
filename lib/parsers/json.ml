open Sx

let position_from_lexbuf lexbuf filename =
  let pos = Lexing.lexeme_start_p lexbuf in
  Position.make ~filename ~line:pos.pos_lnum ~column:(pos.pos_cnum - pos.pos_bol + 1)

let rec yojson_to_ast ~filename = function
  | `Null ->
      Ast.Null (Position.dummy)
  | `Bool b ->
      Ast.Bool (b, Position.dummy)
  | `Int i ->
      Ast.Int (i, Position.dummy)
  | `Float f ->
      Ast.Float (f, Position.dummy)
  | `String s ->
      Ast.String (s, Position.dummy)
  | `List values ->
      let converted = List.map (yojson_to_ast ~filename) values in
      Ast.List (converted, Position.dummy)
  | `Assoc assoc ->
      let converted = List.map (fun (k, v) -> (k, yojson_to_ast ~filename v)) assoc in
      Ast.Assoc (converted, Position.dummy)

let parse_string ~filename content =
  try
    let yojson = Yojson.Basic.from_string content in
    Ok (yojson_to_ast ~filename yojson)
  with
  | Yojson.Json_error msg ->
      Error (Ast.error ~message:("JSON parse error: " ^ msg) ~position:Position.dummy)

let parse_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_string ~filename content
  with
  | Sys_error msg ->
      Error (Ast.error ~message:("File error: " ^ msg) ~position:Position.dummy)