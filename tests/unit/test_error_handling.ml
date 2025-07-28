open Alcotest
open Sx

let test_position_creation () =
  let pos = Position.make ~filename:"test.json" ~line:5 ~column:10 in
  check string "filename" "test.json" pos.filename;
  check int "line" 5 pos.line;
  check int "column" 10 pos.column

let test_error_creation () =
  let pos = Position.make ~filename:"test.json" ~line:1 ~column:1 in
  let error = Error.make_error ~kind:(Error.ParseError "test error") ~position:pos () in
  check string "error message" "test error" (Error.error_message error.kind)

let test_validation_result () =
  let result = Error.create_validation_result ~filename:"test.json" ~success:true () in
  check string "filename" "test.json" result.filename;
  check bool "success" true result.success;
  check int "warning count" 0 result.warning_count

let test_validation_summary () =
  let summary = Error.create_empty_summary () in
  check int "initial files processed" 0 summary.files_processed;
  check int "initial valid files" 0 summary.files_valid;
  
  let result = Error.create_validation_result ~filename:"test.json" ~success:true () in
  let updated_summary = Error.add_result_to_summary summary result in
  check int "updated files processed" 1 updated_summary.files_processed;
  check int "updated valid files" 1 updated_summary.files_valid

let test_validation_exit_code () =
  let summary_success = Error.create_empty_summary () in
  check int "success exit code" 0 (Error.validation_exit_code summary_success);
  
  let empty = Error.create_empty_summary () in
  let summary_with_errors = { empty with files_with_errors = 1 } in
  check int "error exit code" 1 (Error.validation_exit_code summary_with_errors)

let test_error_formatting () =
  let pos = Position.make ~filename:"test.json" ~line:1 ~column:5 in
  let error = Error.make_error ~kind:(Error.ParseError "missing comma") ~position:pos () in
  let formatted = Error.format_error error in
  check bool "contains filename" true (String.contains formatted 't');
  check bool "contains error message" true (String.contains formatted 'c')

let () =
  run "Error Handling" [
    "Position", [
      test_case "position creation" `Quick test_position_creation;
    ];
    "Errors", [
      test_case "error creation" `Quick test_error_creation;
      test_case "error formatting" `Quick test_error_formatting;
    ];
    "Validation", [
      test_case "validation result" `Quick test_validation_result;
      test_case "validation summary" `Quick test_validation_summary;
      test_case "exit codes" `Quick test_validation_exit_code;
    ];
  ]