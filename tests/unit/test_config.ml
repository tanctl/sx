open Alcotest
open Sx

let test_default_config () =
  let config = Config.default_config in
  check (module struct type t = Config.output_format let equal = (=) let pp fmt = function 
    | Config.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
    | Config.Scheme -> Format.pp_print_string fmt "Scheme" end) 
    "default output" Config.Common_lisp config.default_output;
  check bool "default pretty print" true config.pretty_print;
  check int "default buffer size" 8192 config.streaming.buffer_size

let test_config_parsing () =
  let content = {|
default_output = "scheme"
pretty_print = false
colors = "auto"

[streaming]
buffer_size = 4096
auto_enable = true
|} in
  match Config.parse_config_content content "test.config" with
  | Ok config ->
      check (module struct type t = Config.output_format let equal = (=) let pp fmt = function 
        | Config.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
        | Config.Scheme -> Format.pp_print_string fmt "Scheme" end) 
        "parsed output format" Config.Scheme config.default_output;
      check bool "parsed pretty print" false config.pretty_print;
      check int "parsed buffer size" 4096 config.streaming.buffer_size;
      check bool "parsed auto enable" true config.streaming.auto_enable
  | Error _ -> fail "config parsing should succeed"

let test_invalid_config () =
  let content = {|
invalid_key = "invalid"
default_output = "invalid_format"
|} in
  match Config.parse_config_content content "test.config" with
  | Ok config ->
      (* Should parse successfully but ignore invalid keys *)
      check (module struct type t = Config.output_format let equal = (=) let pp fmt = function 
        | Config.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
        | Config.Scheme -> Format.pp_print_string fmt "Scheme" end) 
        "should keep default" Config.Common_lisp config.default_output
  | Error _ -> fail "should not fail on unknown keys"

let test_config_file_not_found () =
  match Config.load_config ~custom_config:"nonexistent.config" () with
  | Ok config ->
      (* Should return default config when file doesn't exist *)
      check (module struct type t = Config.output_format let equal = (=) let pp fmt = function 
        | Config.Common_lisp -> Format.pp_print_string fmt "Common_lisp"
        | Config.Scheme -> Format.pp_print_string fmt "Scheme" end) 
        "should be default" Config.Common_lisp config.default_output
  | Error _ -> fail "should return default config for missing file"

let () =
  run "Config" [
    "Default Config", [
      test_case "default values" `Quick test_default_config;
    ];
    "Config Parsing", [
      test_case "valid config" `Quick test_config_parsing;
      test_case "invalid keys" `Quick test_invalid_config;
    ];
    "Config Loading", [
      test_case "missing file" `Quick test_config_file_not_found;
    ];
  ]