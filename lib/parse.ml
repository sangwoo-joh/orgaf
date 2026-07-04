open Angstrom
module P = Primitive
module M = Model
module A = Appendix

let unit = return ()

let number =
  satisfy P.is_numeric
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
  >>| fun spaces ->
  let name = "_" ^ spaces in
  M.Obj_Entity { name }
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

(* org-syntax defines PRE as the character *before* the MARKER. Angstrom cannot
   look back, so the top-level driver ([parse_inline]) supplies the previous
   character explicitly and gates emphasis with [pre_guard]. [None] means
   start-of-fragment, which is a valid PRE (like start-of-line). *)
let is_pre_ok = function
  | None -> true
  | Some (' ' | '\t' | '\n' | '\r' | '-' | '(' | '{' | '\'' | '"') -> true
  | Some _ -> false
;;

let pre_guard prev = if is_pre_ok prev then unit else fail "invalid PRE condition"

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

let parse_text_markup ~prev (self_parse_object : M.object_ t) =
  let aux_markup_parser ~marker ~markertype parser =
    pre_guard prev *> char marker *> parser
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
  let parse_desc =
    (* extract the description text up to "]]" first, then parse its objects —
       otherwise plain text greedily consumes the closing "]]" (']' is not a
       special char). *)
    string "][" *> take_till_string_non_greedy "]]"
    >>| fun raw ->
    match parse_string ~consume:All (many self_parse_object) raw with
    | Ok objs -> objs
    | Error _ -> [ M.Obj_Plain_text raw ]
  in
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

let parse_path_plain =
  (* This overall pattern may be matched with the following regexp:
     (?:[^ \t\n\[\]<>()]|\((?:[^ \t\n\[\]<>()]|\([^ \t\n\[\]<>()]*\))*\))+(?:[^[:punct:] \t\n]|\/|\((?:[^ \t\n\[\]<>()]|\([^ \t\n\[\]<>()]*\))*\)) *)
  let is_valid_end_char c = not (P.is_whitespace c || P.is_punct_char c) in
  let rec parse_path_atom ~depth =
    (* normal characters *)
    let normals = take_while1 P.is_path_char in
    (* group in parenthesis, this takes up to depth 2 *)
    let paren_group =
      if depth <= 0
      then fail "Max paren depth reached."
      else
        lparen *> many (parse_path_atom ~depth:(depth - 1))
        <* rparen
        >>| fun inner -> Printf.sprintf "(%s)" (String.concat "" inner)
    in
    choice [ normals; paren_group ]
  in
  many1 (parse_path_atom ~depth:2)
  >>| String.concat ""
  >>= fun path_str ->
  (* We need to check whether path string ends with either a non-punctuation
     non-whitespace character, a forward slash, or a parenthesis-wrapped
     substring. The last condition has been checked by parse_path_atom.*)
  let last_char = String.get path_str (String.length path_str - 1) in
  if is_valid_end_char last_char || last_char = '/'
  then return path_str
  else fail "Pathplain does not end with a valid character."
;;

let parse_plain_link ~prev =
  pre_guard prev
  *> lift2
       (fun linktype pathplain -> M.Plain_Link { linktype; pathplain })
       parse_link_parameters
       parse_path_plain
  <* markup_post_condition
;;

let parse_link ~prev (self_parse_object : M.object_ t) =
  (* TODO: parse_radio_link *)
  choice
    [ parse_regular_link self_parse_object
    ; parse_angle_link
    ; parse_plain_link ~prev
    ]
  >>| fun link_info -> M.Obj_Link link_info
;;

let parse_macro =
  let parse_macro_name =
    take_while1 (fun c -> P.is_alpha_numeric c || c = '-' || c = '_')
  in
  let parse_macro_args =
    lparen *> take_till (fun c -> c = ')') <* rparen >>| fun args -> Some args
  in
  let with_args =
    string "{{{"
    *> lift2
         (fun name arguments -> M.Obj_Macro { name; arguments })
         parse_macro_name
         parse_macro_args
    <* string "}}}"
  in
  let without_args =
    string "{{{" *> parse_macro_name
    <* string "}}}"
    >>| fun name -> M.Obj_Macro { name; arguments = None }
  in
  choice [ with_args; without_args ]
;;

(* let parse_latex_fragment = failwith "not implemented" *)
(* let parse_export_snippet = failwith "not implemented" *)
(* let parse_footnote_reference = failwith "not implemented" *)
(* let parse_citation = failwith "not implemented" *)
(* let parse_subscript = failwith "not implemented" *)
(* let parse_superscript = failwith "not implemented" *)
(* let parse_citation_reference = failwith "not implemented" *)
(* let parse_babel_calls = failwith "not implemented" *)
(* let parse_source_block = failwith "not implemented" *)
(* let parse_line_break = failwith "not implemented" *)
(* let parse_target = failwith "not implemented" *)
(* let parse_radio_target = failwith "not implemented" *)
(* let parse_staistics_cookie = failwith "not implemented" *)
(* let parse_table_cell = failwith "not implemented" *)
(* let parse_timestamp = failwith "not implemented" *)

(* Permissive recursive object parser, used for CONTENTS nested inside markup and
   link descriptions. PRE is treated as always-valid here (contents start is a
   boundary); the top-level driver enforces the real PRE via [make_object]. *)
let parse_object =
  fix (fun self_parse_object ->
    choice
      [ parse_text_markup ~prev:None self_parse_object
      ; parse_link ~prev:None self_parse_object
      ; parse_entity
      ; parse_macro
      (* ; parse_latex_fragment *)
      (* ; parse_export_snippet *)
      (* ; parse_footnote_reference *)
      (* ; parse_citation *)
      (* ; parse_citation_reference *)
      (* ; parse_superscript *)
      (* ; parse_subscript *)
      ; parse_plain_text (* should be the last *)
      ])
;;

(* One object at the top level, with the real previous character supplied so
   emphasis PRE is enforced correctly. *)
let make_object ~prev =
  choice
    [ parse_text_markup ~prev parse_object
    ; parse_link ~prev parse_object
    ; parse_entity
    ; parse_macro
    ; parse_plain_text
    ]
;;

let coalesce objs =
  (* merge adjacent plain-text objects produced by the single-char fallback *)
  let rec go acc = function
    | [] -> List.rev acc
    | M.Obj_Plain_text a :: M.Obj_Plain_text b :: tl ->
      go acc (M.Obj_Plain_text (a ^ b) :: tl)
    | x :: tl -> go (x :: acc) tl
  in
  go [] objs
;;

(** Pass 2 entry point: parse the objects of a single inline-bearing fragment.
    Total by construction — an unparseable character becomes plain text — so a
    malformed fragment never crashes the document parse. *)
let parse_inline (s : string) : M.object_ list =
  let n = String.length s in
  let rec loop i acc =
    if i >= n
    then coalesce (List.rev acc)
    else begin
      let prev = if i = 0 then None else Some s.[i - 1] in
      let sub = String.sub s i (n - i) in
      match
        Angstrom.parse_string
          ~consume:Prefix
          (both (make_object ~prev) pos)
          sub
      with
      | Ok (obj, len) when len > 0 -> loop (i + len) (obj :: acc)
      | _ -> loop (i + 1) (M.Obj_Plain_text (String.make 1 s.[i]) :: acc)
    end
  in
  loop 0 []
;;
