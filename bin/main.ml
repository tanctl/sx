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

let detect_input_format (config : Cli.Args.config) filename content =
  match config.input_format with
  | Ast.JSON -> Ast.JSON
  | Ast.YAML -> Ast.YAML
  | Ast.JSONLines -> Ast.JSONLines
  | Ast.Auto -> 
      if config.streaming && Cli.Io.is_jsonlines_format content then
        Ast.JSONLines
      else
        Parsers.Detect.detect_format ~filename_opt:filename ~content

let parse_input format filename content =
  let fname = Option.value filename ~default:"<stdin>" in
  match format with
  | Ast.JSON -> Parsers.Json.parse_string ~filename:fname content
  | Ast.YAML -> Parsers.Yaml_parser.parse_string ~filename:fname content
  | Ast.JSONLines -> 
      Error.unsupported_feature 
        ~message:"JSON Lines format requires streaming mode (use --streaming flag)"
        ~position:Position.dummy ()
  | Ast.Auto -> failwith "Auto format should be resolved before parsing"

let generate_output (config : Cli.Args.config) ast =
  match config.output_format with
  | Ast.Common_lisp -> Generators.Common_lisp.generate ~formatting:config.formatting ast
  | Ast.Scheme -> Generators.Scheme.generate ~formatting:config.formatting ast

let run_streaming (config : Cli.Args.config) input_format =
  let fname = Option.value config.input_file ~default:"<stdin>" in
  let stream_source = match config.input_file with
    | Some "-" | None -> Cli.Io.Stdin
    | Some filename -> Cli.Io.File filename
  in
  
  let channel = Cli.Io.open_input_stream stream_source in
  let progress_state = Cli.Io.create_progress_state () in
  let stream_config = { 
    Cli.Io.buffer_size = config.buffer_size;
    show_progress = config.show_progress;
    progress_interval = 1000;
  } in
  
  let output_channel = match config.output_file with
    | Some "-" | None -> stdout
    | Some filename -> open_out filename
  in
  
  try
    let stream = match input_format with
      | Ast.JSONLines -> Parsers.Json.Stream.parse_jsonlines_stream ~filename:fname channel
      | Ast.JSON -> Parsers.Json.Stream.parse_json_array_stream ~filename:fname channel
      | _ -> failwith "Unsupported streaming format"
    in
    
    let on_item ast =
      let sexp_output = generate_output config ast in
      output_string output_channel (sexp_output ^ "\n");
      flush output_channel;
      Cli.Io.update_progress stream_config progress_state
    in
    
    let on_error error_msg =
      Printf.eprintf "Stream error: %s\n" error_msg;
      flush stderr
    in
    
    let on_complete () =
      Cli.Io.finish_progress stream_config progress_state
    in
    
    Parsers.Json.Stream.process_stream ~on_item ~on_error ~on_complete stream;
    
    (if output_channel <> stdout then close_out output_channel);
    Cli.Io.close_input_stream channel stream_source;
    0
  with
  | exn ->
      (if output_channel <> stdout then close_out output_channel);
      Cli.Io.close_input_stream channel stream_source;
      raise exn

let should_use_streaming (config : Cli.Args.config) input_format content =
  config.streaming || 
  (match input_format with
   | Ast.JSONLines -> true
   | Ast.JSON when Cli.Io.is_large_json_array content -> true
   | _ -> false)

let run (config : Cli.Args.config) =
  try
    if config.streaming && config.input_file = None then
      (* determine format differently for streaming from stdin*)
      let input_format = match config.input_format with
        | Ast.Auto -> Ast.JSONLines
        | other -> other
      in
      run_streaming config input_format
    else
      let content = read_input config.input_file in
      let input_format = detect_input_format config config.input_file content in
      
      if should_use_streaming config input_format content then
        run_streaming config input_format
      else
        let ast = parse_input input_format config.input_file content in
        let output = generate_output config ast in
        write_output (output ^ "\n") config.output_file;
        0
  with
  | Error.Sx_error error ->
      Error.print_error error;
      2
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