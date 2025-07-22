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

type sexp =
  | Atom of string
  | List of sexp list

let rec sexp_to_string = function
  | Atom s -> s
  | List sexps ->
      "(" ^ String.concat " " (List.map sexp_to_string sexps) ^ ")"

type error = {
  message : string;
  position : Position.t;
}

exception Parse_error of error

let error ~message ~position = { message; position }

let make_error ~message ~position = Parse_error (error ~message ~position)