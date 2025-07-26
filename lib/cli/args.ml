open Cmdliner
open Sx

type config = {
  input_file : string option;
  output_file : string option;
  input_format : Ast.input_format;
  output_format : Ast.output_format;
  formatting : Ast.formatting;
  streaming : bool;
  buffer_size : int;
  show_progress : bool;
  config_file : string option;
  no_config : bool;
  validate : bool;
  fail_fast : bool;
  quiet : bool;
  verbose : bool;
  input_files : string list;
}

let input_format_of_string = function
  | "auto" -> Ok Ast.Auto
  | "json" -> Ok Ast.JSON
  | "yaml" -> Ok Ast.YAML
  | "toml" -> Ok Ast.TOML
  | "jsonl" | "jsonlines" -> Ok Ast.JSONLines
  | s -> Error (`Msg ("Invalid input format: " ^ s))

let output_format_of_string = function
  | "common-lisp" | "commonlisp" | "cl" -> Ok Ast.Common_lisp
  | "scheme" | "scm" -> Ok Ast.Scheme
  | s -> Error (`Msg ("Invalid output format: " ^ s))

let input_format_conv = 
  let parser s = input_format_of_string s in
  let printer fmt = function
    | Ast.Auto -> Format.fprintf fmt "auto"
    | Ast.JSON -> Format.fprintf fmt "json"
    | Ast.YAML -> Format.fprintf fmt "yaml"
    | Ast.TOML -> Format.fprintf fmt "toml"
    | Ast.JSONLines -> Format.fprintf fmt "jsonl"
  in
  Arg.conv (parser, printer)

let output_format_conv =
  let parser s = output_format_of_string s in
  let printer fmt = function
    | Ast.Common_lisp -> Format.fprintf fmt "common-lisp"
    | Ast.Scheme -> Format.fprintf fmt "scheme"
  in
  Arg.conv (parser, printer)

let input_file =
  let doc = "Input file to convert. Use '-' or omit for stdin." in
  Arg.(value & pos 0 (some string) None & info [] ~docv:"FILE" ~doc)

let output_file =
  let doc = "Output file. Use '-' or omit for stdout." in
  Arg.(value & pos 1 (some string) None & info [] ~docv:"OUTPUT" ~doc)

let input_format =
  let doc = "Input format. Supported: auto (default), json, yaml, toml, jsonl. Auto-detection based on file extension and content." in
  Arg.(value & opt input_format_conv Ast.Auto & info ["f"; "from"] ~docv:"FORMAT" ~doc)

let output_format =
  let doc = "Output format. Supported: common-lisp (default), scheme." in
  Arg.(value & opt output_format_conv Ast.Common_lisp & info ["t"; "to"] ~docv:"FORMAT" ~doc)

let pretty =
  let doc = "Pretty-print output with indentation (default)." in
  Arg.(value & flag & info ["p"; "pretty"] ~doc)

let compact =
  let doc = "Compact output on single line." in
  Arg.(value & flag & info ["c"; "compact"] ~doc)

let streaming =
  let doc = "Enable streaming mode for large JSON arrays or JSON Lines files." in
  Arg.(value & flag & info ["s"; "streaming"] ~doc)

let buffer_size =
  let doc = "Buffer size for streaming I/O in bytes (default: 8192)." in
  Arg.(value & opt int 8192 & info ["buffer-size"] ~docv:"SIZE" ~doc)

let show_progress =
  let doc = "Show progress information when processing large files in streaming mode." in
  Arg.(value & flag & info ["progress"] ~doc)

let config_file =
  let doc = "Path to custom configuration file." in
  Arg.(value & opt (some string) None & info ["config"] ~docv:"FILE" ~doc)

let no_config =
  let doc = "Ignore all configuration files and use defaults." in
  Arg.(value & flag & info ["no-config"] ~doc)

let validate =
  let doc = "Validate syntax without converting. Exit 0 if valid, 1 if syntax errors." in
  Arg.(value & flag & info ["validate"; "dry-run"] ~doc)

let fail_fast =
  let doc = "Stop processing on first error when handling multiple files." in
  Arg.(value & flag & info ["fail-fast"] ~doc)

let quiet =
  let doc = "Quiet mode - minimal output, just exit codes." in
  Arg.(value & flag & info ["q"; "quiet"] ~doc)

let verbose =
  let doc = "Verbose mode - detailed error reporting and progress information." in
  Arg.(value & flag & info ["v"; "verbose"] ~doc)

let input_files =
  let doc = "Input files to process. Can specify multiple files for batch processing." in
  Arg.(value & pos_all string [] & info [] ~docv:"FILES" ~doc)

let config_term =
  let combine input_file output_file input_format output_format _ compact streaming buffer_size show_progress config_file no_config validate fail_fast quiet verbose input_files =
    let formatting = 
      if compact then Ast.Compact else Ast.Pretty
    in
    { input_file; output_file; input_format; output_format; formatting; streaming; buffer_size; show_progress; config_file; no_config; validate; fail_fast; quiet; verbose; input_files }
  in
  Term.(const combine $ input_file $ output_file $ input_format $ output_format $ pretty $ compact $ streaming $ buffer_size $ show_progress $ config_file $ no_config $ validate $ fail_fast $ quiet $ verbose $ input_files)

let info =
  let doc = "Fast, streaming S-expression converter for JSON, YAML, and TOML" in
  let man = [
    `S Manpage.s_description;
    `P "sx converts structured data from JSON, YAML, and TOML into Common Lisp or Scheme S-expressions.";
    `P "Features automatic format detection, streaming processing for large files, batch validation, and configurable output formatting.";
    `P "Supports both traditional file processing and streaming workflows with constant memory usage.";
    `S Manpage.s_examples;
    `P "Basic conversion:";
    `Pre "  sx data.json";
    `Pre "  echo '{\"key\": \"value\"}' | sx";
    `P "Format-specific conversion:";
    `Pre "  sx --from yaml --to scheme config.yml";
    `Pre "  sx --from toml settings.toml";
    `P "Streaming large files:";
    `Pre "  sx --streaming large-dataset.jsonl";
    `Pre "  sx --streaming --progress huge-array.json";
    `P "Batch validation:";
    `Pre "  sx --validate config/*.toml data/*.json";
    `Pre "  sx --validate --fail-fast --quiet *.yaml";
    `P "Configuration:";
    `Pre "  sx --config custom.config data.json";
    `Pre "  sx --no-config --compact input.yaml";
  ] in
  let exits = [
    Cmd.Exit.info ~doc:"on success" 0;
    Cmd.Exit.info ~doc:"on validation errors or invalid syntax" 1;
    Cmd.Exit.info ~doc:"on file I/O errors or system failures" 2;
  ] in
  Cmd.info "sx" ~version:"0.0.0.1" ~doc ~exits ~man