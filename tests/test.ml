open Orgaf.Parse

let test_plain_text () =
  let input = "just text" in
  let result = Angstrom.parse_string ~consume:All parse_plain_text input in
  match result with
  | Ok (Obj_Plain_text text) ->
    Alcotest.(check string) "plain text" "just text" text
  | _ -> Alcotest.fail "Expected plain text"
;;

let () =
  let open Alcotest in
  run
    "Orgaf Tests"
    [ "Skip", [ test_case "Plain text parsing" `Quick test_plain_text ] ]
;;
