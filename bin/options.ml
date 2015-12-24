open Core.Std
open Cmdliner

let default_port = 7777

let local_address =
  let doc = "The address to listen on." in
  Arg.(value & opt string "0.0.0.0" & info ["a"; "local-address"] ~doc)

let local_port =
  let doc = "The port to listen on." in
  Arg.(value & opt int default_port & info ["p"; "local-port"] ~doc)

let remote_address =
  let doc = "The remote address to connect to." in
  let flags = ["A"; "remote-address"] in
  Arg.(required & opt (some string) None & info flags ~doc)

let remote_port =
  let doc = "The remote port to connect to." in
  let flags = ["P"; "remote-port"] in
  Arg.(value & opt int default_port & info flags ~doc)

let term m = Term.(const m $
                   local_address $
                   local_port $
                   remote_address $
                   remote_port)

let info =
  let doc = "create a udp tunnel on a newly created tun-device" in
  Term.info "udptun" ~doc

let eval main =
  match Term.eval (term main, info) with
  | `Error _ -> exit 1
  | _ -> exit 0
