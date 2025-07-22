open Cmdliner
open Sx

type config = {
  input_file : string option;
  output_file : string option;
  input_format : Ast.input_format;
  output_format : Ast.output_format;
  formatting : Ast.formatting;
}

let input_format_of_string = function
  | "auto" -> Ok Ast.Auto
  | "json" -> Ok Ast.JSON
  | "yaml" -> Ok Ast.YAML
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
  let doc = "Input format. Supported: auto (default), json, yaml. Auto-detection based on file extension." in
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

let config_term =
  let combine input_file output_file input_format output_format _pretty compact =
    let formatting = 
      if compact then Ast.Compact else Ast.Pretty
    in
    { input_file; output_file; input_format; output_format; formatting }
  in
  Term.(const combine $ input_file $ output_file $ input_format $ output_format $ pretty $ compact)

let info =
  let doc = "Convert between JSON, YAML and various S-expression formats" in
  let man = [
    `S Manpage.s_description;
    `P "$(tname) convert structured data (JSON, YAML, TOML) into Common Lisp / Scheme-style S-expressions.";
    `P "The tool supports reading from stdin and writing to stdout, making it suitable for UNIX pipelines.";
    `S Manpage.s_examples;
    `P "Convert JSON file to Common Lisp S-expressions:";
    `Pre "  $(tname) input.json";
    `P "Convert JSON to Scheme format with compact output:";
    `Pre "  $(tname) --to scheme --compact input.json";
    `P "Use with pipes:";
    `Pre "  cat data.json | $(tname) --to scheme > output.scm";
    `P "Convert and save to file:";
    `Pre "  $(tname) input.json output.lisp";
  ] in
  let exits = [
    Cmd.Exit.info ~doc:"on success" 0;
    Cmd.Exit.info ~doc:"on argument parsing errors" 1;
    Cmd.Exit.info ~doc:"on input/output errors" 2;
  ] in
  Cmd.info "sx" ~version:"0.0.0.1" ~doc ~exits ~man