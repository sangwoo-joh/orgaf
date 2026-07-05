(** Pass 1 — the stateful line scanner (see docs/design.md §3).

    It walks the document line by line and emits a *flat* sequence of markers:
    headlines, planning lines, and fully-built non-heading elements. Headline
    nesting and section grouping are left to {!Nest}. Paired elements (blocks,
    drawers) are consumed here without re-dispatching their bodies — that is what
    makes the scan context-sensitive and solves the "[* not a headline]" problem.

    Inline-bearing fragments are handed straight to Pass 2 ({!Parse.parse_inline})
    as they are finalized; the raw text never enters the AST. *)

module L = Line
module M = Model

type heading_marker =
  { level : int
  ; keyword : string option
  ; priority : char option
  ; comment : bool
  ; title : M.object_ list
  ; tags : string list
  }

type flat =
  | FHeading of heading_marker
  | FPlanning of M.planning_info
  | FElement of M.element

(* ------------------------------------------------------------------ *)
(* small string helpers                                               *)
(* ------------------------------------------------------------------ *)

let lstrip s =
  let n = String.length s in
  let i = ref 0 in
  while !i < n && (s.[!i] = ' ' || s.[!i] = '\t') do
    incr i
  done;
  String.sub s !i (n - !i)
;;

let rstrip s =
  let n = String.length s in
  let j = ref n in
  while !j > 0 && (s.[!j - 1] = ' ' || s.[!j - 1] = '\t') do
    decr j
  done;
  String.sub s 0 !j
;;

let starts_with ~prefix s =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix
;;

(* [s] is exactly [w], or [w] followed by a blank *)
let starts_with_word s w =
  s = w
  || (String.length s > String.length w
      && String.sub s 0 (String.length w) = w
      && (s.[String.length w] = ' ' || s.[String.length w] = '\t'))
;;

let split_first_word s =
  let s = lstrip s in
  match String.index_opt s ' ' with
  | None -> s, ""
  | Some i ->
    String.sub s 0 i, lstrip (String.sub s (i + 1) (String.length s - i - 1))
;;

let is_tag_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '@' | '#' | '%' -> true
  | _ -> false
;;

let todo_keywords = [ "TODO"; "DONE" ]

(* ------------------------------------------------------------------ *)
(* headline                                                           *)
(* ------------------------------------------------------------------ *)

let is_tag_block s =
  let n = String.length s in
  n >= 2
  && s.[0] = ':'
  && s.[n - 1] = ':'
  && String.for_all (fun c -> c = ':' || is_tag_char c) s
;;

let split_tags s = String.split_on_char ':' s |> List.filter (fun t -> t <> "")

let find_tags rest =
  let rest = rstrip rest in
  let take_block cand before =
    if is_tag_block cand then rstrip before, split_tags cand else rest, []
  in
  match String.rindex_opt rest ' ' with
  | Some i ->
    take_block
      (String.sub rest (i + 1) (String.length rest - i - 1))
      (String.sub rest 0 i)
  | None -> take_block rest ""
;;

let strip_keyword s =
  match List.find_opt (fun w -> starts_with_word s w) todo_keywords with
  | Some w ->
    ( Some w
    , lstrip
        (String.sub s (String.length w) (String.length s - String.length w)) )
  | None -> None, s
;;

let strip_priority s =
  (* [#A] — single alphanumeric cookie *)
  if String.length s >= 4 && s.[0] = '[' && s.[1] = '#' && s.[3] = ']'
  then Some s.[2], lstrip (String.sub s 4 (String.length s - 4))
  else None, s
;;

let strip_comment s =
  if starts_with_word s "COMMENT"
  then true, lstrip (String.sub s 7 (String.length s - 7))
  else false, s
;;

let parse_headline (line : L.t) : heading_marker option =
  if line.indent <> 0
  then None
  else (
    let raw = line.raw in
    let n = String.length raw in
    let level = ref 0 in
    while !level < n && raw.[!level] = '*' do
      incr level
    done;
    let level = !level in
    if level = 0 || level >= n || raw.[level] <> ' '
    then None
    else (
      let rest = lstrip (String.sub raw level (n - level)) in
      let title_part, tags = find_tags rest in
      let keyword, s = strip_keyword title_part in
      let priority, s = strip_priority s in
      let comment, s = strip_comment s in
      let title = if s = "" then [] else Parse.parse_inline s in
      Some { level; keyword; priority; comment; title; tags }))
;;

(* ------------------------------------------------------------------ *)
(* single-line dispatch predicates                                    *)
(* ------------------------------------------------------------------ *)

(* #+begin_NAME PARAMS -> (name, params) *)
let parse_block_begin content =
  let low = String.lowercase_ascii content in
  if starts_with ~prefix:"#+begin_" low
  then (
    let after = String.sub content 8 (String.length content - 8) in
    Some (split_first_word after))
  else None
;;

let is_block_end name content =
  let low = String.lowercase_ascii (rstrip content) in
  low = "#+end_" ^ String.lowercase_ascii name
;;

(* #+KEY: VALUE *)
let parse_keyword content =
  if not (starts_with ~prefix:"#+" content)
  then None
  else (
    let body = String.sub content 2 (String.length content - 2) in
    match String.index_opt body ':' with
    | None -> None
    | Some i ->
      let key = String.sub body 0 i in
      if key = "" || String.contains key ' '
      then None
      else (
        let value =
          lstrip (String.sub body (i + 1) (String.length body - i - 1))
        in
        Some (key, value)))
;;

let is_comment content = content = "#" || starts_with ~prefix:"# " content
let is_fixed_width content = content = ":" || starts_with ~prefix:": " content

let is_hrule content =
  let t = rstrip content in
  String.length t >= 5 && String.for_all (fun c -> c = '-') t
;;

(* :NAME: on its own line -> drawer start *)
let parse_drawer_begin content =
  let n = String.length (rstrip content) in
  if n < 2 || content.[0] <> ':'
  then None
  else (
    match String.index_from_opt content 1 ':' with
    | Some j when j = n - 1 ->
      let name = String.sub content 1 (j - 1) in
      if
        name <> ""
        && String.uppercase_ascii name <> "END"
        && String.for_all (fun c -> is_tag_char c || c = '-') name
      then Some name
      else None
    | _ -> None)
;;

let is_drawer_end content = String.lowercase_ascii (rstrip content) = ":end:"

(* :NAME: VALUE inside a property drawer *)
let parse_node_property content =
  if String.length content < 2 || content.[0] <> ':'
  then None
  else (
    match String.index_from_opt content 1 ':' with
    | Some j ->
      let name = String.sub content 1 (j - 1) in
      let value =
        lstrip (String.sub content (j + 1) (String.length content - j - 1))
      in
      if name = ""
      then None
      else Some { M.name; value = (if value = "" then None else Some value) }
    | None -> None)
;;

let is_table content = starts_with ~prefix:"|" content

let is_tblfm content =
  starts_with ~prefix:"#+tblfm:" (String.lowercase_ascii content)
;;

let is_planning content =
  starts_with_word content "SCHEDULED:"
  || starts_with_word content "DEADLINE:"
  || starts_with ~prefix:"SCHEDULED:" content
  || starts_with ~prefix:"DEADLINE:" content
  || starts_with ~prefix:"CLOSED:" content
;;

(* \begin{NAME}EXTRA -> (name, extra) *)
let parse_latex_begin content =
  if starts_with ~prefix:"\\begin{" content
  then (
    match String.index_from_opt content 7 '}' with
    | Some j ->
      Some
        ( String.sub content 7 (j - 7)
        , String.sub content (j + 1) (String.length content - j - 1) )
    | None -> None)
  else None
;;

let is_latex_end name content = rstrip content = "\\end{" ^ name ^ "}"

(* [fn:LABEL] CONTENTS at line start -> (label, first-line contents) *)
let parse_footnote_def content =
  if starts_with ~prefix:"[fn:" content
  then (
    match String.index_from_opt content 4 ']' with
    | Some j ->
      let label = String.sub content 4 (j - 4) in
      if label <> "" && String.for_all (fun c -> is_tag_char c || c = '-') label
      then
        Some
          ( label
          , lstrip (String.sub content (j + 1) (String.length content - j - 1))
          )
      else None
    | None -> None)
  else None
;;

(* affiliated keywords: #+NAME:, #+CAPTION[opt]:, #+ATTR_backend:, … *)
let affiliated_names =
  [ "CAPTION"
  ; "DATA"
  ; "HEADER"
  ; "HEADERS"
  ; "LABEL"
  ; "NAME"
  ; "PLOT"
  ; "RESNAME"
  ; "RESULT"
  ; "RESULTS"
  ; "SOURCE"
  ; "SRCNAME"
  ; "TBLNAME"
  ]
;;

let parse_affiliated content : M.affiliated_keyword_info option =
  if not (starts_with ~prefix:"#+" content)
  then None
  else (
    let body = String.sub content 2 (String.length content - 2) in
    match String.index_opt body ':' with
    | None -> None
    | Some ci ->
      let key, optval =
        match String.index_opt body '[' with
        | Some bi when bi < ci ->
          (match String.index_from_opt body bi ']' with
           | Some be when be < ci ->
             String.sub body 0 bi, Some (String.sub body (bi + 1) (be - bi - 1))
           | _ -> String.sub body 0 ci, None)
        | _ -> String.sub body 0 ci, None
      in
      let ukey = String.uppercase_ascii key in
      if List.mem ukey affiliated_names || starts_with ~prefix:"ATTR_" ukey
      then (
        let value_raw =
          lstrip (String.sub body (ci + 1) (String.length body - ci - 1))
        in
        let value_parsed =
          if ukey = "CAPTION" then Some (Parse.parse_inline value_raw) else None
        in
        Some { M.key; optval; value_raw; value_parsed })
      else None)
;;

(* ------------------------------------------------------------------ *)
(* list items                                                         *)
(* ------------------------------------------------------------------ *)

(* returns (bullet, rest_after_bullet) *)
let parse_bullet content =
  let n = String.length content in
  let after k = k < n && (content.[k] = ' ' || content.[k] = '\t') in
  if
    n >= 1
    && (content.[0] = '-' || content.[0] = '+' || content.[0] = '*')
    && (n = 1 || after 1)
  then Some (String.make 1 content.[0], lstrip (String.sub content 1 (n - 1)))
  else (
    (* COUNTER. or COUNTER) — digits or single letter *)
    let i = ref 0 in
    while !i < n && content.[!i] >= '0' && content.[!i] <= '9' do
      incr i
    done;
    let counter_len =
      if !i > 0
      then !i
      else if n >= 1 && content.[0] >= 'a' && content.[0] <= 'z'
      then 1
      else 0
    in
    if
      counter_len > 0
      && counter_len < n
      && (content.[counter_len] = '.' || content.[counter_len] = ')')
      && (counter_len + 1 = n || after (counter_len + 1))
    then
      Some
        ( String.sub content 0 (counter_len + 1)
        , lstrip (String.sub content (counter_len + 1) (n - counter_len - 1)) )
    else None)
;;

let is_item content = parse_bullet content <> None

let strip_counter_set s =
  (* [@N] *)
  if String.length s >= 3 && s.[0] = '[' && s.[1] = '@'
  then (
    match String.index_opt s ']' with
    | Some j ->
      ( Some (String.sub s 0 (j + 1))
      , lstrip (String.sub s (j + 1) (String.length s - j - 1)) )
    | None -> None, s)
  else None, s
;;

let strip_check_box s =
  if String.length s >= 3 && s.[0] = '[' && s.[2] = ']'
  then (
    let cb =
      match s.[1] with
      | ' ' -> Some `Whitespace
      | 'X' -> Some `X
      | '-' -> Some `Hyphen
      | _ -> None
    in
    match cb with
    | Some _ -> cb, lstrip (String.sub s 3 (String.length s - 3))
    | None -> None, s)
  else None, s
;;

let split_tag s =
  (* TAG :: CONTENTS *)
  let sep = " :: " in
  let rec find i =
    if i + String.length sep > String.length s
    then None
    else if String.sub s i (String.length sep) = sep
    then Some i
    else find (i + 1)
  in
  match find 0 with
  | Some i ->
    let tag = String.sub s 0 i in
    let rest =
      String.sub
        s
        (i + String.length sep)
        (String.length s - i - String.length sep)
    in
    Parse.parse_inline tag, rest
  | None -> [], s
;;

(* ------------------------------------------------------------------ *)
(* planning (timestamps come from Parse.timestamp_of_string)          *)
(* ------------------------------------------------------------------ *)

let planning_key content i =
  (* keyword + colon at [i] -> (key, index after colon) *)
  List.find_map
    (fun (word, key) ->
       let w = word ^ ":" in
       if
         starts_with
           ~prefix:w
           (String.sub content i (String.length content - i))
       then Some (key, i + String.length w)
       else None)
    [ "SCHEDULED", `Scheduled; "DEADLINE", `Deadline; "CLOSED", `Closed ]
;;

(* read a <...> / [...] group (and any --<...> range continuation) at [i] *)
let read_timestamp_str content i =
  let n = String.length content in
  let close_of c = if c = '<' then '>' else ']' in
  let read_one k =
    if k >= n || not (content.[k] = '<' || content.[k] = '[')
    then None
    else
      String.index_from_opt content k (close_of content.[k])
      |> Option.map (fun j -> j + 1)
  in
  match read_one i with
  | None -> None
  | Some j ->
    if j + 2 < n && content.[j] = '-' && content.[j + 1] = '-'
    then (
      match read_one (j + 2) with
      | Some k -> Some (String.sub content i (k - i), k)
      | None -> Some (String.sub content i (j - i), j))
    else Some (String.sub content i (j - i), j)
;;

let parse_planning content =
  let n = String.length content in
  let rec skip_spaces i =
    if i < n && content.[i] = ' ' then skip_spaces (i + 1) else i
  in
  let rec go i acc =
    if i >= n
    then List.rev acc
    else (
      match planning_key content i with
      | Some (key, j) ->
        let k = skip_spaces j in
        (match read_timestamp_str content k with
         | Some (ts, k') ->
           (match Parse.timestamp_of_string ts with
            | Some timestamp -> go k' ({ M.keyword = key; timestamp } :: acc)
            | None -> go (k + 1) acc)
         | None -> go (k + 1) acc)
      | None -> go (i + 1) acc)
  in
  match go 0 [] with
  | [] -> None
  | plannings -> Some { M.plannings }
;;

(* ------------------------------------------------------------------ *)
(* elements needing raw bodies                                        *)
(* ------------------------------------------------------------------ *)

let raw_body lines =
  String.concat "\n" (List.map (fun (l : L.t) -> l.raw) lines)
;;

let opt s = if s = "" then None else Some s
let lesser l = M.Elt_Lesser_Element (l, [])
let greater g = M.Elt_Greater_Element (g, [])

let paragraph_of lines =
  let text =
    String.concat " " (List.map (fun (l : L.t) -> rstrip l.L.content) lines)
  in
  lesser (M.Lelt_Paragraph (Parse.parse_inline text))
;;

(* ------------------------------------------------------------------ *)
(* the scan loop                                                      *)
(* ------------------------------------------------------------------ *)

(* affiliated keywords with no element after them are just regular keywords *)
let orphan_affiliated aff =
  List.rev_map
    (fun (ak : M.affiliated_keyword_info) ->
       FElement (lesser (M.Lelt_Keyword { key = ak.key; value = ak.value_raw })))
    aff
;;

let attach_affiliated aff flats =
  match aff, flats with
  | [], _ -> flats
  | _, [ FElement (M.Elt_Greater_Element (g, _)) ] ->
    [ FElement (M.Elt_Greater_Element (g, List.rev aff)) ]
  | _, [ FElement (M.Elt_Lesser_Element ((M.Lelt_Keyword _ as l), _)) ] ->
    orphan_affiliated aff @ [ FElement (lesser l) ]
  | _, [ FElement (M.Elt_Lesser_Element (l, _)) ] ->
    [ FElement (M.Elt_Lesser_Element (l, List.rev aff)) ]
  | _, _ -> orphan_affiliated aff @ flats
;;

let rec scan (lines : L.t list) : flat list = scan_aff [] lines

(* [aff] holds pending affiliated keywords (most recent first) to attach to the
   next element. A blank line or a non-attachable target orphans them. *)
and scan_aff aff (lines : L.t list) : flat list =
  match lines with
  | [] -> orphan_affiliated aff
  | line :: rest ->
    if line.blank
    then orphan_affiliated aff @ scan rest
    else (
      match parse_affiliated line.content with
      | Some ak -> scan_aff (ak :: aff) rest
      | None ->
        let flats, rest' = dispatch line rest in
        attach_affiliated aff flats @ scan rest')

and dispatch (line : L.t) rest =
  let content = line.L.content in
  match parse_headline line with
  | Some m -> [ FHeading m ], rest
  | None ->
    (match parse_block_begin content with
     | Some (name, params) -> handle_block name params rest
     | None ->
       (match parse_latex_begin content with
        | Some (name, extra) -> handle_latex_env name extra rest
        | None ->
          (match parse_footnote_def content with
           | Some (label, first) -> handle_footnote_def label first rest
           | None ->
             (match parse_keyword content with
              | Some (key, value) ->
                [ FElement (lesser (M.Lelt_Keyword { key; value })) ], rest
              | None ->
                if is_comment content
                then handle_comment (line :: rest)
                else (
                  match parse_drawer_begin content with
                  | Some name -> handle_drawer name rest
                  | None ->
                    if is_fixed_width content
                    then handle_fixed_width (line :: rest)
                    else if is_planning content
                    then (
                      match parse_planning content with
                      | Some p -> [ FPlanning p ], rest
                      | None -> handle_paragraph (line :: rest))
                    else if is_hrule content
                    then [ FElement (lesser M.Lelt_Horizontal_Rule) ], rest
                    else if is_table content
                    then handle_table (line :: rest)
                    else if is_item content
                    then handle_list line.L.indent (line :: rest)
                    else handle_paragraph (line :: rest))))))

(* ----- paired: blocks ----- *)
and handle_block name params rest =
  let rec collect acc = function
    | [] -> List.rev acc, []
    | (l : L.t) :: tl ->
      if is_block_end name l.content
      then List.rev acc, tl
      else collect (l :: acc) tl
  in
  let body, rest' = collect [] rest in
  let elt = build_block name params body in
  [ FElement elt ], rest'

and build_block name params body =
  let contents = opt (raw_body body) in
  match String.lowercase_ascii name with
  | "src" ->
    let language, arguments = split_first_word params in
    lesser
      (M.Lelt_Block
         (Source_Block { language; switches = ""; arguments; contents }))
  | "example" ->
    lesser (M.Lelt_Block (Example_Block { data = opt params; contents }))
  | "export" -> lesser (M.Lelt_Block (Export_Block { data = params; contents }))
  | "comment" ->
    lesser (M.Lelt_Block (Comment_Block { data = opt params; contents }))
  | "verse" ->
    lesser
      (M.Lelt_Block
         (Verse_Block
            { data = opt params; contents = Parse.parse_inline (raw_body body) }))
  | "center" ->
    greater
      (M.Gelt_Greater_Block
         { name
         ; subtype = `Center
         ; parameters = opt params
         ; contents = elements_of body
         })
  | "quote" ->
    greater
      (M.Gelt_Greater_Block
         { name
         ; subtype = `Quote
         ; parameters = opt params
         ; contents = elements_of body
         })
  | _ ->
    greater
      (M.Gelt_Greater_Block
         { name
         ; subtype = `Special name
         ; parameters = opt params
         ; contents = elements_of body
         })

(* body of a greater element -> elements (drop any stray headline markers) *)
and elements_of lines =
  List.filter_map
    (function
      | FElement e -> Some e
      | _ -> None)
    (scan lines)

(* ----- paired: LaTeX environment ----- *)
and handle_latex_env name extra rest =
  let rec collect acc = function
    | [] -> List.rev acc, []
    | (l : L.t) :: tl ->
      if is_latex_end name l.content
      then List.rev acc, tl
      else collect (l :: acc) tl
  in
  let body, rest' = collect [] rest in
  let elt =
    lesser
      (M.Lelt_LaTeX_Environment
         { name; extra = opt (rstrip extra); contents = opt (raw_body body) })
  in
  [ FElement elt ], rest'

(* ----- footnote definitions ----- *)
and handle_footnote_def label first rest =
  (* contents end at the next footnote/heading, two consecutive blanks, or EOF *)
  let rec collect acc = function
    | (l1 : L.t) :: (l2 :: _ as tl) when l1.blank && l2.blank ->
      List.rev acc, tl
    | (l : L.t) :: tl
      when parse_headline l <> None || parse_footnote_def l.content <> None ->
      List.rev acc, l :: tl
    | (l : L.t) :: tl -> collect (l :: acc) tl
    | [] -> List.rev acc, []
  in
  let body, rest' = collect [] rest in
  let body =
    List.rev (List.filter (fun (l : L.t) -> not l.L.blank) (List.rev body))
  in
  let body_lines = (if first = "" then [] else [ L.make first ]) @ body in
  ( [ FElement
        (greater
           (M.Gelt_Footnote_Definition
              { label; contents = elements_of body_lines }))
    ]
  , rest' )

(* ----- paired: drawers ----- *)
and handle_drawer name rest =
  let rec collect acc = function
    | [] -> List.rev acc, []
    | (l : L.t) :: tl ->
      if is_drawer_end l.content
      then List.rev acc, tl
      else collect (l :: acc) tl
  in
  let inner, rest' = collect [] rest in
  let elt =
    if String.uppercase_ascii name = "PROPERTIES"
    then
      greater
        (M.Gelt_Property_Drawer
           { contents =
               List.filter_map
                 (fun (l : L.t) -> parse_node_property l.content)
                 inner
           })
    else greater (M.Gelt_Drawer { name; contents = elements_of inner })
  in
  [ FElement elt ], rest'

(* ----- comment / fixed-width runs ----- *)
and handle_comment lines =
  let rec collect acc = function
    | (l : L.t) :: tl when is_comment l.content -> collect (l :: acc) tl
    | rest -> List.rev acc, rest
  in
  let run, rest' = collect [] lines in
  let strip (l : L.t) =
    let c = l.L.content in
    if c = "#" then "" else String.sub c 2 (String.length c - 2)
  in
  ( [ FElement
        (lesser (M.Lelt_Comment (String.concat "\n" (List.map strip run))))
    ]
  , rest' )

and handle_fixed_width lines =
  let rec collect acc = function
    | (l : L.t) :: tl when is_fixed_width l.content -> collect (l :: acc) tl
    | rest -> List.rev acc, rest
  in
  let run, rest' = collect [] lines in
  let strip (l : L.t) =
    let c = l.L.content in
    if c = ":" then "" else String.sub c 2 (String.length c - 2)
  in
  ( [ FElement
        (lesser
           (M.Lelt_Fixed_Width_Area (String.concat "\n" (List.map strip run))))
    ]
  , rest' )

(* ----- tables ----- *)
and handle_table lines =
  let rec collect acc = function
    | (l : L.t) :: tl when is_table l.content -> collect (l :: acc) tl
    | rest -> List.rev acc, rest
  in
  let rows_lines, after = collect [] lines in
  let rec formulas acc = function
    | (l : L.t) :: tl when is_tblfm l.content ->
      let v = lstrip (String.sub l.content 8 (String.length l.content - 8)) in
      formulas (v :: acc) tl
    | rest -> List.rev acc, rest
  in
  let formulas, rest' = formulas [] after in
  let rows = List.map (fun (l : L.t) -> parse_table_row l.content) rows_lines in
  ( [ FElement (greater (M.Gelt_Table { subtype = `Org; rows; formulas })) ]
  , rest' )

and parse_table_row content =
  let content = rstrip content in
  if String.length content >= 2 && (content.[1] = '-' || content.[1] = '+')
  then { M.subtype = `Rule; cells = [] }
  else (
    (* strip leading '|' and trailing '|' then split *)
    let inner =
      let s = String.sub content 1 (String.length content - 1) in
      if String.length s > 0 && s.[String.length s - 1] = '|'
      then String.sub s 0 (String.length s - 1)
      else s
    in
    let cells =
      String.split_on_char '|' inner
      |> List.map (fun c ->
        { M.contents = Parse.parse_inline (String.trim c)
        ; spaces = None
        ; eol = ""
        })
    in
    { M.subtype = `Standard; cells })

(* ----- plain lists ----- *)
and handle_list base lines =
  let rec collect acc = function
    | (l : L.t) :: tl
      when (not l.blank) && l.indent >= base && parse_headline l = None ->
      collect (l :: acc) tl
    | (l : L.t) :: (l2 :: _ as tl)
      when l.blank
           && (not l2.blank)
           && l2.indent >= base
           && parse_headline l2 = None -> collect (l :: acc) tl
    | rest -> List.rev acc, rest
  in
  let block, rest' = collect [] lines in
  (* drop trailing blank lines *)
  let block =
    List.rev (List.filter (fun (l : L.t) -> not l.L.blank) (List.rev block))
  in
  [ FElement (greater (M.Gelt_Plain_List (parse_list base block))) ], rest'

and parse_list base block : M.plain_list_info =
  let items = split_items base block in
  let contents = List.map parse_item items in
  let subtype =
    match contents with
    | { M.tag = _ :: _; _ } :: _ -> `Descriptive
    | { M.bullet; _ } :: _
      when String.length bullet > 0 && bullet.[String.length bullet - 1] = '.'
      -> `Ordered
    | { M.bullet; _ } :: _
      when String.length bullet > 0 && bullet.[String.length bullet - 1] = ')'
      -> `Ordered
    | _ -> `Unordered
  in
  { M.subtype; contents; level = base }

and split_items base block =
  (* group consecutive lines into items; a new item starts at indent=base bullet *)
  let rec go acc cur = function
    | [] -> List.rev (if cur = [] then acc else List.rev cur :: acc)
    | (l : L.t) :: tl ->
      if l.indent = base && is_item l.content && cur <> []
      then go (List.rev cur :: acc) [ l ] tl
      else go acc (l :: cur) tl
  in
  go [] [] block

and parse_item item_lines =
  match item_lines with
  | [] ->
    { M.bullet = "-"
    ; counter_set = None
    ; check_box = None
    ; tag = []
    ; contents = []
    }
  | head :: body ->
    let bullet, after = Option.get (parse_bullet head.L.content) in
    let counter_set, after = strip_counter_set after in
    let check_box, after = strip_check_box after in
    let tag, after = split_tag after in
    (* continuation lines (deeper, non-bullet) vs nested list (deeper bullet) *)
    let cont, nested =
      let rec sp cont = function
        | (l : L.t) :: tl when is_item l.content -> List.rev cont, l :: tl
        | (l : L.t) :: tl -> sp (l :: cont) tl
        | [] -> List.rev cont, []
      in
      sp [] body
    in
    let para_text =
      String.concat
        " "
        (rstrip after :: List.map (fun (l : L.t) -> rstrip l.L.content) cont)
      |> String.trim
    in
    let para =
      if para_text = ""
      then []
      else [ lesser (M.Lelt_Paragraph (Parse.parse_inline para_text)) ]
    in
    let nested_elems =
      match nested with
      | [] -> []
      | (l : L.t) :: _ ->
        [ greater (M.Gelt_Plain_List (parse_list l.indent nested)) ]
    in
    { M.bullet; counter_set; check_box; tag; contents = para @ nested_elems }

(* ----- paragraph (fallback) ----- *)
and handle_paragraph lines =
  let rec collect acc = function
    | (l : L.t) :: tl
      when (not l.blank)
           && parse_headline l = None
           && not (is_paragraph_breaker l) -> collect (l :: acc) tl
    | rest -> List.rev acc, rest
  in
  let run, rest' = collect [] lines in
  [ FElement (paragraph_of run) ], rest'

and is_paragraph_breaker (l : L.t) =
  let c = l.L.content in
  parse_block_begin c <> None
  || parse_latex_begin c <> None
  || parse_footnote_def c <> None
  || parse_affiliated c <> None
  || parse_keyword c <> None
  || is_comment c
  || parse_drawer_begin c <> None
  || is_fixed_width c
  || is_hrule c
  || is_table c
  || is_item c
;;
