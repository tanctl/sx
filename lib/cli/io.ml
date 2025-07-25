type stream_config = {
  buffer_size : int;
  show_progress : bool;
  progress_interval : int; (* progress update every N items *)
}

let default_stream_config = {
  buffer_size = 8192;
  show_progress = false;
  progress_interval = 1000;
}

type stream_source = 
  | File of string
  | Stdin

let is_streamable_file filename =
  try
    let stats = Unix.stat filename in
    stats.st_size > 1024 * 1024 (* streamable if file larger than 1mb *)
  with _ -> false

let is_stdin_available () =
  try
    not (Unix.isatty Unix.stdin)
  with _ -> false

let detect_stream_source = function
  | Some "-" | None when is_stdin_available () -> Some Stdin
  | Some filename when is_streamable_file filename -> Some (File filename)
  | _ -> None

let open_input_stream = function
  | Stdin -> stdin
  | File filename -> open_in filename

let close_input_stream stream = function
  | Stdin -> () (* dont close stdin *)
  | File _ -> close_in stream

type progress_state = {
  mutable count : int;
  mutable last_reported : int;
  start_time : float;
}

let create_progress_state () = {
  count = 0;
  last_reported = 0;
  start_time = Unix.time ();
}

let update_progress config state =
  state.count <- state.count + 1;
  if config.show_progress && 
     (state.count - state.last_reported) >= config.progress_interval then
    let elapsed = Unix.time () -. state.start_time in
    let rate = float_of_int state.count /. elapsed in
    Printf.eprintf "\rProcessed %d items (%.1f items/sec)%!" state.count rate;
    state.last_reported <- state.count

let finish_progress config state =
  if config.show_progress then
    let elapsed = Unix.time () -. state.start_time in
    let rate = float_of_int state.count /. elapsed in
    Printf.eprintf "\rProcessed %d items in %.2fs (%.1f items/sec)\n%!" 
      state.count elapsed rate

(* buffered line reader for json lines *)
type line_reader = {
  channel : in_channel;
  buffer : Buffer.t;
  mutable eof : bool;
}

let create_line_reader channel = {
  channel;
  buffer = Buffer.create 1024;
  eof = false;
}

let read_line reader =
  if reader.eof then None
  else
    try
      let line = input_line reader.channel in
      Some (String.trim line)
    with End_of_file ->
      reader.eof <- true;
      None

(* if content is json lines *)
let is_jsonlines_format content =
  let lines = String.split_on_char '\n' content in
  let non_empty_lines = List.filter (fun s -> String.trim s <> "") lines in
  match non_empty_lines with
  | [] -> false
  | lines when List.length lines > 1 ->
      (* if each line starts with { or [ *)
      List.for_all (fun line ->
        let trimmed = String.trim line in
        String.length trimmed > 0 && 
        (trimmed.[0] = '{' || trimmed.[0] = '[')
      ) (List.take (min 5 (List.length lines)) lines)
  | _ -> false

let is_large_json_array content =
  let trimmed = String.trim content in
  String.length trimmed > 0 && trimmed.[0] = '[' &&
  String.length content > 1024