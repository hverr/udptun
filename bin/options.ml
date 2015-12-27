open Core.Std
open Cmdliner

let local_address =
  let doc = "The address to listen on." in
  Arg.(value & opt string "0.0.0.0" & info ["a"; "local-address"] ~doc)

let local_port =
  let doc = "The port to listen on." in
  let default_port = Resolve.Destination.default_port in
  Arg.(value & opt int default_port & info ["p"; "local-port"] ~doc)

let remote_host =
  let doc = "The remote host to connect to (for one-to-one tunnels)." in
  let flags = ["A"; "remote-address"] in
  Arg.(value & opt (some string) None & info flags ~doc)

let remote_port =
  let doc = "The remote port to connect to. (for one-to-one tunnels)." in
  let flags = ["P"; "remote-port"] in
  let default_port = Resolve.Destination.default_port in
  Arg.(value & opt int default_port & info flags ~doc)

let hosts_file =
  let doc = "File containing the remote hosts to connect to. (for " ^
    "one-to-many tunnels)." in
  let flags = ["hosts-file"] in
  Arg.(value & opt (some string) None & info flags ~doc)

let hosts_url =
  let doc = "URL serving the remote hosts to connect to. (for " ^
    "one-to-many tunnels)." in
  let flags = ["hosts-url"] in
  Arg.(value & opt (some string) None & info flags ~doc)

let hosts_url_interval =
  let doc = "Update interval when querying remote hosts from a URL." in
  let env = Arg.env_var "HOSTS_URL_INTERVAL" ~doc in
  let flags = ["hosts-url-interval"] in
  Arg.(value & opt float 300.0 & info flags ~env ~doc)

let device =
  let doc = "The name of the created tun device." in
  let flags = ["d"; "device"] in
  Arg.(value & opt string "tun%d" & info flags ~doc)

let term m = Term.(const m $
                   local_address $ local_port $
                   remote_host $ remote_port $
                   hosts_file $
                   hosts_url $ hosts_url_interval $
                   device)

let info =
  let doc = "create a udp tunnel on a newly created tun-device" in
  Term.info "udptun" ~doc

let eval main =
  match Term.eval (term main, info) with
  | `Error _ -> exit 1
  | _ -> exit 0
