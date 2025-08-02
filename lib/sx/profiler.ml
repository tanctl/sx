type stage = 
  | Parse
  | Transform  
  | Generate
  | Total

type profiling_result = {
  stage : stage;
  duration_ms : float;
  memory_mb : float;
}

type timer = {
  start_time : float;
  start_memory : float;
}

let string_of_stage = function
  | Parse -> "Parse"
  | Transform -> "Transform"
  | Generate -> "Generate"
  | Total -> "Total"

let get_memory_usage_mb () =
  let stat = Gc.stat () in
  (* convert bytes to megabytes *)
  float_of_int (stat.heap_words * (Sys.word_size / 8)) /. (1024.0 *. 1024.0)

let start_timer () =
  {
    start_time = Unix.gettimeofday ();
    start_memory = get_memory_usage_mb ();
  }

let stop_timer timer stage =
  let end_time = Unix.gettimeofday () in
  let end_memory = get_memory_usage_mb () in
  let duration_ms = (end_time -. timer.start_time) *. 1000.0 in
  let memory_mb = max end_memory timer.start_memory in
  {
    stage;
    duration_ms;
    memory_mb;
  }

type profiler = {
  mutable results : profiling_result list;
  mutable enabled : bool;
}

let create_profiler ?(enabled=false) () =
  { results = []; enabled }

let enable profiler = 
  profiler.enabled <- true

let disable profiler =
  profiler.enabled <- false

let profile_stage profiler stage f =
  if not profiler.enabled then
    f ()
  else
    let timer = start_timer () in
    let result = f () in
    let profile_result = stop_timer timer stage in
    profiler.results <- profile_result :: profiler.results;
    result

let get_results profiler =
  List.rev profiler.results

let format_duration_ms duration =
  if duration < 1.0 then
    Printf.sprintf "%.1fms" duration
  else if duration < 1000.0 then
    Printf.sprintf "%.0fms" duration
  else
    Printf.sprintf "%.2fs" (duration /. 1000.0)

let format_memory_mb memory =
  if memory < 1.0 then
    Printf.sprintf "%.1fMB" memory
  else
    Printf.sprintf "%.1fMB" memory

let print_results profiler =
  if not profiler.enabled then () else
  let results = get_results profiler in
  if results = [] then () else
  
  Printf.printf "\nPipeline Analysis:\n";
  
  (* calculate column widths for alignment *)
  let max_stage_width = List.fold_left (fun acc result ->
    max acc (String.length (string_of_stage result.stage))
  ) 0 results in
  let stage_width = max max_stage_width 8 in
  
  List.iter (fun result ->
    let stage_str = string_of_stage result.stage in
    let duration_str = format_duration_ms result.duration_ms in
    let memory_str = format_memory_mb result.memory_mb in
    Printf.printf "%-*s | %6s | %s\n" 
      stage_width stage_str duration_str memory_str
  ) results;
  
  flush stdout

let calculate_peak_memory results =
  List.fold_left (fun acc result -> max acc result.memory_mb) 0.0 results

let add_total_result profiler =
  if not profiler.enabled then () else
  let results = get_results profiler in
  if results = [] then () else
  
  let total_duration = List.fold_left (fun acc result ->
    acc +. result.duration_ms
  ) 0.0 results in
  
  let peak_memory = calculate_peak_memory results in
  
  let total_result = {
    stage = Total;
    duration_ms = total_duration;
    memory_mb = peak_memory;
  } in
  
  profiler.results <- total_result :: profiler.results