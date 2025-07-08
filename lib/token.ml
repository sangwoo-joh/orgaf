open Sexplib.Std

type t =
  | Whitespace of string
  | New_Line
  | Horizontal_Rule (* --- *)
  | Check_Box of [ `Whitespace | `X | `Hyphen ]
  | Digit of int
  | Hash (* # *)
  | Plus (* + *)
  | Dollar (* $ *)
  | Double_Dollar (* $$ *)
  | Star of int (* * with the number *)
  | Hyphen (* - *)
  | Slash (* / *)
  | Backslash (* \ *)
  | Caret (* ^ *)
  | Under_Score (* _ *)
  | Equal (* = *)
  | Tilde (* ~ *)
  | Bang (* ! *)
  | Colon (* : *)
  | LBracket (* [ *)
  | RBracket (* ] *)
  | LAngle (* < *)
  | RAngle (* > *)
  | LLBracket (* [[ *)
  | RRBracket (* ]] *)
  | LLAngle (* << *)
  | RRAngle (* >> *)
  | LLLAngle (* <<< *)
  | RRRAngle (* >>> *)
  | LParen (* ( *)
  | RParen (* ) *)
  | LBrace (* { *)
  | RBrace (* } *)
  | LLLBrace (* {{{ *)
  | RRRBrace (* }}} *)
  | At (* @ *)
  | Double_At (* @@ *)
  | Pipe (* | *)
  | EOF
  | LaTeX_Begin of string (* \begin{NAME} *)
  | LaTeX_End of string (* \end{NAME} *)
  | Text of string
[@@deriving sexp]
