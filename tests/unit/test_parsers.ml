open Alcotest
open Sx

let test_json_simple () =
  let content = {|{"name": "test", "value": 42, "enabled": true}|} in
  let result = Parsers.Json.parse_string ~filename:"test.json" content in
  match result with
  | Ast.Assoc (pairs, _) ->
      check int "should have 3 pairs" 3 (List.length pairs);
      let name_val = List.assoc "name" pairs in
      (match name_val with
       | Ast.String (s, _) -> check string "name value" "test" s
       | _ -> fail "expected string");
      let value_val = List.assoc "value" pairs in
      (match value_val with
       | Ast.Int (i, _) -> check int "value" 42 i
       | _ -> fail "expected int")
  | _ -> fail "expected assoc"

let test_json_array () =
  let content = {|[1, 2, 3]|} in
  let result = Parsers.Json.parse_string ~filename:"test.json" content in
  match result with
  | Ast.List (items, _) -> 
      check int "array length" 3 (List.length items)
  | _ -> fail "expected list"

let test_json_invalid () =
  let content = {|{"name": "test", "value": 42|} in
  try
    let _ = Parsers.Json.parse_string ~filename:"test.json" content in
    fail "Should have raised an exception"
  with
  | Error.Sx_error _ -> ()
  | _ -> fail "Should have raised Sx_error"

let test_yaml_simple () =
  let content = {|
name: test
value: 42
enabled: true
|} in
  let result = Parsers.Yaml_parser.parse_string ~filename:"test.yaml" content in
  match result with
  | Ast.Assoc (pairs, _) ->
      check int "should have 3 pairs" 3 (List.length pairs)
  | _ -> fail "expected assoc"

let test_yaml_nested () =
  let content = {|
database:
  host: localhost
  port: 5432
features:
  - auth
  - logging
|} in
  let result = Parsers.Yaml_parser.parse_string ~filename:"test.yaml" content in
  match result with
  | Ast.Assoc (pairs, _) ->
      let db = List.assoc "database" pairs in
      (match db with
       | Ast.Assoc (db_pairs, _) ->
           check int "database pairs" 2 (List.length db_pairs)
       | _ -> fail "expected nested assoc")
  | _ -> fail "expected assoc"

let test_toml_simple () =
  let content = {|
name = "test"
value = 42
enabled = true
|} in
  let result = Parsers.Toml.parse_string ~filename:"test.toml" content in
  match result with
  | Ast.Assoc (pairs, _) ->
      check int "should have 3 pairs" 3 (List.length pairs);
      let name_val = List.assoc "name" pairs in
      (match name_val with
       | Ast.String (s, _) -> check string "name value" "test" s
       | _ -> fail "expected string")
  | _ -> fail "expected assoc"

let test_toml_numbers () =
  let content = {|
integer = 42
float = 3.14
|} in
  let result = Parsers.Toml.parse_string ~filename:"test.toml" content in
  match result with
  | Ast.Assoc (pairs, _) ->
      let int_val = List.assoc "integer" pairs in
      (match int_val with
       | Ast.Int (i, _) -> check int "integer value" 42 i
       | _ -> fail "expected int");
      let float_val = List.assoc "float" pairs in
      (match float_val with
       | Ast.Float (f, _) -> check (float 0.01) "float value" 3.14 f
       | _ -> fail "expected float")
  | _ -> fail "expected assoc"

let test_format_detection () =
  let json_content = {|{"test": true}|} in
  let yaml_content = {|test: true|} in
  let _toml_content = {|test = true|} in
  
  let json_format = Parsers.Detect.detect_format ~filename_opt:(Some "test.json") ~content:json_content in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML" 
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) "detect JSON" Ast.JSON json_format;
    
  let yaml_format = Parsers.Detect.detect_format ~filename_opt:(Some "test.yaml") ~content:yaml_content in
  check (module struct type t = Ast.input_format let equal = (=) let pp fmt = function 
    | Ast.JSON -> Format.pp_print_string fmt "JSON"
    | Ast.YAML -> Format.pp_print_string fmt "YAML" 
    | Ast.TOML -> Format.pp_print_string fmt "TOML"
    | _ -> Format.pp_print_string fmt "Other" end) "detect YAML" Ast.YAML yaml_format

let () =
  run "Parsers" [
    "JSON", [
      test_case "simple JSON" `Quick test_json_simple;
      test_case "JSON array" `Quick test_json_array;
      test_case "invalid JSON" `Quick test_json_invalid;
    ];
    "YAML", [
      test_case "simple YAML" `Quick test_yaml_simple;
      test_case "nested YAML" `Quick test_yaml_nested;
    ];
    "TOML", [
      test_case "simple TOML" `Quick test_toml_simple;
      test_case "TOML numbers" `Quick test_toml_numbers;
    ];
    "Detection", [
      test_case "format detection" `Quick test_format_detection;
    ];
  ]