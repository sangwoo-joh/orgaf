open Orgaf.Model

let pp_object fmt = function
  | Obj_Plain_text s -> Format.fprintf fmt "Plain_text(%S)" s
  | Obj_Entity { name } -> Format.fprintf fmt "Entity(%s)" name
  | Obj_Link _ -> Format.fprintf fmt "Link(...)"
  | obj ->
    Format.fprintf fmt "%s" (Sexplib.Sexp.to_string (sexp_of_object_ obj))
;;

let object_ =
  let module M = struct
    type t = object_

    let pp = pp_object
    let equal = ( = )
  end
  in
  (module M : Alcotest.TESTABLE with type t = M.t)
;;
