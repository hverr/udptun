open Core.Std
open Async.Std

let to_address ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let main local_address local_port remote_address remote_port =
  let start_receiving () =
    let handle_packet buf addr =
      printf "Got packet from %s\n%!"
        (Unix.Socket.Address.Inet.to_string addr)
    in
    let address = to_address local_address local_port in
    Tunnel.Rxer.create address >>= fun rxer ->
    Tunnel.Rxer.start rxer handle_packet
  in
  let start_sending () =
    let address = to_address remote_address remote_port in
    Tunnel.Txer.connect address >>= (fun txer ->
      let rec keep_sending () =
        printf "Sending message\n%!";
        Tunnel.Txer.send_packet txer "Hello World!" >>= fun () ->
        after (Time.Span.of_sec 1.0) >>= fun () ->
        keep_sending ()
      in
      keep_sending ();
    )
  in
  ignore (start_receiving ());
  ignore (start_sending ());
  
  never_returns (Scheduler.go ())
