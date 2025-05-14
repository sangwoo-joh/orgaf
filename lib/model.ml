open Sexplib.Std


type element =
  (* syntactic components that at the same or greater than a paragraph *)
  | Heading of heading_info
  | Zeroth_Section of zeroth_section_info
  | Section of section_info
  | Greater_Element of greater_element
  | Lesser_Element of lesser_element
[@@deriving sexp]

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

and greater_element =
  | Greater_Block of string
  | Drawer of string
  | Property_Drawer of string
  | Dynamic_Block of string
  | Footnote_Definition of string
  | Inlinetask of string
  | Item of string
  | Plain_List of string
  | Table of string

and lesser_element =
  | Block of string
  | Clock of string
  | Diary_Sexp of string
  | Planning of string
  | Comment of string
  | Fixed_Width_Area of string
  | Horizontal_Rule of string
  | Keyword of string * string
  | LaTeX_Environment of string
  | Node_Property of string
  | Paragraph of string
  | Table_Row of string
