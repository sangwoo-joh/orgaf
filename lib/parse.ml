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
      | None -> return () (* EOF is valid condition *)
      | Some c ->
        if not (P.is_alpha c)
        then return ()
        else fail "POST character in entity cannot be alphabetic."
    in
    post_condition *> return (M.Obj_Entity { name }))
;;

let parse_entity =
  backslash
  *> choice [ parse_braced_entity; parse_whitespace_entity; parse_post_entity ]
;;

let markup_pre_condition =
  at_end_of_input
  >>= function
  | true -> return ()
  | false ->
    peek_char_fail
    >>= (function
     | ' ' | '\t' | '\n' | '\r' | '-' | '(' | '{' | '\'' | '"' -> return ()
     | _ -> fail "unsatisfied PRE condition of Markup")
;;

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
let parse_text_markup = failwith "not implemented"
let parse_link = failwith "not implemented"

let parse_object =
  choice
    [ parse_text_markup
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
    ]
;;
