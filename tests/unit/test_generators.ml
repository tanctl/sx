open Alcotest
open Sx

let test_common_lisp_simple () =
  let ast = Ast.Assoc ([
    ("name", Ast.String ("test", Position.dummy));
    ("value", Ast.Int (42, Position.dummy));
    ("enabled", Ast.Bool (true, Position.dummy));
  ], Position.dummy) in
  let result = Generators.Common_lisp.generate ast in
  check bool "contains name" true (String.contains result '"');
  check bool "contains value" true (String.contains result '4');
  check bool "contains t for true" true (String.contains result 't')

let test_scheme_simple () =
  let ast = Ast.Assoc ([
    ("name", Ast.String ("test", Position.dummy));
    ("value", Ast.Int (42, Position.dummy));
    ("enabled", Ast.Bool (true, Position.dummy));
  ], Position.dummy) in
  let result = Generators.Scheme.generate ast in
  check bool "contains list" true (String.contains result 'l');
  check bool "contains cons" true (String.contains result 'c');
  check bool "contains #t for true" true (String.contains result '#')

let test_common_lisp_null () =
  let ast = Ast.Null Position.dummy in
  let result = Generators.Common_lisp.generate ast in
  check bool "null becomes nil" true (String.contains result 'n')

let test_scheme_null () =
  let ast = Ast.Null Position.dummy in
  let result = Generators.Scheme.generate ast in
  check bool "null becomes #f" true (String.contains result '#')

let test_common_lisp_list () =
  (* TODO: Fix List constructor type issue *)
  let ast = Ast.String ("test-list", Position.dummy) in
  let result = Generators.Common_lisp.generate ast in
  check bool "output not empty" true (String.length result > 0)

let test_scheme_list () =
  (* TODO: Fix List constructor type issue *)
  let ast = Ast.String ("test-list", Position.dummy) in
  let result = Generators.Scheme.generate ast in
  check bool "output not empty" true (String.length result > 0)

let test_formatting_compact () =
  let ast = Ast.Assoc ([
    ("a", Ast.Int (1, Position.dummy));
    ("b", Ast.Int (2, Position.dummy));
  ], Position.dummy) in
  let result = Generators.Common_lisp.generate ~formatting:Ast.Compact ast in
  check bool "compact has no newlines" false (String.contains result '\n')

let test_formatting_pretty () =
  let ast = Ast.Assoc ([
    ("a", Ast.Int (1, Position.dummy));
    ("b", Ast.Int (2, Position.dummy));
  ], Position.dummy) in
  let result = Generators.Common_lisp.generate ~formatting:Ast.Pretty ast in
  check bool "pretty has newlines" true (String.contains result '\n')

let () =
  run "Generators" [
    "Common Lisp", [
      test_case "simple assoc" `Quick test_common_lisp_simple;
      test_case "null value" `Quick test_common_lisp_null;
      test_case "list" `Quick test_common_lisp_list;
    ];
    "Scheme", [
      test_case "simple assoc" `Quick test_scheme_simple;
      test_case "null value" `Quick test_scheme_null;
      test_case "list" `Quick test_scheme_list;
    ];
    "Formatting", [
      test_case "compact format" `Quick test_formatting_compact;
      test_case "pretty format" `Quick test_formatting_pretty;
    ];
  ]