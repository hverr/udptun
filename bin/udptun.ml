open Core.Std
open Async.Std

let copy_packets_to_txer dev txer =
  let rec copier () =
    Tundev.read_packet dev >>= fun packet ->
      let iobuf = Iobuf.of_string (Tundev.Packet.raw packet) in
      printf "Got packet for %s\n%!"
        (Unix.Inet_addr.to_string (Tundev.Packet.destination packet));
      Tunnel.Txer.send_buf txer iobuf >>= fun () ->
      copier ()
  in
  copier ()

let copy_rxer_to_writer rxer w =
  let f buf addr = Writer.write w (Iobuf.to_string buf) in
  Tunnel.Rxer.start rxer f

let addr_to_inet ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let host_to_inet host port =
  let open Core.Std.Unix.Host in
  let entry = getbyname_exn host in
  match Array.length entry.addresses with
  | 0 -> raise (Failure ("No host with name " ^ host))
  | _ -> begin
    let addr = Array.get entry.addresses 0 in
    Unix.Socket.Address.Inet.create addr ~port
  end

let main local_address local_port remote_host remote_port dev =
  let tundev = Tundev.create dev in
  Core.Std.printf "Created device %s\n%!" (Tundev.name tundev);
  let start_receiving () =
    let address = addr_to_inet local_address local_port in
    Core.Std.printf "Started listening on %s\n%!"
      (Unix.Socket.Address.Inet.to_string address);
    Tunnel.Rxer.create address >>= fun rxer ->
    copy_rxer_to_writer rxer (Tundev.writer tundev)
  in
  let start_sending () =
    let address = host_to_inet remote_host remote_port in
    Core.Std.printf "Started sending to %s\n%!"
      (Unix.Socket.Address.Inet.to_string address);
    Tunnel.Txer.connect address >>= fun txer ->
    copy_packets_to_txer tundev txer
  in
  ignore (start_receiving ());
  ignore (start_sending ());

  never_returns (Scheduler.go ())

let () =
  Options.eval main
