(** Public entry point: parse an Org document string into the {!Model} AST.

    Pass 1 ({!Scanner}) + structure assembly ({!Nest}); inline objects are filled
    by Pass 2 ({!Parse.parse_inline}) during the scan. *)

let parse (s : string) : Model.document =
  s |> Line.split |> Scanner.scan |> Nest.build
;;
