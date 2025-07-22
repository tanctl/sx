type value =
  | Null of Position.t
  | Bool of bool * Position.t
  | Int of int * Position.t
  | Float of float * Position.t
  | String of string * Position.t
  | List of value list * Position.t
  | Assoc of (string * value) list * Position.t

let position_of = function
  | Null pos -> pos
  | Bool (_, pos) -> pos
  | Int (_, pos) -> pos
  | Float (_, pos) -> pos
  | String (_, pos) -> pos
  | List (_, pos) -> pos
  | Assoc (_, pos) -> pos

type input_format =
  | Auto
  | JSON

type output_format =
  | Common_lisp
  | Scheme

type formatting =
  | Pretty
  | Compact

type sexp =
  | Atom of string
  | List of sexp list

let rec sexp_to_string_compact = function
  | Atom s -> s
  | List sexps ->
      "(" ^ String.concat " " (List.map sexp_to_string_compact sexps) ^ ")"

let rec sexp_to_string_pretty ?(indent=0) = function
  | Atom s -> s
  | List [] -> "()"
  | List [single] -> "(" ^ sexp_to_string_pretty ~indent single ^ ")"
  | List sexps ->
      let inner_spaces = String.make (indent + 2) ' ' in
      let items = List.map (sexp_to_string_pretty ~indent:(indent + 2)) sexps in
      "(" ^ String.concat ("\n" ^ inner_spaces) items ^ ")"

let sexp_to_string ?(formatting=Pretty) sexp =
  match formatting with
  | Compact -> sexp_to_string_compact sexp
  | Pretty -> sexp_to_string_pretty sexp

type error = {
  message : string;
  position : Position.t;
}

exception Parse_error of error

let error ~message ~position = { message; position }

let make_error ~message ~position = Parse_error (error ~message ~position)