open Sx

let rec yaml_to_ast ~filename = function
  | `Null ->
      Ast.Null (Position.dummy)
  | `Bool b ->
      Ast.Bool (b, Position.dummy)
  | `Float f ->
      if Float.is_integer f && f >= Float.of_int Int.min_int && f <= Float.of_int Int.max_int then
        Ast.Int (Float.to_int f, Position.dummy)
      else
        Ast.Float (f, Position.dummy)
  | `String s ->
      Ast.String (s, Position.dummy)
  | `A values ->
      let converted = List.map (yaml_to_ast ~filename) values in
      Ast.List (converted, Position.dummy)
  | `O assoc ->
      let converted = List.map (fun (k, v) -> (k, yaml_to_ast ~filename v)) assoc in
      Ast.Assoc (converted, Position.dummy)

let parse_string ~filename content =
  try
    match Yaml.of_string content with
    | Ok yaml_value ->
        yaml_to_ast ~filename yaml_value
    | Error (`Msg msg) ->
        let pos = Position.make ~filename ~line:1 ~column:1 in
        Error.parse_error ~message:("YAML parse error: " ^ msg) ~position:pos ~source_context:content ()
  with
  | Error.Sx_error _ as e -> raise e
  | exn ->
      let pos = Position.make ~filename ~line:1 ~column:1 in
      Error.parse_error 
        ~message:("YAML parsing failed: " ^ Printexc.to_string exn) 
        ~position:pos 
        ~source_context:content ()

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