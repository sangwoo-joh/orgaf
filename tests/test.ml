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
        ] )
    ; ( "structure"
      , [ tc "headline components" test_headline_components
        ; tc "headline nesting" test_nesting
        ; tc "src block raw body" test_src_block_raw
        ; tc "property drawer" test_property_drawer
        ; tc "plain list" test_list
        ; tc "table" test_table
        ; tc "keyword" test_keyword
        ] )
    ]
;;
