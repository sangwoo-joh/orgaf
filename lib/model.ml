open Sexplib.Std

type element =
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
  { level : int (* stars *)
  ; keyword : string option (* case sensitive *)
  ; priority : char option
  ; comment : bool
  ; title : object_ list
  ; tags : string list
  ; section : section_info option
  ; planning : planning_info option
  ; children : heading_info list
  }

and zeroth_section_info =
  { section : section_info
  ; property_drawer : property_drawer_info option
  ; comments : lesser_element_info option
  }

and section_info = { contents : element list (* except for heading_info *) }

and greater_element_info =
  | Gelt_Greater_Block of greater_block_info
  | Gelt_Drawer of drawer_info
  | Gelt_Property_Drawer of property_drawer_info
  | Gelt_Dynamic_Block of dynamic_block_info
  | Gelt_Footnote_Definition of footnote_definition_info
  | Gelt_Inlinetask of inlinetask_info
  | Gelt_Item of item_info
  | Gelt_Plain_List of plain_list_info
  | Gelt_Table of table_info

and lesser_element_info =
  | Lelt_Block of block_info
  | Lelt_Clock of clock_info
  | Lelt_Diary_Sexp of string
  (* | Lelt_Planning of planning_info (* NOTE: planning is always dependent on heading *) *)
  | Lelt_Comment of string
  | Lelt_Fixed_Width_Area of string
  | Lelt_Horizontal_Rule
  | Lelt_Keyword of keyword_info
  | Lelt_LaTeX_Environment of latex_environment_info
  | Lelt_Node_Property of node_property_info
  | Lelt_Paragraph of object_ list (* standard set *)
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

and keyword_info =
  { key : string
  ; value : string
  }

and latex_environment_info =
  { name : string
  ; extra : string option
  ; contents : string option
  }

and planning_info = { plannings : planning_data list }

and planning_data =
  { keyword : [ `Deadline | `Scheduled | `Closed ]
  ; timestamp : timestamp_info
  }

and entity_info = { name : string }

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

and citation_info =
  { cite_style : string option (* TODO *)
  ; global_prefix : object_ list (* standard set *)
  ; referecnes : citation_reference_info list
  ; global_suffix : object_ list (* standard set *)
  }

and citation_reference_info =
  { key_prefix : object_ list (* minimal set *)
  ; key : string
  ; key_suffix : object_ list (* minimal set*)
  }

and inline_babel_call_info =
  { name : string
  ; arguments : string
  ; header1 : string option
  ; header2 : string option
  }

and inline_source_block_info =
  { language : string
  ; headers : string option
  ; body : string
  }

and link_info =
  | Radio_Link of
      { pre : char
      ; radio : object_ (* radio target or minimal set *)
      ; post : char
      }
  | Plain_Link of
      { pre : char
      ; linktype : string
      ; pathplain : string
      ; post : char
      }
  | Angle_Link of
      { linktype : string
      ; pathangle : string
      }
  | Regular_Link of
      { pathreg : annotated_pattern
      ; description : object_ list
      }

and annotated_pattern =
  | Hypertext of
      { linktype : string
        (* shell, news, mailto, https, http, ftp, help, file, elisp *)
      ; pathinner : string
      }
  | Id of string
  | Custom_Id of string
  | Code_Ref of string
  | Fuzzy_Or_File of string

and macro_info =
  { name : string
  ; arguments : string option
  }

and target_info = { target : string }
and radio_target_info = { contents : object_ list }

and statistics_cookie_info =
  { percent : int option
  ; num1 : int option
  ; num2 : int option
  }

and script_info =
  { char : char option (* HACK: to make parsing easier *)
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
  { markertype :
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

and greater_block_info =
  { name : string
  ; subtype : [ `Center | `Quote | `Special of string ]
  ; parameters : string option
  ; contents : element list
  }

and drawer_info =
  { name : string
  ; contents : element list (* except another drawer *)
  }

and property_drawer_info = { contents : node_property_info list }

and dynamic_block_info =
  { name : string
  ; parameters : string option
  ; contents : element list
  }

and footnote_definition_info =
  { label : string
  ; contents : element list
  }

and inlinetask_info =
  { contents : heading_info
  ; optional_elements : element list
    (* when level >= org-inlinetask-min-level && no optional components && END *)
  }

and plain_list_info =
  { subtype : [ `Ordered | `Descriptive | `Unordered ]
  ; contents : item_info list
  ; level : int
  }

and table_info =
  { subtype : [ `Org | `Table_dot_el ]
  ; rows : table_row_info list
  ; formulas : string list
  }

type document = element list
