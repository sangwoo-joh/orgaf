(* TODO: make types more rich *)

open Sexplib.Std

type element =
  (* syntactic components that at the same or greater than a paragraph *)
  | Elt_Heading of heading_info
  | Elt_Zeroth_Section of zeroth_section_info
  | Elt_Section of section_info
  | Elt_Greater_Element of greater_element_info * affiliated_keyword_info list
  | Elt_Lesser_Element of lesser_element_info * affiliated_keyword_info list
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
  { level : int
  ; keyword : string option
  ; priority : string option
  ; comment : bool
  ; title : string option
  ; tags : string list
  ; section : section_info option
  ; children : heading_info list (* is this allowed? *)
  }

and zeroth_section_info =
  { (* All elements before the first heading_info in a document lie in a special section_info called the *zeroth section_info*. *)
    section : section_info
  ; property_drawer : string option
  ; comments : string option
  }

and section_info =
  { (* Sections contain one or more non-heading_info elements. *)
    contents : element list (* except for heading_info *)
  }

and greater_element_info =
  | Gelt_Greater_Block of
      { name : string
      ; subtype : [ `Center | `Quote | `Special of string ]
      ; parameters : string option
      ; contents : element list
      }
  | Gelt_Drawer of
      { name : string
      ; contents : element list (* except another drawer *)
      }
  | Gelt_Property_Drawer of { contents : node_property_info list }
  | Gelt_Dynamic_Block of
      { name : string
      ; parameters : string option
      ; contents : element list
      }
  | Gelt_Footnote_Definition of
      { label : string
      ; contents : element list
      }
  | Gelt_Inlinetask of
      { contents : heading_info
      ; optional_elements : element list
      (* when level >= org-inlinetask-min-level && no optional components && END *)
      }
  | Gelt_Item of item_info
  | Gelt_Plain_List of
      { subtype : [ `Ordered | `Descriptive | `Unordered ]
      ; contents : item_info list
      ; level : int
      }
  | Gelt_Table of
      { subtype : [ `Org | `Table_dot_el ]
      ; rows : table_row_info list
      ; formulas : string list
      }

and lesser_element_info =
  | Lelt_Block of block_info
  | Lelt_Clock of clock_info
  | Lelt_Diary_Sexp of string
  | Lelt_Planning of planning_info
  | Lelt_Comment of string
  | Lelt_Fixed_Width_Area of string
  | Lelt_Horizontal_Rule
  | Lelt_Keyword of
      { key : string
      ; value : string
      }
  | Lelt_LaTeX_Environment of
      { name : string
      ; extra : string option
      ; contents : string option
      }
  | Lelt_Node_Property of node_property_info
  | Lelt_Paragraph of string
  | Lelt_Table_Row of table_row_info

and block_info =
  | Comment_Block of
      { data : string option
      ; contents : string option
      }
  | Example_Block of
      { data : string option
      ; contents : string option
      }
  | Export_Block of
      { data : string (* mandatory *)
      ; contents : string option
      }
  | Source_Block of
      { language : string
      ; switches : string
      ; arguments : string
      ; contents : string option
      }
  | Verse_Block of
      { data : string option
      ; contents : object_ list
      }

and clock_info =
  | Timestamp of timestamp_info (* intacive or inactive range only *)
  | Duration of
      { hh : int
      ; mm : int
      }

and planning_info =
  { heading : heading_info
  ; plannings : planning_data list
  }

and planning_data =
  { keyword : [ `Deadline | `Scheduled | `Closed ]
  ; timestamp : timestamp_info
  }

and entity_info =
  { name : string
  ; post : string
  ; spaces : string
  }

and latex_fragment_info =
  { name : string
  ; brackets : string option
  ; contents : string
  }

and export_snippet_info =
  { backend : string
  ; value : string option
  }

and footnote_reference_info =
  { label : string
  ; definition : object_ list
  }

and citation_info = string
and citation_reference_info = string
and inline_babel_call_info = string
and inline_source_block_info = string
and link_info = string
and macro_info = string
and target_info = string
and radio_target_info = string
and statistics_cookie_info = string

and script_info =
  { char : char
  ; script : script_data
  }

and script_data =
  | Asterisk
  | Structured of object_ list
  | Pattern of
      { sign : char option
      ; chars : string option
      ; final : char
      }

and timestamp_info =
  | Active of timestamp_data
  | Inactive of timestamp_data
  | Active_Range of timestamp_data * timestamp_data
  | Inactive_Range of timestamp_data * timestamp_data
  | Diary of string (* sexp *)

and timestamp_data =
  { year : int
  ; month : int
  ; day : int
  ; day_name : string option
  ; hour : int option
  ; minute : int option
  ; repeater_raw : string option (* TODO *)
  ; delay_raw : string option (* TODO *)
  }

and text_markup_info =
  { marker :
      [ `Bold | `Italic | `Underline | `Verbatim | `Code | `Strike_Through ]
  ; contents : [ `String of string | `Standard of object_ list ]
  }

and affiliated_keyword_info =
  { key : string
  ; optval : string option
  ; value_raw : string
  ; value_parsed : object_ list option
  }

and node_property_info =
  { name : string
  ; value : string option
  }

and item_info =
  { bullet : string
  ; counter_set : string option
  ; check_box : [ `Whitespace | `X | `Hyphen ] option
  ; tag : object_ list
  ; contents : element list
  }

and table_row_info =
  { subtype : [ `Standard | `Rule ]
  ; cells : table_cell_info list
  }

and table_cell_info =
  { contents : object_ list
  ; spaces : string option
  ; eol : string
  }

type t = element list
