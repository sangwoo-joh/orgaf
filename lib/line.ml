(** Pass 1 works line-by-line, so it operates on [Line.t] rather than raw
    strings. Each line records its indentation and its indent-stripped content so
    the scanner can dispatch on leading patterns without re-measuring blanks. *)

type t =
  { raw : string (* original line, without the newline *)
  ; indent : int (* leading blank columns; tab counts as 8 (FEATURE.md) *)
  ; content : string (* [raw] with leading blanks stripped *)
  ; blank : bool (* [content] is empty *)
  }

let measure_indent raw =
  let n = String.length raw in
  let rec go i col =
    if i >= n
    then i, col
    else (
      match raw.[i] with
      | ' ' -> go (i + 1) (col + 1)
      | '\t' -> go (i + 1) (col + 8)
      | _ -> i, col)
  in
  go 0 0
;;

let make raw =
  let off, col = measure_indent raw in
  let content = String.sub raw off (String.length raw - off) in
  let blank = content = "" in
  { raw; indent = (if blank then 0 else col); content; blank }
;;

let strip_cr l =
  let n = String.length l in
  if n > 0 && l.[n - 1] = '\r' then String.sub l 0 (n - 1) else l
;;

(** Split a document into lines, handling both [\n] and [\r\n]. A single trailing
    newline does not produce an extra empty line (it belongs to the last line's
    element per the Org spec). *)
let split (s : string) : t list =
  let lines = String.split_on_char '\n' s in
  let lines =
    match List.rev lines with
    | "" :: rest -> List.rev rest
    | _ -> lines
  in
  List.map (fun l -> make (strip_cr l)) lines
;;
