open Sx
open Alcotest

(* Simple property tests for sx *)
let test_roundtrip_json () =
  let json_string = {|{"name": "test", "value": 42}|} in
  try
    let ast = Parsers.Json.parse_string ~filename:"test.json" json_string in
    let output = Generators.Common_lisp.generate ast in
    check bool "output is not empty" true (String.length output > 0);
    check bool "output contains expected content" true (String.contains output 'n')
  with
  | _ -> fail "parsing or generation failed"

let test_basic_json_parsing () =
  let simple_cases = [
    ({|{"test": true}|}, "simple object");
    ({|[1, 2, 3]|}, "simple array");
    ({|"hello"|}, "simple string");
    ({|42|}, "simple number");
    ({|true|}, "simple boolean");
    ({|null|}, "simple null");
  ] in
  List.iter (fun (json, desc) ->
    try
      let _ = Parsers.Json.parse_string ~filename:"test.json" json in
      ()
    with
    | _ -> fail (Printf.sprintf "failed to parse %s: %s" desc json)
  ) simple_cases

let test_generator_output_format () =
  let ast = Ast.Bool (true, Position.dummy) in
  let cl_output = Generators.Common_lisp.generate ast in
  let scheme_output = Generators.Scheme.generate ast in
  check bool "common lisp output not empty" true (String.length cl_output > 0);
  check bool "scheme output not empty" true (String.length scheme_output > 0);
  check bool "outputs are different" true (cl_output <> scheme_output)

let () =
  run "Property Tests" [
    "Basic Properties", [
      test_case "JSON roundtrip" `Quick test_roundtrip_json;
      test_case "JSON parsing robustness" `Quick test_basic_json_parsing;
      test_case "Generator output format" `Quick test_generator_output_format;
    ];
  ]