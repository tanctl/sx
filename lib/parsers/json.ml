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

(* json streaming *)
module Stream = struct
  type 'a stream_result = 
    | StreamItem of 'a
    | StreamEnd
    | StreamError of string

  let yojson_safe_to_basic yojson =
    (* convert yojson.safe.t to yojson.basic.t by removing unsupported variants *)
    let rec convert = function
      | `Null -> `Null
      | `Bool b -> `Bool b
      | `Int i -> `Int i
      | `Intlit s -> `Int (int_of_string s) (* convert intlit to int *)
      | `Float f -> `Float f
      | `String s -> `String s
      | `List items -> `List (List.map convert items)
      | `Assoc assoc -> `Assoc (List.map (fun (k, v) -> (k, convert v)) assoc)
      | `Tuple items -> `List (List.map convert items) (* convert tuple to list *)
      | `Variant (name, opt_value) -> (* convert variant to object *)
          let value = match opt_value with
            | None -> `Null
            | Some v -> convert v
          in
          `Assoc [("variant", `String name); ("value", value)]
    in
    convert yojson

  let yojson_seq_to_ast_seq ~filename seq =
    let convert_item yojson =
      try 
        let basic_yojson = yojson_safe_to_basic yojson in
        StreamItem (yojson_to_ast ~filename basic_yojson)
      with exn -> StreamError (Printexc.to_string exn)
    in
    Seq.map convert_item seq

  let parse_json_array_stream ~filename channel =
    let state = ref `ExpectOpenBracket in
    let current_item = Buffer.create 256 in
    let brace_depth = ref 0 in
    let in_string = ref false in
    let escaped = ref false in
    
    let rec next_item () =
      try
        match !state with
        | `ExpectOpenBracket ->
            (* skip whitespace and find opening bracket *)
            let rec find_bracket () =
              let c = input_char channel in
              match c with
              | '[' -> 
                  state := `InArray;
                  next_item ()
              | ' ' | '\t' | '\n' | '\r' -> find_bracket ()
              | _ -> raise (Failure ("Expected '[' at start of JSON array, found: " ^ String.make 1 c))
            in
            find_bracket ()
            
        | `InArray ->
            let rec parse_char () =
              let c = input_char channel in
              
              if !escaped then begin
                Buffer.add_char current_item c;
                escaped := false;
                parse_char ()
              end else begin
                match c with
                | '\\' when !in_string ->
                    Buffer.add_char current_item c;
                    escaped := true;
                    parse_char ()
                | '"' ->
                    Buffer.add_char current_item c;
                    in_string := not !in_string;
                    parse_char ()
                | '{' when not !in_string ->
                    Buffer.add_char current_item c;
                    incr brace_depth;
                    parse_char ()
                | '}' when not !in_string ->
                    Buffer.add_char current_item c;
                    decr brace_depth;
                    if !brace_depth = 0 then begin
                      (* complete json object found *)
                      let item_str = Buffer.contents current_item in
                      Buffer.clear current_item;
                      try
                        let yojson = Yojson.Basic.from_string item_str in
                        let ast = yojson_to_ast ~filename yojson in
                        Seq.Cons (StreamItem ast, next_item)
                      with
                      | Yojson.Json_error msg ->
                          Seq.Cons (StreamError ("JSON parse error: " ^ msg), next_item)
                      | exn ->
                          Seq.Cons (StreamError (Printexc.to_string exn), next_item)
                    end else
                      parse_char ()
                | ',' when not !in_string && !brace_depth = 0 ->
                    (* skip comma between items *)
                    parse_char ()
                | ']' when not !in_string && !brace_depth = 0 ->
                    state := `Finished;
                    Seq.Nil
                | ' ' | '\t' | '\n' | '\r' when not !in_string && !brace_depth = 0 ->
                    (* skip whitespace between items *)
                    parse_char ()
                | _ when not !in_string && !brace_depth = 0 && c = '{' ->
                    Buffer.add_char current_item c;
                    incr brace_depth;
                    parse_char ()
                | _ ->
                    Buffer.add_char current_item c;
                    parse_char ()
              end
            in
            parse_char ()
            
        | `Finished -> Seq.Nil
      with
      | End_of_file -> 
          if Buffer.length current_item > 0 then
            Seq.Cons (StreamError "Unexpected end of file in JSON array", fun () -> Seq.Nil)
          else
            Seq.Nil
      | exn -> 
          Seq.Cons (StreamError (Printexc.to_string exn), fun () -> Seq.Nil)
    in
    next_item

  let parse_jsonlines_stream ~filename channel =
    let rec next_line () =
      try
        let line = input_line channel in
        let trimmed = String.trim line in (* skip empty lines *)
        if trimmed = "" then next_line () else
        try
          let yojson = Yojson.Basic.from_string trimmed in
          let ast = yojson_to_ast ~filename yojson in
          Seq.Cons (StreamItem ast, next_line)
        with
        | Yojson.Json_error msg ->
            Seq.Cons (StreamError ("JSON parse error in line: " ^ msg), next_line)
        | exn ->
            Seq.Cons (StreamError (Printexc.to_string exn), next_line)
      with
      | End_of_file -> Seq.Nil
    in
    next_line

  let process_stream ~on_item ~on_error ~on_complete stream =
    let rec process seq_func =
      match seq_func () with
      | Seq.Nil -> on_complete ()
      | Seq.Cons (StreamItem item, rest) ->
          on_item item;
          process rest
      | Seq.Cons (StreamError error, rest) ->
          on_error error;
          process rest
      | Seq.Cons (StreamEnd, rest) ->
          process rest
    in
    process stream
end

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