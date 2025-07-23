open Sx

let detect_by_extension filename =
  let lowercase_filename = String.lowercase_ascii filename in
  if String.ends_with ~suffix:".json" lowercase_filename then
    Some Ast.JSON
  else if String.ends_with ~suffix:".yaml" lowercase_filename || 
          String.ends_with ~suffix:".yml" lowercase_filename then
    Some Ast.YAML
  else
    None

let detect_by_content content =
  let trimmed = String.trim content in
  if trimmed = "" then None
  else
    let first_char = trimmed.[0] in
    match first_char with
    | '{' | '[' | '"' -> Some Ast.JSON
    | '-' when String.length trimmed > 2 && trimmed.[1] = '-' && trimmed.[2] = '-' -> 
        Some Ast.YAML
    | _ ->
        if String.contains trimmed ':' && not (String.contains trimmed '{') then
          Some Ast.YAML (* yaml key-value without json object syntax *)
          (* edge case: pure numeric content could be valid json *)
        else if String.for_all (fun c -> c = ' ' || c = '\t' || c = '\n' || 
                                          Char.code c >= 48 && Char.code c <= 57 || 
                                          c = '.' || c = '-' || c = '+' || c = 'e' || c = 'E') trimmed then
          Some Ast.JSON
        else
          None

let detect_format ~filename_opt ~content =
  match filename_opt with
  | Some filename ->
      (match detect_by_extension filename with
       | Some format -> format
       | None -> 
           match detect_by_content content with
           | Some format -> format
           | None -> 
               Error.format_detection_error 
                 ~message:"Could not determine input format from filename or content" 
                 ~position:Position.dummy ())
  | None ->
      match detect_by_content content with
      | Some format -> format
      | None ->
          Error.format_detection_error
            ~message:"Could not determine input format from content (try specifying --from explicitly)"
            ~position:Position.dummy ()