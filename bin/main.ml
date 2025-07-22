open Sx

let convert_file filename =
  match Parsers.Json.parse_file filename with
  | Ok ast ->
      let sexp = Generators.Common_lisp.generate ast in
      print_endline sexp;
      0
  | Error error ->
      Printf.eprintf "Error: %s at %s\n" 
        error.message 
        (Position.to_string error.position);
      1

let () =
  match Sys.argv with
  | [| _; filename |] -> exit (convert_file filename)
  | _ ->
      Printf.eprintf "Usage: %s <json-file>\n" Sys.argv.(0);
      exit 1