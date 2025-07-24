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
    yojson_to_ast ~filename yojson
  with
  | Yojson.Json_error msg ->
      let pos = Position.make ~filename ~line:1 ~column:1 in
      Error.parse_error ~message:("JSON parse error: " ^ msg) ~position:pos ~source_context:content ()

let parse_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_string ~filename content
  with
  | Error.Sx_error _ as e -> raise e
  | Sys_error msg ->
      Error.io_error ~message:("File error: " ^ msg) ~position:Position.dummy ()