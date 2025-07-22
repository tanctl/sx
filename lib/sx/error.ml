type error_kind =
  | ParseError of string
  | TypeError of string
  | IOError of string
  | UnsupportedFeature of string
  | FormatDetectionError of string

type error = {
  kind : error_kind;
  position : Position.t;
  source_context : string option;
}

let make_error ~kind ~position ?source_context () =
  { kind; position; source_context }

let kind_to_string = function
  | ParseError _ -> "Parse Error"
  | TypeError _ -> "Type Error"
  | IOError _ -> "I/O Error"
  | UnsupportedFeature _ -> "Unsupported Feature"
  | FormatDetectionError _ -> "Format Detection Error"

let error_message = function
  | ParseError msg -> msg
  | TypeError msg -> msg
  | IOError msg -> msg
  | UnsupportedFeature msg -> msg
  | FormatDetectionError msg -> msg

let is_tty () =
  try Unix.isatty Unix.stderr
  with _ -> false

let color_red s = if is_tty () then "\027[31m" ^ s ^ "\027[0m" else s
let color_yellow s = if is_tty () then "\027[33m" ^ s ^ "\027[0m" else s
let color_blue s = if is_tty () then "\027[34m" ^ s ^ "\027[0m" else s
let color_bold s = if is_tty () then "\027[1m" ^ s ^ "\027[0m" else s

let format_position pos =
  let loc = Position.to_string pos in
  color_blue (color_bold loc)

let format_error_kind kind =
  color_red (color_bold (kind_to_string kind))

let extract_source_line content line_num =
  let lines = String.split_on_char '\n' content in
  try Some (List.nth lines (line_num - 1))
  with _ -> None

let show_context_line line line_num column =
  let line_str = Printf.sprintf "%4d | %s" line_num line in
  let spaces = String.make (String.length (Printf.sprintf "%4d | " line_num) + column - 1) ' ' in
  let pointer = color_red "^" in
  [line_str; spaces ^ pointer]

let format_error error =
  let kind_str = format_error_kind error.kind in
  let message = error_message error.kind in
  let pos_str = format_position error.position in
  
  let header = Printf.sprintf "%s: %s" kind_str message in
  let location = Printf.sprintf "  --> %s" pos_str in
  
  let context_lines = match error.source_context with
    | Some content ->
        (match extract_source_line content error.position.line with
         | Some line -> 
             let context = show_context_line line error.position.line error.position.column in
             ["   |"] @ (List.map (fun l -> "   " ^ l) context) @ ["   |"]
         | None -> [])
    | None -> []
  in
  
  String.concat "\n" ([header; location] @ context_lines)

let print_error error =
  Printf.eprintf "%s\n" (format_error error)

exception Sx_error of error

let raise_error ~kind ~position ?source_context () =
  raise (Sx_error (make_error ~kind ~position ?source_context ()))

let parse_error ~message ~position ?source_context () =
  raise_error ~kind:(ParseError message) ~position ?source_context ()

let io_error ~message ~position ?source_context () =
  raise_error ~kind:(IOError message) ~position ?source_context ()

let type_error ~message ~position ?source_context () =
  raise_error ~kind:(TypeError message) ~position ?source_context ()

let unsupported_feature ~message ~position ?source_context () =
  raise_error ~kind:(UnsupportedFeature message) ~position ?source_context ()

let format_detection_error ~message ~position ?source_context () =
  raise_error ~kind:(FormatDetectionError message) ~position ?source_context ()