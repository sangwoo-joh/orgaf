open Orgaf
open Orgaf.Model

(* ------------------------------------------------------------------ *)
(* helpers                                                            *)
(* ------------------------------------------------------------------ *)

let fail = Alcotest.fail
let check_bool = Alcotest.(check bool)
let rec collect_headings h = h :: List.concat_map collect_headings h.children

let all_headings (doc : document) =
  List.concat_map
    (function
      | Elt_Heading h -> collect_headings h
      | _ -> [])
    doc
;;

(* every element appearing anywhere in the document tree *)
let rec elements_of_element e =
  e
  ::
  (match e with
   | Elt_Heading h ->
     (match h.section with
      | Some s -> List.concat_map elements_of_element s.contents
      | None -> [])
     @ List.concat_map (fun c -> elements_of_element (Elt_Heading c)) h.children
   | Elt_Zeroth_Section z ->
     List.concat_map elements_of_element z.section.contents
   | Elt_Section s -> List.concat_map elements_of_element s.contents
   | Elt_Greater_Element (Gelt_Drawer d, _) ->
     List.concat_map elements_of_element d.contents
   | Elt_Greater_Element (Gelt_Plain_List pl, _) ->
     List.concat_map
       (fun (i : item_info) -> List.concat_map elements_of_element i.contents)
       pl.contents
   | _ -> [])
;;

let all_elements (doc : document) = List.concat_map elements_of_element doc

(* ------------------------------------------------------------------ *)
(* Pass 2 — objects                                                   *)
(* ------------------------------------------------------------------ *)

let test_plain_text () =
  match Parse.parse_inline "just text" with
  | [ Obj_Plain_text "just text" ] -> ()
  | _ -> fail "expected a single plain-text object"
;;

let test_bold () =
  match Parse.parse_inline "a *bold* b" with
  | [ Obj_Plain_text "a "
    ; Obj_Text_Markup
        { markertype = `Bold; contents = `Standard [ Obj_Plain_text "bold" ] }
    ; Obj_Plain_text " b"
    ] -> ()
  | _ -> fail "expected: text, bold, text"
;;

let test_no_bold_midword () =
  (* PRE condition: emphasis needs a boundary before the marker *)
  match Parse.parse_inline "hello*world*" with
  | [ Obj_Plain_text "hello*world*" ] -> ()
  | _ -> fail "mid-word asterisks must stay plain text"
;;

let test_link_with_desc () =
  match Parse.parse_inline "See [[id:b13][Rules]]." with
  | [ Obj_Plain_text "See "
    ; Obj_Link
        (Regular_Link
           { pathreg = Id "b13"; description = [ Obj_Plain_text "Rules" ] })
    ; Obj_Plain_text "."
    ] -> ()
  | _ -> fail "expected an id: link with description"
;;

let test_entity () =
  match Parse.parse_inline "1\\cent." with
  | [ Obj_Plain_text "1"; Obj_Entity { name = "cent" }; Obj_Plain_text "." ] ->
    ()
  | _ -> fail "expected a \\cent entity"
;;

let test_line_break () =
  match Parse.parse_inline "one\\\\ two" with
  | [ Obj_Plain_text "one"; Obj_Line_Break; Obj_Plain_text " two" ] -> ()
  | _ -> fail "expected a line break"
;;

let test_export_snippet () =
  match Parse.parse_inline "@@html:<b>x</b>@@" with
  | [ Obj_Export_Snippet { backend = "html"; value = Some "<b>x</b>" } ] -> ()
  | _ -> fail "expected an html export snippet"
;;

let test_inline_source () =
  match Parse.parse_inline "src_python{print(1)}" with
  | [ Obj_Inline_Source_Block { language = "python"; body = "print(1)"; _ } ] ->
    ()
  | _ -> fail "expected an inline source block"
;;

let test_latex_fragment () =
  match Parse.parse_inline "x $a^2$ y" with
  | [ Obj_Plain_text "x "
    ; Obj_Latex_Fragment { contents = "$a^2$"; _ }
    ; Obj_Plain_text " y"
    ] -> ()
  | _ -> fail "expected an inline LaTeX fragment"
;;

let test_footnote_reference () =
  match Parse.parse_inline "see [fn:1]" with
  | [ Obj_Plain_text "see "
    ; Obj_Footnote_Reference { label = "1"; definition = [] }
    ] -> ()
  | _ -> fail "expected a footnote reference"
;;

let test_inline_timestamp () =
  match Parse.parse_inline "at <2026-07-05 Sun 10:00>" with
  | [ Obj_Plain_text "at "
    ; Obj_Timestamp
        (Active
           { year = 2026
           ; month = 7
           ; day = 5
           ; hour = Some 10
           ; minute = Some 0
           ; _
           })
    ] -> ()
  | _ -> fail "expected an active timestamp"
;;

let test_statistics_cookie () =
  match Parse.parse_inline "done [2/5]" with
  | [ Obj_Plain_text "done "
    ; Obj_Statistics_Cookie { percent = None; num1 = Some 2; num2 = Some 5 }
    ] -> ()
  | _ -> fail "expected a [2/5] statistics cookie"
;;

let test_percent_cookie () =
  match Parse.parse_inline "[50%]" with
  | [ Obj_Statistics_Cookie { percent = Some 50; _ } ] -> ()
  | _ -> fail "expected a [50%] statistics cookie"
;;

let test_target () =
  match Parse.parse_inline "see <<anchor>>" with
  | [ Obj_Plain_text "see "; Obj_Target { target = "anchor" } ] -> ()
  | _ -> fail "expected a target"
;;

let test_radio_stays_plain () =
  (* radio targets are left to a future resolution pass -> plain text *)
  match Parse.parse_inline "<<<radio>>>" with
  | [ Obj_Plain_text "<<<radio>>>" ] -> ()
  | _ -> fail "radio target must remain plain text"
;;

let test_subscript () =
  match Parse.parse_inline "H_{2}O" with
  | [ Obj_Plain_text "H"
    ; Obj_Subscript { script = Structured [ Obj_Plain_text "2" ]; _ }
    ; Obj_Plain_text "O"
    ] -> ()
  | _ -> fail "expected a subscript"
;;

let test_no_bare_subscript () =
  (* bare form is deliberately unsupported so snake_case is untouched *)
  match Parse.parse_inline "snake_case" with
  | [ Obj_Plain_text "snake_case" ] -> ()
  | _ -> fail "snake_case must stay plain text"
;;

(* ------------------------------------------------------------------ *)
(* Pass 1 — structure                                                 *)
(* ------------------------------------------------------------------ *)

let test_headline_components () =
  let doc =
    Doc.parse "* Big\n** DONE child\n*** TODO [#A] COMMENT Complex :tag:a2%:\n"
  in
  match all_headings doc with
  | [ big; child; complex ] ->
    check_bool "big level" true (big.level = 1 && big.keyword = None);
    check_bool "child DONE" true (child.level = 2 && child.keyword = Some "DONE");
    check_bool "complex level" true (complex.level = 3);
    check_bool "complex keyword" true (complex.keyword = Some "TODO");
    check_bool "complex priority" true (complex.priority = Some 'A');
    check_bool "complex comment" true complex.comment;
    check_bool "complex tags" true (complex.tags = [ "tag"; "a2%" ]);
    (match complex.title with
     | [ Obj_Plain_text "Complex" ] -> ()
     | _ -> fail "complex title")
  | _ -> fail "expected 3 headings"
;;

let test_nesting () =
  let doc = Doc.parse "* A\n** B\n** C\n*** D\n* E\n" in
  match doc with
  | [ Elt_Heading a; Elt_Heading e ] ->
    check_bool "A children" true (List.length a.children = 2);
    check_bool "E level" true (e.level = 1 && e.children = []);
    (match a.children with
     | [ _b; c ] -> check_bool "C has child D" true (List.length c.children = 1)
     | _ -> fail "A should have B and C")
  | _ -> fail "expected two top-level headings A and E"
;;

(* the docs/design.md §6 context-sensitivity example *)
let test_src_block_raw () =
  let doc =
    Doc.parse
      "#+begin_src ocaml\nlet x = \"* not a headline\" in x\n#+end_src\n"
  in
  check_bool "no headline emitted from src body" true (all_headings doc = []);
  let src =
    List.find_map
      (function
        | Elt_Lesser_Element
            (Lelt_Block (Source_Block { language; contents; _ }), _) ->
          Some (language, contents)
        | _ -> None)
      (all_elements doc)
  in
  match src with
  | Some (language, contents) ->
    check_bool "language" true (language = "ocaml");
    (match contents with
     | Some body ->
       check_bool
         "body captured raw"
         true
         (String.length body >= 16
          &&
          let needle = "* not a headline" in
          let rec find i =
            i + String.length needle <= String.length body
            && (String.sub body i (String.length needle) = needle || find (i + 1)
               )
          in
          find 0)
     | None -> fail "src body missing")
  | None -> fail "expected a source block"
;;

let test_property_drawer () =
  let doc = Doc.parse ":PROPERTIES:\n:ID: abc-123\n:END:\n" in
  match doc with
  | [ Elt_Zeroth_Section { property_drawer = Some { contents }; _ } ] ->
    (match contents with
     | [ { name = "ID"; value = Some "abc-123" } ] -> ()
     | _ -> fail "expected ID property")
  | _ -> fail "expected zeroth section with property drawer"
;;

let test_list () =
  let doc = Doc.parse "- item\n3. [@3] set to three\n+ [-] tag :: contents\n" in
  let plain_list =
    List.find_map
      (function
        | Elt_Greater_Element (Gelt_Plain_List pl, _) -> Some pl
        | _ -> None)
      (all_elements doc)
  in
  match plain_list with
  | Some { contents; subtype; _ } ->
    check_bool "unordered (first bullet -)" true (subtype = `Unordered);
    (match contents with
     | [ a; b; c ] ->
       check_bool "a bullet" true (a.bullet = "-");
       check_bool
         "b counter-set"
         true
         (b.counter_set = Some "[@3]" && b.bullet = "3.");
       check_bool "c checkbox" true (c.check_box = Some `Hyphen);
       check_bool "c tag" true (c.tag = [ Obj_Plain_text "tag" ])
     | _ -> fail "expected 3 items")
  | None -> fail "expected a plain list"
;;

let test_table () =
  let doc = Doc.parse "| a | b |\n|---+---|\n| 1 | 2 |\n" in
  let table =
    List.find_map
      (function
        | Elt_Greater_Element (Gelt_Table t, _) -> Some t
        | _ -> None)
      (all_elements doc)
  in
  match table with
  | Some { rows; _ } ->
    (match rows with
     | [ r1; rule; r3 ] ->
       check_bool "row1 cells" true (List.length r1.cells = 2);
       check_bool "rule row" true (rule.subtype = `Rule);
       check_bool
         "row3 first cell"
         true
         (match r3.cells with
          | { contents = [ Obj_Plain_text "1" ]; _ } :: _ -> true
          | _ -> false)
     | _ -> fail "expected 3 rows")
  | None -> fail "expected a table"
;;

let test_keyword () =
  match Doc.parse "#+title: Notes\n" with
  | [ Elt_Zeroth_Section
        { section =
            { contents =
                [ Elt_Lesser_Element
                    (Lelt_Keyword { key = "title"; value = "Notes" }, _)
                ]
            }
        ; _
        }
    ] -> ()
  | _ -> fail "expected a title keyword"
;;

let test_latex_env () =
  let latex_env =
    List.find_map
      (function
        | Elt_Lesser_Element (Lelt_LaTeX_Environment { name; contents; _ }, _)
          -> Some (name, contents)
        | _ -> None)
      (all_elements (Doc.parse "\\begin{equation}\nE=mc^2\n\\end{equation}\n"))
  in
  match latex_env with
  | Some ("equation", Some body) -> check_bool "raw body" true (body = "E=mc^2")
  | _ -> fail "expected a LaTeX environment"
;;

let test_footnote_def () =
  let doc =
    Doc.parse "[fn:1] A short footnote.\n\n[fn:2] Longer.\n\nStill 2.\n"
  in
  let labels =
    List.filter_map
      (function
        | Elt_Greater_Element (Gelt_Footnote_Definition { label; _ }, _) ->
          Some label
        | _ -> None)
      (all_elements doc)
  in
  check_bool "two footnote definitions" true (labels = [ "1"; "2" ])
;;

let test_affiliated () =
  let doc = Doc.parse "#+CAPTION: hi\n#+NAME: t1\n| a |\n" in
  let aff =
    List.find_map
      (function
        | Elt_Greater_Element (Gelt_Table _, aff) when aff <> [] -> Some aff
        | _ -> None)
      (all_elements doc)
  in
  match aff with
  | Some [ { key = "CAPTION"; _ }; { key = "NAME"; _ } ] -> ()
  | _ -> fail "expected CAPTION and NAME affiliated to the table"
;;

let test_planning () =
  match Doc.parse "* Task\nSCHEDULED: <2026-07-05 Sun>\n" with
  | [ Elt_Heading
        { planning =
            Some
              { plannings =
                  [ { keyword = `Scheduled; timestamp = Active { day = 5; _ } }
                  ]
              }
        ; _
        }
    ] -> ()
  | _ -> fail "expected planning attached to the heading"
;;

let test_clock () =
  let doc = Doc.parse "clock: => 1:30\n" in
  let clock =
    List.find_map
      (function
        | Elt_Lesser_Element (Lelt_Clock c, _) -> Some c
        | _ -> None)
      (all_elements doc)
  in
  match clock with
  | Some (Duration { hh = 1; mm = 30 }) -> ()
  | _ -> fail "expected a clock duration"
;;

let test_clock_range () =
  let doc =
    Doc.parse "CLOCK: [2024-10-12 Sat 09:00]--[2024-10-12 Sat 10:00] => 1:00\n"
  in
  let clock =
    List.find_map
      (function
        | Elt_Lesser_Element (Lelt_Clock c, _) -> Some c
        | _ -> None)
      (all_elements doc)
  in
  match clock with
  | Some
      (Timestamp (Inactive_Range ({ hour = Some 9; _ }, { hour = Some 10; _ })))
    -> ()
  | _ -> fail "expected a clock timestamp range"
;;

(* ------------------------------------------------------------------ *)

let () =
  let open Alcotest in
  let tc name f = test_case name `Quick f in
  run
    "Orgaf"
    [ ( "objects"
      , [ tc "plain text" test_plain_text
        ; tc "bold" test_bold
        ; tc "no mid-word emphasis" test_no_bold_midword
        ; tc "link with description" test_link_with_desc
        ; tc "entity" test_entity
        ; tc "line break" test_line_break
        ; tc "export snippet" test_export_snippet
        ; tc "inline source block" test_inline_source
        ; tc "latex fragment" test_latex_fragment
        ; tc "footnote reference" test_footnote_reference
        ; tc "inline timestamp" test_inline_timestamp
        ; tc "statistics cookie" test_statistics_cookie
        ; tc "percent cookie" test_percent_cookie
        ; tc "target" test_target
        ; tc "radio stays plain" test_radio_stays_plain
        ; tc "subscript" test_subscript
        ; tc "no bare subscript" test_no_bare_subscript
        ] )
    ; ( "structure"
      , [ tc "headline components" test_headline_components
        ; tc "headline nesting" test_nesting
        ; tc "src block raw body" test_src_block_raw
        ; tc "property drawer" test_property_drawer
        ; tc "plain list" test_list
        ; tc "table" test_table
        ; tc "keyword" test_keyword
        ; tc "latex environment" test_latex_env
        ; tc "footnote definition" test_footnote_def
        ; tc "affiliated keywords" test_affiliated
        ; tc "planning" test_planning
        ; tc "clock duration" test_clock
        ; tc "clock range" test_clock_range
        ] )
    ]
;;
