open Sexplib.Std

type element =
  (* syntactic components that at the same or greater than a paragraph *)
  | Elt_Heading of heading_info
  | Elt_Zeroth_Section of zeroth_section_info
  | Elt_Section of section_info
  | Elt_Greater_Element of greater_element_info
  | Elt_Lesser_Element of lesser_element_info
[@@deriving sexp]

and object_ =
  | Obj_Plain_text of string
  | Obj_Entity of entity_info
  | Obj_Latex_Fragment of latex_fragment_info
  | Obj_Export_Snippet of export_snippet_info
  | Obj_Footnote_Reference of footnote_reference_info
  | Obj_Citation of citation_info
  | Obj_Citation_Reference of citation_reference_info
  | Obj_Inline_Babel_Call of inline_babel_call_info
  | Obj_Inline_Source_Block of inline_source_block_info
  | Obj_Line_Break
  | Obj_Link of link_info
  | Obj_Macro of macro_info
  | Obj_Target of target_info
  | Obj_Radio_Target of radio_target_info
  | Obj_Statistics_Cookie of statistics_cookie_info
  | Obj_Subscript of script_info
  | Obj_Superscript of script_info
  | Obj_Table_Cell of table_cell_info
  | Obj_Timestamp of timestamp_info
  | Obj_Text_Markup of text_markup_info

and heading_info =
  { stars : int
  ; keyword : string option
  ; priority : string option
  ; comment : bool
  ; title : string option
  ; tags : string list
  ; section : section_info option
  }

and zeroth_section_info =
  { (* All elements before the first heading in a document lie in a special section called the *zeroth section*. *)
    section : section_info
  ; property_drawer : string option
  ; comments : string option
  }

and section_info =
  { (* Sections contain one or more non-heading elements. *)
    content : element list (* except for heading *)
  }

(* TODO: make types more rich *)
and greater_element_info =
  | Gelt_Greater_Block of string
  | Gelt_Drawer of string
  | Gelt_Property_Drawer of string
  | Gelt_Dynamic_Block of string
  | Gelt_Footnote_Definition of string
  | Gelt_Inlinetask of string
  | Gelt_Item of string
  | Gelt_Plain_List of string
  | Gelt_Table of string

and lesser_element_info =
  | Lelt_Block of string
  | Lelt_Clock of string
  | Lelt_Diary_Sexp of string
  | Lelt_Planning of string
  | Lelt_Comment of string
  | Lelt_Fixed_Width_Area of string
  | Lelt_Horizontal_Rule of string
  | Lelt_Keyword of string * string
  | Lelt_LaTeX_Environment of string
  | Lelt_Node_Property of string
  | Lelt_Paragraph of string
  | Lelt_Table_Row of string

and entity_info = string
and latex_fragment_info = string
and export_snippet_info = string
and footnote_reference_info = string
and citation_info = string
and citation_reference_info = string
and inline_babel_call_info = string
and inline_source_block_info = string
and link_info = string
and macro_info = string
and target_info = string
and radio_target_info = string
and statistics_cookie_info = string
and script_info = string
and table_cell_info = string
and timestamp_info = string
and text_markup_info = string

type t = element list
