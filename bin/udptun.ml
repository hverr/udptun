open Core.Std
open Async.Std

let copy_packets_to_txer resolver dev txer =
  let rec copier () =
    Tundev.read_packet dev >>= fun packet ->
    let iobuf = Iobuf.of_string (Tundev.Packet.raw packet) in
    printf "Got packet for %s\n%!"
      (packet |> Tundev.Packet.destination |>
      Unix.Inet_addr.inet4_addr_of_int32 |>
      Unix.Inet_addr.to_string);
    let _send packet = packet |>
      Tundev.Packet.destination |>
      Resolve.resolve resolver |> function
      | None -> return (printf "No destination for %s\n%!"
          (Tundev.Packet.destination packet |>
          Unix.Inet_addr.inet4_addr_of_int32 |>
          Unix.Inet_addr.to_string))
      | Some d -> begin
        let addr = Resolve.Destination.to_inet d in
        Tunnel.Txer.send_buf txer addr iobuf
      end
    in
    _send packet >>=
    copier
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

let setup_resolver remote_host remote_port hosts_file =
  match (remote_host, hosts_file) with
  | (Some host, None) -> Resolve.from_host host remote_port
  | (None, Some file) -> raise (Failure "Not implemented.")
  | _ -> raise (Failure ("You must choose exactly one method to " ^
                         "resolve destinations."))

let main local_address local_port
         remote_host remote_port
         hosts_file
         dev =
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
    setup_resolver remote_host remote_port hosts_file
    >>= fun resolver ->
    let txer = Tunnel.Txer.create () in
    copy_packets_to_txer resolver tundev txer
  in
  ignore (start_receiving ());
  ignore (start_sending ());

  never_returns (Scheduler.go ())

let () =
  Options.eval main
