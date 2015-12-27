open Core.Std
open Async.Std

let rec handle_outgoing ?pending_update ?pending_packet
                        resolver dev txer =
  let u = match pending_update with
  | Some x -> x | None -> (Resolve.update resolver) in
  let p = match pending_packet with
  | Some x -> x | None -> (Tundev.read_packet dev) in
  choose [
    choice u (function
      | `Eof -> raise (Failure "Resolver was closed")
      | `Ok resolver -> `New_resolver resolver);
    choice p (fun x -> `Packet x)
  ] >>= function
  | `New_resolver resolver ->
    handle_outgoing ?pending_packet:(Some p) resolver dev txer
  | `Packet packet -> (
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
    _send packet >>= fun () ->
    handle_outgoing ?pending_update:(Some u) resolver dev txer
  )

let handle_incoming rxer w =
  let f buf addr = Writer.write w (Iobuf.to_string buf) in
  Tunnel.Rxer.start rxer f

let addr_to_inet ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let setup_resolver ~remote_host ~remote_port
                   ~hosts_file
                   ~hosts_url ~hosts_url_interval =
  match (remote_host, hosts_file, hosts_url) with
  | (Some host, None, None) -> Resolve.from_host host remote_port
  | (None, Some file, None) -> Resolve.from_file file
  | (None, None, Some url)  ->
    let i = Time.Span.of_sec hosts_url_interval in
    Resolve.from_url i url
  | _ -> raise (Failure ("You must choose exactly one method to " ^
                         "resolve destinations."))

let main local_address local_port
         remote_host remote_port
         hosts_file
         hosts_url hosts_url_interval
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
                   ~hosts_url ~hosts_url_interval
    >>= fun resolver ->
    let txer = Tunnel.Txer.create () in
    handle_outgoing resolver tundev txer
  in
  ignore (start_receiving ());
  ignore (start_sending ());

  never_returns (Scheduler.go ())

let () =
  Options.eval main
