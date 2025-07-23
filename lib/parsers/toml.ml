open Sx

let position_from_error filename _error_msg =
  Position.make ~filename ~line:1 ~column:1

let parse_string ~filename content =
  try
    let lines = String.split_on_char '\n' content in
    let rec parse_lines acc = function
      | [] -> List.rev acc
      | line :: rest ->
          let trimmed = String.trim line in
          if trimmed = "" || String.get trimmed 0 = '#' then
            parse_lines acc rest
          else if String.contains trimmed '=' then
            let parts = String.split_on_char '=' trimmed in
            match parts with
            | [key; value] ->
                let clean_key = String.trim key in
                let clean_value = String.trim value in
                let parsed_value = 
                  if clean_value = "true" then
                    Ast.Bool (true, Position.dummy)
                  else if clean_value = "false" then
                    Ast.Bool (false, Position.dummy)
                  else if String.get clean_value 0 = '"' && 
                          String.get clean_value (String.length clean_value - 1) = '"' then
                    let str_content = String.sub clean_value 1 (String.length clean_value - 2) in
                    Ast.String (str_content, Position.dummy)
                  else
                    try 
                      let int_val = int_of_string clean_value in
                      Ast.Int (int_val, Position.dummy)
                    with _ ->
                      try
                        let float_val = float_of_string clean_value in
                        Ast.Float (float_val, Position.dummy)
                      with _ ->
                        Ast.String (clean_value, Position.dummy)
                in
                parse_lines ((clean_key, parsed_value) :: acc) rest
            | _ -> parse_lines acc rest
          else
            parse_lines acc rest
    in
    let pairs = parse_lines [] lines in
    Ast.Assoc (pairs, Position.dummy)
  with
  | exn ->
      let pos = position_from_error filename (Printexc.to_string exn) in
      Error.parse_error 
        ~message:("TOML parsing failed: " ^ Printexc.to_string exn) 
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