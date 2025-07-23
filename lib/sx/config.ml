
type color_mode = Auto | Always | Never

type streaming_config = {
  buffer_size : int;
  auto_enable : bool;
}

type output_format = Common_lisp | Scheme

type config = {
  default_output : output_format;
  pretty_print : bool;
  colors : color_mode;
  streaming : streaming_config;
}

let default_config = {
  default_output = Common_lisp;
  pretty_print = true;
  colors = Auto;
  streaming = {
    buffer_size = 8192;
    auto_enable = true;
  };
}

let color_mode_of_string = function
  | "auto" -> Some Auto
  | "always" -> Some Always
  | "never" -> Some Never
  | _ -> None

let output_format_of_string = function
  | "common-lisp" | "commonlisp" | "cl" -> Some Common_lisp
  | "scheme" | "scm" -> Some Scheme
  | _ -> None

let string_of_color_mode = function
  | Auto -> "auto"
  | Always -> "always"
  | Never -> "never"

let string_of_output_format = function
  | Common_lisp -> "common-lisp"
  | Scheme -> "scheme"

let get_home_dir () =
  try Some (Sys.getenv "HOME")
  with Not_found -> None

let get_config_paths custom_config =
  let paths = match custom_config with
    | Some path -> [path]
    | None -> 
        let local_config = "./sx.config" in
        let home_config = match get_home_dir () with
          | Some home -> Some (Filename.concat home ".sx.config")
          | None -> None
        in
        (* filter out None values to get valid config paths *)
        List.filter_map (fun x -> x) [Some local_config; home_config]
  in
  List.filter Sys.file_exists paths


let parse_toml_value key value =
  try
    match key, value with
    | "default_output", s ->
        (match output_format_of_string s with
         | Some fmt -> Some (`Output_format fmt)
         | None -> None)
    | "pretty_print", "true" -> Some (`Pretty_print true)
    | "pretty_print", "false" -> Some (`Pretty_print false)
    | "colors", s ->
        (match color_mode_of_string s with
         | Some mode -> Some (`Colors mode)
         | None -> None)
    | _ -> None
  with _ -> None

let parse_streaming_section lines =
  let buffer_size = ref default_config.streaming.buffer_size in
  let auto_enable = ref default_config.streaming.auto_enable in
  
  List.iter (fun line ->
    let trimmed = String.trim line in
    if String.contains trimmed '=' then
      let parts = String.split_on_char '=' trimmed in
      match parts with
      | [key; value] ->
          let clean_key = String.trim key in
          let clean_value = String.trim value in
          (match clean_key with
           | "buffer_size" ->
               (try buffer_size := int_of_string clean_value
                with _ -> ())
           | "auto_enable" when clean_value = "true" -> auto_enable := true
           | "auto_enable" when clean_value = "false" -> auto_enable := false
           | _ -> ())
      | _ -> ()
  ) lines;
  
  { buffer_size = !buffer_size; auto_enable = !auto_enable }

let parse_config_content content filename =
  try
    let lines = String.split_on_char '\n' content in
    let config = ref default_config in
    let in_streaming_section = ref false in
    let streaming_lines = ref [] in
    
    let process_line line =
      let trimmed = String.trim line in
      if trimmed = "" || (String.length trimmed > 0 && String.get trimmed 0 = '#') then
        ()
      else if trimmed = "[streaming]" then (
        in_streaming_section := true
      ) else if String.length trimmed > 0 && String.get trimmed 0 = '[' then (
        if !in_streaming_section && !streaming_lines <> [] then (
          let streaming_config = parse_streaming_section (List.rev !streaming_lines) in
          config := { !config with streaming = streaming_config };
          streaming_lines := []
        );
        in_streaming_section := false
      ) else if !in_streaming_section then (
        streaming_lines := line :: !streaming_lines
      ) else if String.contains trimmed '=' then (
        let parts = String.split_on_char '=' trimmed in
        match parts with
        | [key; value] ->
            let clean_key = String.trim key in
            let clean_value = String.trim value in
            (* strip surrounding quotes from config values *)
            let clean_value = 
              if String.length clean_value >= 2 && 
                 String.get clean_value 0 = '"' && 
                 String.get clean_value (String.length clean_value - 1) = '"' then
                String.sub clean_value 1 (String.length clean_value - 2)
              else
                clean_value
            in
            (match parse_toml_value clean_key clean_value with
             | Some (`Output_format fmt) -> config := { !config with default_output = fmt }
             | Some (`Pretty_print b) -> config := { !config with pretty_print = b }
             | Some (`Colors mode) -> config := { !config with colors = mode }
             | None -> ())
        | _ -> ()
      )
    in
    
    List.iter process_line lines;
    
    if !in_streaming_section && !streaming_lines <> [] then (
      let streaming_config = parse_streaming_section (List.rev !streaming_lines) in
      config := { !config with streaming = streaming_config }
    );
    
    Ok !config
  with
  | exn ->
      let pos = Position.make ~filename ~line:1 ~column:1 in
      let error = Error.make_error 
        ~kind:(Error.ParseError ("Configuration parsing failed: " ^ Printexc.to_string exn)) 
        ~position:pos 
        ~source_context:content () in
      Error (error)

let load_config_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_config_content content filename
  with
  | Sys_error _ -> Ok default_config

let load_config ?custom_config ?(ignore_config=false) () =
  if ignore_config then Ok default_config
  else
    let config_paths = get_config_paths custom_config in
    match config_paths with
    | [] -> Ok default_config
    | path :: _ -> load_config_file path

let convert_output_format = function
  | Common_lisp -> Ast.Common_lisp
  | Scheme -> Ast.Scheme

let apply_config_to_cli_args _config cli_args =
  cli_args

let should_use_colors config =
  match config.colors with
  | Always -> true
  | Never -> false
  | Auto -> true (* assume color support in auto mode *)

let create_sample_config () =
  let sample = {|# sx configuration file
# Output format: "common-lisp" or "scheme"
default_output = "common-lisp"

# Pretty print output by default
pretty_print = true

# Color output: "auto", "always", or "never"
colors = "auto"

[streaming]
# Buffer size for streaming operations (bytes)
buffer_size = 8192

# Automatically enable streaming for large files
auto_enable = true
|} in
  sample