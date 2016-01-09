open Core.Std
open Async.Std

let _send_destination_host_unreachable w packet =
  let dst = Tundev.Packet.source packet in
  let src = Tundev.Packet.destination packet in
  return (
  packet |> Icmp.destination_host_unreachable
         |> Icmp.to_bitstring
         |> Bitstring.string_of_bitstring
         |> Ip.V4.create Ip.Icmp ~src ~dst
         |> Ip.V4.to_bitstring
         |> Bitstring.string_of_bitstring
         |> Writer.write w
  )

let _send resolver txer dev packet =
  packet |> Tundev.Packet.destination
         |> Resolve.resolve resolver
         |> function
  | None -> begin
    printf "No destination for %s\n%!"
      (packet |> Tundev.Packet.destination
              |> Unix.Inet_addr.inet4_addr_of_int32
              |> Unix.Inet_addr.to_string);
    _send_destination_host_unreachable (Tundev.writer dev) packet
  end
  | Some d ->
    let addr = Resolve.Destination.to_inet d in
    let iobuf = packet |> Tundev.Packet.raw |> Iobuf.of_string in
    Tunnel.Txer.send_packet txer addr iobuf

let rec handle_outgoing ?pending_update ?pending_packet
                        resolver dev txer =
  let u = match pending_update with
  | Some x -> x | None -> (Resolve.update resolver) in
  let p = match pending_packet with
  | Some x -> x | None -> (Tundev.read_packet dev) in
  choose [
    choice u (function
      | `Eof -> failwith "Resolver was closed"
      | `Ok resolver -> `New_resolver resolver);
    choice p (fun x -> `Packet x)
  ] >>= function
  | `New_resolver resolver ->
    handle_outgoing ?pending_packet:(Some p) resolver dev txer
  | `Packet packet -> begin
    _send resolver txer dev packet >>= fun () ->
    handle_outgoing ?pending_update:(Some u) resolver dev txer
  end

let handle_incoming rxer w =
  let f buf addr =
    let str = Iobuf.to_string buf in
    let bs = Bitstring.bitstring_of_string str in
    try
      let _ = Ip.V4.of_bitstring bs  in
      Writer.write w (Iobuf.to_string buf)
    with
    | e ->
      printf "Received an invalid IPv4 packet from %s: %s (%s)\n%!"
        (Socket.Address.Inet.to_string addr)
        (Exn.to_string e)
        Iobuf.(to_string_hum ~bounds:`Window buf)
  in
  Tunnel.Rxer.start rxer f

let addr_to_inet ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let setup_resolver ~remote_host ~remote_port
                   ~hosts_file
                   ~hosts_url ~hosts_url_interval ~ca_file ~ca_path =
  match (remote_host, hosts_file, hosts_url) with
  | (Some host, None, None) -> Resolve.from_host host remote_port
  | (None, Some file, None) -> Resolve.from_file file
  | (None, None, Some url)  ->
    let interval = Time.Span.of_sec hosts_url_interval in
    Resolve.from_url ~interval ~ca_file ~ca_path url
  | _ -> failwith ("You must choose exactly one method to " ^
                   "resolve destinations.")

let main local_address local_port
         remote_host remote_port
         hosts_file
         hosts_url hosts_url_interval ca_file ca_path
         dev =
  let tundev = Tundev.create dev in
  Core.Std.printf "Created device %s\n%!" (Tundev.name tundev);
  let start_receiving () =
    let address = addr_to_inet local_address local_port in
    Core.Std.printf "Started listening on %s\n%!"
      (Unix.Socket.Address.Inet.to_string address);
    Tunnel.Rxer.create address >>= fun rxer ->
    handle_incoming rxer (Tundev.writer tundev)
  in
  let start_sending () =
    setup_resolver ~remote_host ~remote_port
                   ~hosts_file
                   ~hosts_url ~hosts_url_interval ~ca_file ~ca_path
    >>= fun resolver ->
    let txer = Tunnel.Txer.create () in
    handle_outgoing resolver tundev txer
  in
  ignore (start_receiving ());
  ignore (start_sending ());

  never_returns (Scheduler.go ())

let () =
  Options.eval main
