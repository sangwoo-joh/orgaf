module A = Angstrom

module Primitive = struct
  let is_blank = function
    | ' ' | '\t' | '\n' | '\r' -> true
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

let unit = A.return ()

let digit =
  let open A in
  A.satisfy P.is_digit
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
  let open A in
  A.take_while P.is_star
  >>= fun raw_stars ->
  if String.length raw_stars = 0
  then fail "no stars"
  else if String.length raw_stars > 6
  then fail "too many stars"
  else return (String.length raw_stars)
;;

let colon = A.char ':'
