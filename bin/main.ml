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
  | Ast.TOML -> Ast.TOML
  | Ast.JSONLines -> Ast.JSONLines
  | Ast.Auto -> 
      (* streaming mode favors json lines detection for better performance *)
      if config.streaming && Cli.Io.is_jsonlines_format content then
        Ast.JSONLines
      else
        Parsers.Detect.detect_format ~filename_opt:filename ~content

let parse_input format filename content =
  let fname = Option.value filename ~default:"<stdin>" in
  match format with
  | Ast.JSON -> Parsers.Json.parse_string ~filename:fname content
  | Ast.YAML -> Parsers.Yaml_parser.parse_string ~filename:fname content
  | Ast.TOML -> Parsers.Toml.parse_string ~filename:fname content
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

(* decide whether to use streaming based on format and content size *)
let should_use_streaming (config : Cli.Args.config) input_format content =
  config.streaming || 
  (match input_format with
   | Ast.JSONLines -> true
   | Ast.JSON when Cli.Io.is_large_json_array content -> true
   | _ -> false)

let apply_config_to_cli_args (config : Config.config) (cli_config : Cli.Args.config) =
  (* only apply config defaults when CLI args are at their default values *)
  (* check if the user explicitly set cli flags vs using defaults *)
  let formatting = 
    if cli_config.formatting = Ast.Pretty && not config.pretty_print then
      Ast.Compact
    else
      cli_config.formatting
  in
  let output_format = 
    cli_config.output_format
  in
  let buffer_size = 
    if cli_config.buffer_size = 8192 then
      config.streaming.buffer_size
    else
      cli_config.buffer_size
  in
  { cli_config with 
    output_format; 
    formatting; 
    buffer_size }

let load_and_apply_config (cli_config : Cli.Args.config) =
  match Config.load_config ?custom_config:cli_config.config_file ~ignore_config:cli_config.no_config () with
  | Ok config -> 
      let merged_config = apply_config_to_cli_args config cli_config in
      (merged_config, None)
  | Error config_error ->
      (cli_config, Some config_error)

let validate_single_file (config : Cli.Args.config) filename =
  try
    let content = read_input (Some filename) in
    let input_format = detect_input_format config (Some filename) content in
    let _ = parse_input input_format (Some filename) content in (* parse to validate syntax only *)
    Error.create_validation_result ~filename ~success:true ()
  with
  | Error.Sx_error error ->
      Error.create_validation_result ~filename ~success:false ~error ()
  | exn ->
      let pos = Position.make ~filename ~line:1 ~column:1 in
      let error = Error.make_error 
        ~kind:(Error.ParseError ("Validation failed: " ^ Printexc.to_string exn))
        ~position:pos () in
      Error.create_validation_result ~filename ~success:false ~error ()

let process_single_file_normal (config : Cli.Args.config) filename =
  if config.streaming && config.input_file = None then
    let input_format = match config.input_format with
      | Ast.Auto -> Ast.JSONLines
      | other -> other
    in
    run_streaming config input_format
  else
    let content = read_input (Some filename) in
    let input_format = detect_input_format config (Some filename) content in
    
    if should_use_streaming config input_format content then
      run_streaming config input_format
    else
      let ast = parse_input input_format (Some filename) content in
      let output = generate_output config ast in
      write_output (output ^ "\n") config.output_file;
      0

let get_input_files (config : Cli.Args.config) =
  (* priority: input_files (multiple) > input_file (single) > stdin *)
  match config.input_files with
  | [] ->
      (match config.input_file with
       | None -> ["-"]
       | Some file -> [file])
  | files -> files

let run (cli_config : Cli.Args.config) =
  try
    let (config, config_error_opt) = load_and_apply_config cli_config in
    
    (match config_error_opt with
     | Some error -> 
         if not config.quiet then (
           Printf.eprintf "Warning: Configuration error: %s\n" (Error.format_error error);
           flush stderr
         )
     | None -> ());
    
    let input_files = get_input_files config in
    
    if config.validate then
      let (valid_files, file_errors) = Cli.Io.validate_input_files input_files in
      
      List.iter (fun (_file, error) ->
        if not config.quiet then
          match error with
          | `File_not_found path -> Printf.eprintf "Error: File not found: %s\n" path
          | `Permission_denied path -> Printf.eprintf "Error: Permission denied: %s\n" path
          | `Is_directory path -> Printf.eprintf "Error: Is a directory: %s\n" path
          | `Broken_symlink path -> Printf.eprintf "Error: Broken symbolic link: %s\n" path
          | `Unsupported_file_type path -> Printf.eprintf "Error: Unsupported file type: %s\n" path
      ) file_errors;
      
      let summary = ref (Error.create_empty_summary ()) in
      let continue_processing = ref true in
      
      List.iter (fun filename ->
        if !continue_processing then (
          let result = validate_single_file config filename in
          summary := Error.add_result_to_summary !summary result;
          Error.print_validation_result ~quiet:config.quiet ~verbose:config.verbose result;
          if config.fail_fast && not result.success then
            continue_processing := false
        )
      ) valid_files;
      
      Error.print_validation_summary ~quiet:config.quiet !summary;
      Error.validation_exit_code !summary
    else
      match input_files with
      | [single_file] ->
          if single_file = "-" then
            if config.streaming && config.input_file = None then
              let input_format = match config.input_format with
                | Ast.Auto -> Ast.JSONLines
                | other -> other
              in
              run_streaming config input_format
            else
              let content = read_input None in
              let input_format = detect_input_format config None content in
              
              if should_use_streaming config input_format content then
                run_streaming config input_format
              else
                let ast = parse_input input_format None content in
                let output = generate_output config ast in
                write_output (output ^ "\n") config.output_file;
                0
          else
            process_single_file_normal config single_file
      | _ ->
          Printf.eprintf "Error: Multiple files only supported in validation mode (use --validate)\n";
          2
  with
  | Error.Sx_error error ->
      if not cli_config.quiet then Error.print_error error;
      2
  | Sys_error msg ->
      if not cli_config.quiet then Printf.eprintf "IO Error: %s\n" msg;
      2
  | exn ->
      if not cli_config.quiet then Printf.eprintf "Unexpected error: %s\n" (Printexc.to_string exn);
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