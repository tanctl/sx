open Alcotest

let test_jsonl_detection () =
  let content = {|{"test": 1}
{"test": 2}
{"test": 3}|} in
  let is_jsonl = Cli.Io.is_jsonlines_format content in
  check bool "should detect JSON Lines" true is_jsonl

let test_large_json_array_detection () =
  (* Create a JSON array string that's larger than 1024 bytes *)
  let items = Array.make 100 {|{"id": 123, "name": "test item")|} in
  let content = "[" ^ String.concat ", " (Array.to_list items) ^ "]" in
  let is_large = Cli.Io.is_large_json_array content in
  check bool "should detect large JSON array" true is_large

let test_small_json_array_not_large () =
  let content = {|[{"id": 1}, {"id": 2}]|} in
  let is_large = Cli.Io.is_large_json_array content in
  check bool "small array not considered large" false is_large

let test_stream_config_creation () =
  let config = Cli.Io.default_stream_config in
  check int "default buffer size" 8192 config.buffer_size;
  check bool "default show progress" false config.show_progress;
  check int "default progress interval" 1000 config.progress_interval

let test_progress_state () =
  let state = Cli.Io.create_progress_state () in
  check int "initial count" 0 state.count;
  check int "initial last reported" 0 state.last_reported

(* Test streaming mode selection logic *)
let test_streaming_mode_selection () =
  let small_json = {|{"test": true}|} in
  let large_array = "[" ^ String.make 2000 '1' ^ "]" in
  let jsonl_content = {|{"line": 1}
{"line": 2}|} in
  
  check bool "small JSON not streaming" false (Cli.Io.is_large_json_array small_json);
  check bool "large array is streaming" true (Cli.Io.is_large_json_array large_array);
  check bool "JSONL is streaming" true (Cli.Io.is_jsonlines_format jsonl_content)

let () =
  run "Streaming" [
    "Detection", [
      test_case "JSON Lines detection" `Quick test_jsonl_detection;
      test_case "large JSON array detection" `Quick test_large_json_array_detection;
      test_case "small array not large" `Quick test_small_json_array_not_large;
      test_case "streaming mode selection" `Quick test_streaming_mode_selection;
    ];
    "Configuration", [
      test_case "stream config creation" `Quick test_stream_config_creation;
      test_case "progress state" `Quick test_progress_state;
    ];
  ]