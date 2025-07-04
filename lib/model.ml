(* TODO: make types more rich *)

open Sexplib.Std

type element =
  (* syntactic components that at the same or greater than a paragraph *)
  | Elt_Heading of heading
  | Elt_Zeroth_Section of zeroth_section
  | Elt_Section of section
  | Elt_Greater_Element of greater_element * affiliated_keyword list
  | Elt_Lesser_Element of lesser_element * affiliated_keyword list
[@@deriving sexp]

and object_ =
  | Obj_Plain_text of string
  | Obj_Entity of entity
  | Obj_Latex_Fragment of latex_fragment
  | Obj_Export_Snippet of export_snippet
  | Obj_Footnote_Reference of footnote_reference
  | Obj_Citation of citation
  | Obj_Citation_Reference of citation_reference
  | Obj_Inline_Babel_Call of inline_babel_call
  | Obj_Inline_Source_Block of inline_source_block
  | Obj_Line_Break
  | Obj_Link of link
  | Obj_Macro of macro
  | Obj_Target of target
  | Obj_Radio_Target of radio_target
  | Obj_Statistics_Cookie of statistics_cookie
  | Obj_Subscript of script
  | Obj_Superscript of script
  | Obj_Table_Cell of table_cell
  | Obj_Timestamp of timestamp
  | Obj_Text_Markup of text_markup

and heading =
  { level : int
  ; keyword : string option
  ; priority : string option
  ; comment : bool
  ; title : string option
  ; tags : string list
  ; section : section option
  ; children : heading list (* is this allowed? *)
  }

and zeroth_section =
  { (* All elements before the first heading in a document lie in a special section called the *zeroth section*. *)
    section : section
  ; property_drawer : string option
  ; comments : string option
  }

and section =
  { (* Sections contain one or more non-heading elements. *)
    contents : element list (* except for heading *)
  }

and greater_element =
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
  | Gelt_Property_Drawer of { contents : node_property list }
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
      { contents : heading
      ; optional_elements : element list
        (* when level >= org-inlinetask-min-level && no optional components && END *)
      }
  | Gelt_Item of item
  | Gelt_Plain_List of
      { subtype : [ `Ordered | `Descriptive | `Unordered ]
      ; contents : item list
      ; level : int
      }
  | Gelt_Table of
      { subtype : [ `Org | `Table_dot_el ]
      ; rows : table_row list
      ; formulas : string list
      }

and lesser_element =
  | Lelt_Block of block
  | Lelt_Clock of clock
  | Lelt_Diary_Sexp of string
  | Lelt_Planning of planning
  | Lelt_Comment of string
  | Lelt_Fixed_Width_Area of string
  | Lelt_Horizontal_Rule of string
  | Lelt_Keyword of string * string
  | Lelt_LaTeX_Environment of string
  | Lelt_Node_Property of string
  | Lelt_Paragraph of string
  | Lelt_Table_Row of string

and block =
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

and clock =
  | Inactive_Timestamp of timestamp
  | Inactive_Timestamp_Range of timestamp
  | Duration of
      { hh : int
      ; mm : int
      }

and planning =
  { heading : heading
  ; plannings : planning_info list
  }

and planning_info =
  { keyword : [ `Deadline | `Scheduled | `Closed ]
  ; timestamp : timestamp
  }

and entity = string
and latex_fragment = string
and export_snippet = string
and footnote_reference = string
and citation = string
and citation_reference = string
and inline_babel_call = string
and inline_source_block = string
and link = string
and macro = string
and target = string
and radio_target = string
and statistics_cookie = string
and script = string
and timestamp = string
and text_markup = string

and affiliated_keyword =
  { key : string
  ; optval : string option
  ; value_raw : string
  ; value_parsed : object_ list option
  }

and node_property =
  { name : string
  ; value : string option
  }

and item =
  { bullet : string
  ; counter_set : string option
  ; check_box : [ `Whitespace | `X | `Hyphen ] option
  ; tag : object_ list
  ; contents : element list
  }

and table_row =
  { subtype : [ `Standard | `Rule ]
  ; cells : table_cell list
  }

and table_cell =
  { contents : object_ list
  ; spaces : string option
  ; eol : string
  }

type t = element list
