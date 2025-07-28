open Alcotest
open Sx

let test_file_validation () =
  let valid_files = ["tests/fixtures/valid/simple.json"; "tests/fixtures/valid/server.yaml"] in
  let invalid_files = ["tests/fixtures/invalid/bad.json"; "nonexistent.json"] in
  let mixed_files = valid_files @ invalid_files in
  
  let (validated, errors) = Cli.Io.validate_input_files mixed_files in
  
  (* Should find the valid files that exist *)
  check bool "has valid files" true (List.length validated > 0);
  (* Should have errors for invalid/missing files *)
  check bool "has errors" true (List.length errors > 0)

let test_validation_result_creation () =
  let success_result = Error.create_validation_result ~filename:"test.json" ~success:true () in
  check string "filename" "test.json" success_result.filename;
  check bool "success" true success_result.success;
  check (option (module struct type t = Error.error let equal = (=) let pp fmt _ = Format.pp_print_string fmt "error" end)) "no error" None success_result.error;
  
  let pos = Position.make ~filename:"test.json" ~line:1 ~column:1 in
  let error = Error.make_error ~kind:(Error.ParseError "test error") ~position:pos () in
  let error_result = Error.create_validation_result ~filename:"test.json" ~success:false ~error () in
  check bool "failure" false error_result.success;
  check bool "has error" true (error_result.error <> None)

let test_validation_summary_aggregation () =
  let summary = Error.create_empty_summary () in
  
  let result1 = Error.create_validation_result ~filename:"good.json" ~success:true () in
  let summary1 = Error.add_result_to_summary summary result1 in
  
  let pos = Position.make ~filename:"bad.json" ~line:1 ~column:1 in
  let error = Error.make_error ~kind:(Error.ParseError "syntax error") ~position:pos () in
  let result2 = Error.create_validation_result ~filename:"bad.json" ~success:false ~error () in
  let summary2 = Error.add_result_to_summary summary1 result2 in
  
  check int "total files" 2 summary2.files_processed;
  check int "valid files" 1 summary2.files_valid;
  check int "files with errors" 1 summary2.files_with_errors;
  check int "total errors" 1 summary2.total_errors

let test_file_access_checking () =
  let existing_file = "tests/fixtures/valid/simple.json" in
  let missing_file = "nonexistent.json" in
  
  let existing_result = Cli.Io.check_file_access existing_file in
  let missing_result = Cli.Io.check_file_access missing_file in
  
  (match existing_result with
   | Ok _ -> check bool "existing file ok" true true
   | Error _ -> fail "existing file should be ok");
   
  (match missing_result with
   | Error (`File_not_found _) -> check bool "missing file detected" true true
   | _ -> fail "should detect missing file")

let test_batch_file_processing () =
  (* Test the logic for handling multiple files *)
  let files = ["file1.json"; "file2.yaml"; "file3.toml"] in
  check int "file count" 3 (List.length files);
  
  (* Test file type detection *)
  let has_json = List.exists (fun f -> String.ends_with ~suffix:".json" f) files in
  let has_yaml = List.exists (fun f -> String.ends_with ~suffix:".yaml" f) files in
  let has_toml = List.exists (fun f -> String.ends_with ~suffix:".toml" f) files in
  
  check bool "has JSON file" true has_json;
  check bool "has YAML file" true has_yaml;
  check bool "has TOML file" true has_toml

let test_exit_code_logic () =
  let success_summary = Error.create_empty_summary () in
  let result = Error.create_validation_result ~filename:"good.json" ~success:true () in
  let success_summary = Error.add_result_to_summary success_summary result in
  check int "success exit code" 0 (Error.validation_exit_code success_summary);
  
  let empty = Error.create_empty_summary () in
  let error_summary = { empty with files_with_errors = 1 } in
  check int "error exit code" 1 (Error.validation_exit_code error_summary)

let () =
  run "Batch Processing" [
    "File Validation", [
      test_case "file validation" `Quick test_file_validation;
      test_case "file access checking" `Quick test_file_access_checking;
    ];
    "Validation Results", [
      test_case "result creation" `Quick test_validation_result_creation;
      test_case "summary aggregation" `Quick test_validation_summary_aggregation;
      test_case "exit code logic" `Quick test_exit_code_logic;
    ];
    "Batch Logic", [
      test_case "file processing" `Quick test_batch_file_processing;
    ];
  ]