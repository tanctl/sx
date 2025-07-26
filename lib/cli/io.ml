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

(* stdin is available if it's not a terminal (ie, piped or redirected) *)
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

let is_jsonlines_format content =
  let lines = String.split_on_char '\n' content in
  let non_empty_lines = List.filter (fun s -> String.trim s <> "") lines in
  match non_empty_lines with
  | [] -> false
  | lines when List.length lines > 1 ->
      (* json lines: each line should be a complete json object starting with { *)
      (* json arrays start with [ on first line, so exclude those *)
      let first_line = String.trim (List.hd lines) in
      if String.length first_line > 0 && first_line.[0] = '[' then
        false
      else
        List.for_all (fun line ->
          let trimmed = String.trim line in
          String.length trimmed > 0 && trimmed.[0] = '{'
        ) (List.take (min 5 (List.length lines)) lines)
  | _ -> false

let is_large_json_array content =
  let trimmed = String.trim content in
  String.length trimmed > 0 && trimmed.[0] = '[' &&
  String.length content > 1024

type file_type = RegularFile | Directory | SymbolicLink | Other

let get_file_type path =
  try
    let stats = Unix.lstat path in
    match stats.st_kind with
    | Unix.S_REG -> RegularFile
    | Unix.S_DIR -> Directory
    | Unix.S_LNK -> SymbolicLink
    | _ -> Other
  with
  | Unix.Unix_error _ -> Other

let file_exists path =
  try
    let _ = Unix.stat path in
    true
  with
  | Unix.Unix_error _ -> false

let is_readable path =
  try
    Unix.access path [Unix.R_OK];
    true
  with
  | Unix.Unix_error _ -> false

let check_file_access path =
  if not (file_exists path) then
    Error (`File_not_found path)
  else if not (is_readable path) then
    Error (`Permission_denied path)
  else
    match get_file_type path with
    | Directory -> Error (`Is_directory path)
    | RegularFile -> Ok path
    | SymbolicLink ->
        (* resolve symlink and check if target is accessible *)
        (try
          let target = Unix.readlink path in
          if is_readable target then Ok path
          else Error (`Permission_denied target)
        with
        | Unix.Unix_error _ -> Error (`Broken_symlink path))
    | Other -> Error (`Unsupported_file_type path)

let get_file_size path =
  try
    let stats = Unix.stat path in
    Some stats.st_size
  with
  | Unix.Unix_error _ -> None

let validate_input_files files =
  let results = List.map (fun file ->
    match check_file_access file with
    | Ok _ -> (file, None)
    | Error error -> (file, Some error)
  ) files in
  
  let valid_files = List.filter_map (function
    | (file, None) -> Some file
    | (_, Some _) -> None
  ) results in
  
  let errors = List.filter_map (function
    | (file, Some error) -> Some (file, error)
    | (_, None) -> None
  ) results in
  
  (valid_files, errors)