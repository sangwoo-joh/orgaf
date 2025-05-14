module A = Angstrom

module P = struct
  let is_blank = function
    | ' ' | '\t' | '\n' | '\r' -> true
    | _ -> false
  ;;

  let is_digit = function
    | '0' .. '9' -> true
    | _ -> false
  ;;
end

let unit = A.return ()

let digit =
  let open A in
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
