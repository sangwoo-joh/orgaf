let is_space = function
  | ' ' -> true
  | _ -> false
;;

let is_blank = function
  | ' ' | '\t' -> true
  | _ -> false
;;

let is_newline = function
  | '\n' | '\r' -> true
  | _ -> false
;;

let is_whitespace c =
  (* Although the org syntax defines this as "blank lines" in section 2.2., it
     uses "whitespaces" in other places. So we adapt it as function name. *)
  is_blank c || is_newline c
;;

let is_numeric = function
  | '0' .. '9' -> true
  | _ -> false
;;

let is_alpha = function
  | 'a' .. 'z' | 'A' .. 'Z' -> true
  | _ -> false
;;

let is_alpha_numeric = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true
  | _ -> false
;;

let is_star = function
  | '*' -> true
  | _ -> false
;;

let is_special_char = function
  | '*'
  | '/'
  | '_'
  | '+'
  | '~'
  | '='
  | '['
  | '<'
  | '{'
  | '\\'
  | '@'
  | '$'
  | '\n'
  | '\r' -> true
  | _ -> false
;;

let is_path_char = function
  | ' ' | '\t' | '\n' | '\r' | '(' | ')' | '[' | ']' | '<' | '>' -> false
  | _ -> true
;;

let is_punct_char = function
  (* https://support.google.com/a/answer/1371415?hl=en *)
  | '!'
  | '"'
  | '#'
  | '$'
  | '%'
  | '&'
  | '\''
  | '('
  | ')'
  | '*'
  | '+'
  | ','
  | '\\'
  | '-'
  | '/'
  | ':'
  | ';'
  | '<'
  | '='
  | '>'
  | '?'
  | '@'
  | '['
  | ']'
  | '^'
  | '_'
  | '`'
  | '{'
  | '|'
  | '}' -> true
  | _ -> false
;;
