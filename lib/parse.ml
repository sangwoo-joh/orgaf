open Angstrom

module Primitive = struct
  let is_space = function
    | ' ' -> true
    | _ -> false
  ;;

  let is_blank = function
    | ' ' | '\t' -> true
    | _ -> false
  ;;

  let is_newline = function
    | '\n' | '\r' -> true
    | _ -> false
  ;;

  let is_whitespace c = is_blank c || is_newline c

  let is_digit = function
    | '0' .. '9' -> true
    | _ -> false
  ;;

  let is_alpha = function
    | 'a' .. 'z' | 'A' .. 'Z' -> true
    | _ -> false
  ;;

  let is_alpha_numeric = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true
    | _ -> false
  ;;

  let is_star = function
    | '*' -> true
    | _ -> false
  ;;

  let is_special_char = function
    | '*'
    | '/'
    | '_'
    | '+'
    | '~'
    | '='
    | '['
    | '<'
    | '{'
    | '\\'
    | '@'
    | '$'
    | '\n'
    | '\r' -> true
    | _ -> false
  ;;

  let is_path_char = function
    | ' ' | '\t' | '\n' | '\r' | '(' | ')' | '[' | ']' | '<' | '>' -> false
    | _ -> true
  ;;

  let is_punct_char = function
    (* https://support.google.com/a/answer/1371415?hl=en *)
    | '!'
    | '"'
    | '#'
    | '$'
    | '%'
    | '&'
    | '\''
    | '('
    | ')'
    | '*'
    | '+'
    | ','
    | '\\'
    | '-'
    | '/'
    | ':'
    | ';'
    | '<'
    | '='
    | '>'
    | '?'
    | '@'
    | '['
    | ']'
    | '^'
    | '_'
    | '`'
    | '{'
    | '|'
    | '}' -> true
    | _ -> false
  ;;
end

module P = Primitive
module M = Model
module A = Appendix

let unit = return ()

let digit =
  satisfy P.is_digit
  >>| function
  | '0' -> 0
  | '1' -> 1
  | '2' -> 2
  | '3' -> 3
  | '4' -> 4
  | '5' -> 5
  | '6' -> 6
  | '7' -> 7
  | '8' -> 8
  | '9' -> 9
  | _ -> assert false
;;

let stars =
  take_while P.is_star
  >>= fun raw_stars ->
  if String.length raw_stars = 0
  then fail "no stars"
  else if String.length raw_stars > 6
  then fail "too many stars"
  else return (String.length raw_stars)
;;

let colon = char ':'
let whitespaces = skip_while P.is_blank
let optional_whitespaces = option () whitespaces
let eol = end_of_line
let eol_or_eof = eol <|> end_of_input
let take_till_eol = take_till P.is_newline
let blank_line = whitespaces *> eol
let lbracket = char '['
let rbracket = char ']'
let lparen = char '('
let rparen = char ')'
let lbrace = char '{'
let rbrace = char '}'
let langle = char '<'
let rangle = char '>'
let slash = char '/'
let backslash = char '\\'
let underscore = char '_'
let dash = char '-'
let is_valid_entity_name s = List.mem s A.valid_entities

(** parse until it ends with [s]*)
let take_till_string_non_greedy s =
  let rec forward acc =
    peek_string (String.length s)
    >>= fun current ->
    if current = s
    then return (String.concat "" (List.rev acc))
    else any_char >>= fun c -> forward (String.make 1 c :: acc)
  in
  forward []
;;

(*******************************************************************************************)
(* Parser Implementations *)
(* NOTE: the order of sub parsers in [choice] is important: it is the order of priority. *)
(*******************************************************************************************)

let parse_plain_text =
  take_while1 (fun c -> not (P.is_special_char c))
  >>| fun text -> M.Obj_Plain_text text
;;

let parse_braced_entity =
  take_while1 P.is_alpha
  >>= fun name ->
  if is_valid_entity_name name
  then string "{}" *> return (M.Obj_Entity { name })
  else fail (Printf.sprintf "'%s' is not a valid entity name." name)
;;

let parse_whitespace_entity =
  underscore *> take_while1 P.is_space
  >>= fun spaces ->
  let name = "_" ^ spaces in
  return (M.Obj_Entity { name })
;;

let parse_post_entity =
  take_while1 P.is_alpha
  >>= fun name ->
  if not (is_valid_entity_name name)
  then fail (Printf.sprintf "'%s' is not a valid entity name." name)
  else (
    let post_condition =
      peek_char
      >>= function
      | None -> unit (* EOF is valid condition *)
      | Some c ->
        if not (P.is_alpha c)
        then unit
        else fail "POST character in entity cannot be alphabetic."
    in
    post_condition *> return (M.Obj_Entity { name }))
;;

let parse_entity =
  backslash
  *> choice [ parse_braced_entity; parse_whitespace_entity; parse_post_entity ]
;;

let markup_pre_condition =
  (* FIXME: Current implementation has limitation. org-syntax defines PRE as a
     character *before* the MARKER, but the current implementation checks the
     character *after* the MARKER, i.e., the first character of CONTENTS. For
     example, in hello*world*, character 'o' precedes '*', thus it is not PRE,
     but the current implementation sees 'w' after '*' and wrongly says it meets
     the condition. *)
  at_end_of_input
  >>= function
  | true -> unit
  | false ->
    peek_char_fail
    >>= (function
     | ' ' | '\t' | '\n' | '\r' | '-' | '(' | '{' | '\'' | '"' -> unit
     | _ -> fail "invalid PRE condition of Markup")
;;

let markup_post_condition =
  at_end_of_input
  >>= function
  | true -> unit
  | false ->
    peek_char_fail
    >>= (function
     | ' '
     | '\t'
     | '\n'
     | '\r'
     | '-'
     | '.'
     | ','
     | ';'
     | ':'
     | '!'
     | '?'
     | '\''
     | ')'
     | '}'
     | '['
     | '"'
     | '\\' -> unit
     | _ -> fail "invalid POST condition of Markup")
;;

let parse_markup_string_contents ~marker =
  (* when marker is code or verbatim *)
  take_till (fun c -> c = marker)
  >>= fun content ->
  if String.starts_with ~prefix:" " content
     || String.ends_with ~suffix:" " content
  then fail "Verbatim/Code contents cannot start or end with whitespace"
  else return (`String content)
;;

let parse_markup_standard_contents (self_parse_object : M.object_ t) =
  many1 self_parse_object >>= fun objects -> return (`Standard objects)
;;

let parse_text_markup (self_parse_object : M.object_ t) =
  let aux_markup_parser ~marker ~markertype parser =
    markup_pre_condition *> char marker *> parser
    <* char marker
    <* markup_post_condition
    >>| fun contents -> M.Obj_Text_Markup { markertype; contents }
  in
  let parse_bold =
    aux_markup_parser
      ~marker:'*'
      ~markertype:`Bold
      (parse_markup_standard_contents self_parse_object)
  in
  let parse_italic =
    aux_markup_parser
      ~marker:'/'
      ~markertype:`Italic
      (parse_markup_standard_contents self_parse_object)
  in
  let parse_underline =
    aux_markup_parser
      ~marker:'_'
      ~markertype:`Underline
      (parse_markup_standard_contents self_parse_object)
  in
  let parse_strike_through =
    aux_markup_parser
      ~marker:'+'
      ~markertype:`Strike_Through
      (parse_markup_standard_contents self_parse_object)
  in
  let parse_code =
    aux_markup_parser
      ~marker:'~'
      ~markertype:`Code
      (parse_markup_string_contents ~marker:'~')
  in
  let parse_verbatim =
    aux_markup_parser
      ~marker:'='
      ~markertype:`Verbatim
      (parse_markup_string_contents ~marker:'=')
  in
  choice
    [ parse_bold
    ; parse_italic
    ; parse_underline
    ; parse_strike_through
    ; parse_code
    ; parse_verbatim
    ]
;;

let parse_link_parameters =
  choice
    [ string "shell"
    ; string "news"
    ; string "mailto"
    ; string "https"
    ; string "http"
    ; string "ftp"
    ; string "help"
    ; string "file"
    ; string "elisp"
    ]
;;

let parse_link_hyper_text =
  lift2
    (fun linktype pathinner -> M.Hypertext { linktype; pathinner })
    parse_link_parameters
    ((string ":" <|> string "://") *> take_while (fun c -> c <> ']'))
;;

let parse_link_id =
  string "id:" *> take_while (fun c -> c <> ']') >>| fun id -> M.Id id
;;

let parse_link_custom_id =
  char '#' *> take_while (fun c -> c <> ']') >>| fun id -> M.Custom_Id id
;;

let parse_link_code_ref =
  lparen *> take_till (fun c -> c = ')')
  <* rparen
  >>| fun code -> M.Code_Ref code
;;

let parse_link_fuzzy_or_file =
  take_while1 (fun c -> c <> ']')
  >>| fun fuzzy_or_file -> M.Fuzzy_Or_File fuzzy_or_file
;;

let parse_annotated_pattern =
  choice
    [ parse_link_hyper_text
    ; parse_link_id
    ; parse_link_custom_id
    ; parse_link_code_ref
    ; parse_link_fuzzy_or_file
    ]
;;

let parse_regular_link (self_parse_object : M.object_ t) =
  let parse_desc = string "][" *> many self_parse_object in
  let with_desc =
    string "[["
    *> lift2
         (fun pathreg description -> M.Regular_Link { pathreg; description })
         parse_annotated_pattern
         parse_desc
    <* string "]]"
  in
  let without_desc =
    string "[[" *> parse_annotated_pattern
    <* string "]]"
    >>| fun pathreg -> M.Regular_Link { pathreg; description = [] }
  in
  choice [ with_desc; without_desc ]
;;

let parse_angle_link =
  langle
  *> lift2
       (fun linktype pathangle -> M.Angle_Link { linktype; pathangle })
       parse_link_parameters
       (colon *> take_while (fun c -> c <> '>'))
  <* rangle
;;

let parse_link = failwith "not implemented"
let parse_latex_fragment = failwith "not implemented"
let parse_export_snippet = failwith "not implemented"
let parse_footnote_reference = failwith "not implemented"
let parse_citation = failwith "not implemented"
let parse_subscript = failwith "not implemented"
let parse_superscript = failwith "not implemented"
let parse_citation_reference = failwith "not implemented"
let parse_babel_calls = failwith "not implemented"
let parse_source_block = failwith "not implemented"
let parse_line_break = failwith "not implemented"
let parse_macro = failwith "not implemented"
let parse_target = failwith "not implemented"
let parse_radio_target = failwith "not implemented"
let parse_staistics_cookie = failwith "not implemented"
let parse_table_cell = failwith "not implemented"
let parse_timestamp = failwith "not implemented"

let parse_object =
  fix (fun self_parse_object ->
    choice
      [ parse_text_markup self_parse_object
      ; parse_link
      ; parse_entity
      ; parse_latex_fragment
      ; parse_export_snippet
      ; parse_footnote_reference
      ; parse_citation
      ; parse_citation_reference
      ; parse_superscript
      ; parse_subscript
      ; parse_plain_text (* should be the last *)
      ])
;;
