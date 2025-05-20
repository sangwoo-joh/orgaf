open Angstrom

module Primitive = struct
  let is_blank = function
    | ' ' | '\t' -> true
    | _ -> false
  ;;

  let is_newline = function
    | '\n' | '\r' -> true
    | _ -> false
  ;;

  let is_digit = function
    | '0' .. '9' -> true
    | _ -> false
  ;;

  let is_star = function
    | '*' -> true
    | _ -> false
  ;;
end

module P = Primitive

let unit = return ()

let digit =
  satisfy P.is_digit
  >>| function
  | '0' -> 0
  | '1' -> 1
  | '2' -> 2
  | '3' -> 3
  | '4' -> 4
  | '5' -> 5
  | '6' -> 6
  | '7' -> 7
  | '8' -> 8
  | '9' -> 9
  | _ -> assert false
;;

let stars =
  take_while P.is_star
  >>= fun raw_stars ->
  if String.length raw_stars = 0
  then fail "no stars"
  else if String.length raw_stars > 6
  then fail "too many stars"
  else return (String.length raw_stars)
;;

let colon = char ':'
let blanks = skip_while P.is_blank
let optional_blanks = option () blanks
let eol = end_of_line
let eol_or_eof = eol <|> end_of_input
let take_till_eol = take_till P.is_newline
let blank_line = blanks *> eol
