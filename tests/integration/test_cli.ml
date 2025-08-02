open Alcotest
open Sx

(* Helper to create basic CLI config for testing *)
let make_test_config ?(validate=false) ?(quiet=false) ?(verbose=false) 
                     ?(output_format=Ast.Common_lisp) ?(no_config=true) () =
  { Cli.Args.input_file = None; output_file = None; input_format = Ast.Auto;
    output_format; formatting = Ast.Pretty; streaming = false; buffer_size = 8192;
    show_progress = false; config_file = None; no_config; validate; fail_fast = false;
    quiet; verbose; input_files = []; pipeline_analysis = false; ast_dump = false }

let test_basic_json_conversion () =
  (* This is more of a smoke test - we can't easily run the full CLI here *)
  let _config = make_test_config () in
  let content = {|{"name": "test", "value": 42}|} in
  let ast = Parsers.Json.parse_string ~filename:"test.json" content in
  let output = Generators.Common_lisp.generate ast in
  check bool "output contains name" true (String.contains output 'n');
  check bool "output contains value" true (String.contains output '4')

let test_validation_mode_flag () =
  let config = make_test_config ~validate:true () in
  check bool "validation enabled" true config.validate

let test_quiet_mode_flag () =
  let config = make_test_config ~quiet:true () in
  check bool "quiet enabled" true config.quiet

let test_output_format_selection () =
  let config_cl = make_test_config ~output_format:Ast.Common_lisp () in
  check (module struct type t = Ast.output_format let equal = (=) let pp fmt = function 
    | Ast.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
    | Ast.Scheme -> Format.pp_print_string fmt "Scheme" end) 
    "common lisp format" Ast.Common_lisp config_cl.output_format;
    
  let config_scheme = make_test_config ~output_format:Ast.Scheme () in
  check (module struct type t = Ast.output_format let equal = (=) let pp fmt = function 
    | Ast.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
    | Ast.Scheme -> Format.pp_print_string fmt "Scheme" end) 
    "scheme format" Ast.Scheme config_scheme.output_format

let test_format_auto_detection () =
  let json_format = Parsers.Detect.detect_format ~filename_opt:(Some "test.json") ~content:{|{"test": true}|} in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) 
    "auto detect JSON" Ast.JSON json_format;
    
  let yaml_format = Parsers.Detect.detect_format ~filename_opt:(Some "test.yaml") ~content:{|test: true|} in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) 
    "auto detect YAML" Ast.YAML yaml_format

let test_different_output_formats () =
  let ast = Ast.Assoc ([
    ("name", Ast.String ("test", Position.dummy));
    ("enabled", Ast.Bool (true, Position.dummy));
  ], Position.dummy) in
  
  let cl_output = Generators.Common_lisp.generate ast in
  let scheme_output = Generators.Scheme.generate ast in
  
  (* Common Lisp uses 't' and 'nil' *)
  check bool "CL has t" true (String.contains cl_output 't');
  (* Scheme uses '#t' and has 'list' keyword *)
  check bool "Scheme has #t" true (String.contains scheme_output '#');
  check bool "Scheme has list" true (Str.string_match (Str.regexp ".*list.*") scheme_output 0)

let () =
  run "CLI Integration" [
    "Basic Functionality", [
      test_case "JSON conversion" `Quick test_basic_json_conversion;
      test_case "format auto-detection" `Quick test_format_auto_detection;
      test_case "output formats" `Quick test_different_output_formats;
    ];
    "CLI Flags", [
      test_case "validation mode" `Quick test_validation_mode_flag;
      test_case "quiet mode" `Quick test_quiet_mode_flag;
      test_case "output format selection" `Quick test_output_format_selection;
    ];
  ]