open Sx
open Cmdliner

let read_input = function
  | Some "-" | None -> 
      let buffer = Buffer.create 1024 in
      (try
         while true do
           Buffer.add_char buffer (input_char stdin)
         done
       with End_of_file -> ());
      Buffer.contents buffer
  | Some filename ->
      let ic = open_in filename in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      content

let write_output content = function
  | Some "-" | None -> print_string content
  | Some filename ->
      let oc = open_out filename in
      output_string oc content;
      close_out oc

let detect_input_format (config : Cli.Args.config) filename _content =
  match config.input_format with
  | Ast.JSON -> Ast.JSON
  | Ast.Auto ->
      match filename with
      | Some name when String.ends_with ~suffix:".json" name -> Ast.JSON
      | _ -> Ast.JSON

let parse_input format filename content =
  match format with
  | Ast.JSON -> Parsers.Json.parse_string ~filename:(Option.value filename ~default:"<stdin>") content
  | Ast.Auto -> failwith "Auto format should be resolved before parsing"

let generate_output (config : Cli.Args.config) ast =
  match config.output_format with
  | Ast.Common_lisp -> Generators.Common_lisp.generate ~formatting:config.formatting ast
  | Ast.Scheme -> Generators.Scheme.generate ~formatting:config.formatting ast

let run (config : Cli.Args.config) =
  try
    let content = read_input config.input_file in
    let input_format = detect_input_format config config.input_file content in
    match parse_input input_format config.input_file content with
    | Ok ast ->
        let output = generate_output config ast in
        write_output (output ^ "\n") config.output_file;
        0
    | Error error ->
        Printf.eprintf "Error: %s at %s\n" 
          error.message 
          (Position.to_string error.position);
        2
  with
  | Sys_error msg ->
      Printf.eprintf "IO Error: %s\n" msg;
      2
  | exn ->
      Printf.eprintf "Unexpected error: %s\n" (Printexc.to_string exn);
      2

let () = 
  let cmd = Cmd.v Cli.Args.info (Term.(ret (const (fun config -> 
    try
      match run config with
      | 0 -> `Ok ()
      | n -> `Error (false, Printf.sprintf "Command failed with exit code %d" n)
    with
    | Failure msg -> `Error (true, msg)
    | exn -> `Error (false, Printf.sprintf "Unexpected error: %s" (Printexc.to_string exn))
  ) $ Cli.Args.config_term))) in
  exit (Cmd.eval cmd)