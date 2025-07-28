open Alcotest
open Sx

let test_json_detection_by_extension () =
  let result = Parsers.Detect.detect_by_extension "config.json" in
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "JSON extension" (Some Ast.JSON) result

let test_yaml_detection_by_extension () =
  let yaml_result = Parsers.Detect.detect_by_extension "config.yaml" in
  let yml_result = Parsers.Detect.detect_by_extension "config.yml" in
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "YAML extension" (Some Ast.YAML) yaml_result;
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "YML extension" (Some Ast.YAML) yml_result

let test_toml_detection_by_extension () =
  let result = Parsers.Detect.detect_by_extension "config.toml" in
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "TOML extension" (Some Ast.TOML) result

let test_json_detection_by_content () =
  let json_object = {|{"test": true}|} in
  let json_array = {|[1, 2, 3]|} in
  let json_string = {|"hello"|} in
  
  let obj_result = Parsers.Detect.detect_by_content json_object in
  let arr_result = Parsers.Detect.detect_by_content json_array in
  let str_result = Parsers.Detect.detect_by_content json_string in
  
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "JSON object" (Some Ast.JSON) obj_result;
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "JSON array" (Some Ast.JSON) arr_result;
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "JSON string" (Some Ast.JSON) str_result

let test_yaml_detection_by_content () =
  let yaml_content = {|key: value
list:
  - item1
  - item2|} in
  let result = Parsers.Detect.detect_by_content yaml_content in
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "YAML content" (Some Ast.YAML) result

let test_toml_detection_by_content () =
  let toml_content = {|key = "value"
number = 42|} in
  let result = Parsers.Detect.detect_by_content toml_content in
  check (option (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end)) "TOML content" (Some Ast.TOML) result

let test_combined_detection () =
  (* Test the main detection function that combines extension and content *)
  let json_result = Parsers.Detect.detect_format ~filename_opt:(Some "test.json") ~content:{|{"test": true}|} in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) "combined JSON detection" Ast.JSON json_result;
    
  let yaml_result = Parsers.Detect.detect_format ~filename_opt:(Some "test.yaml") ~content:{|test: value|} in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) "combined YAML detection" Ast.YAML yaml_result

let test_fallback_to_content () =
  (* When filename doesn't give clues, should fall back to content detection *)
  let result = Parsers.Detect.detect_format ~filename_opt:(Some "unknown.txt") ~content:{|{"json": true}|} in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML"
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) "fallback to content" Ast.JSON result

let () =
  run "Auto Detection" [
    "Extension Detection", [
      test_case "JSON extension" `Quick test_json_detection_by_extension;
      test_case "YAML extensions" `Quick test_yaml_detection_by_extension;
      test_case "TOML extension" `Quick test_toml_detection_by_extension;
    ];
    "Content Detection", [
      test_case "JSON content" `Quick test_json_detection_by_content;
      test_case "YAML content" `Quick test_yaml_detection_by_content;
      test_case "TOML content" `Quick test_toml_detection_by_content;
    ];
    "Combined Detection", [
      test_case "combined detection" `Quick test_combined_detection;
      test_case "fallback to content" `Quick test_fallback_to_content;
    ];
  ]