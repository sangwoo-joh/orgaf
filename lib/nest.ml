(** Structure assembly (see docs/design.md §3.4).

    Turns the flat marker sequence from {!Scanner} into the document tree: the
    zeroth section, then headlines nested by level with their sections and
    planning attached. This is deliberately kept out of the scanner. *)

module M = Model
module S = Scanner

let take_elements flats =
  let rec go acc = function
    | S.FElement e :: tl -> go (e :: acc) tl
    | rest -> List.rev acc, rest
  in
  go [] flats
;;

let make_zeroth elems : M.zeroth_section_info =
  let property_drawer =
    List.find_map
      (function
        | M.Elt_Greater_Element (M.Gelt_Property_Drawer pd, _) -> Some pd
        | _ -> None)
      elems
  in
  let comments =
    List.find_map
      (function
        | M.Elt_Lesser_Element ((M.Lelt_Comment _ as c), _) -> Some c
        | _ -> None)
      elems
  in
  let is_extracted = function
    | M.Elt_Greater_Element (M.Gelt_Property_Drawer _, _) -> true
    | M.Elt_Lesser_Element (M.Lelt_Comment _, _) -> true
    | _ -> false
  in
  let contents = List.filter (fun e -> not (is_extracted e)) elems in
  { section = { contents }; property_drawer; comments }
;;

let rec build_heading (m : S.heading_marker) flats
  : M.heading_info * S.flat list
  =
  let planning, flats =
    match flats with
    | S.FPlanning p :: tl -> Some p, tl
    | _ -> None, flats
  in
  let section_elems, flats = take_elements flats in
  let children, flats = build_children m.level flats in
  let section =
    match section_elems with
    | [] -> None
    | contents -> Some ({ contents } : M.section_info)
  in
  ( { M.level = m.level
    ; keyword = m.keyword
    ; priority = m.priority
    ; comment = m.comment
    ; title = m.title
    ; tags = m.tags
    ; section
    ; planning
    ; children
    }
  , flats )

and build_children parent_level flats =
  match flats with
  | S.FHeading h :: tl when h.level > parent_level ->
    let child, flats = build_heading h tl in
    let siblings, flats = build_children parent_level flats in
    child :: siblings, flats
  | _ -> [], flats
;;

let rec tops flats =
  match flats with
  | [] -> []
  | S.FHeading h :: tl ->
    let hd, flats = build_heading h tl in
    M.Elt_Heading hd :: tops flats
  | S.FPlanning _ :: tl ->
    tops tl (* stray planning: not attached to a heading *)
  | S.FElement e :: tl -> M.Elt_Section { contents = [ e ] } :: tops tl
;;

let build (flats : S.flat list) : M.document =
  let zeroth_elems, flats = take_elements flats in
  let zeroth =
    match zeroth_elems with
    | [] -> []
    | elems -> [ M.Elt_Zeroth_Section (make_zeroth elems) ]
  in
  zeroth @ tops flats
;;
