open Core.Std
open Async.Std

module Tun = struct
  type t = {
    name : string;
    reader : Reader.t;
    writer : Writer.t;
  }

  let create () =
    let file, name = Tuntap.opentun () in
    let fd = Fd.create Fd.Kind.Char file (Info.of_string name) in
    let reader = Reader.create fd in
    let writer = Writer.create fd in
    {name; reader; writer}

  let reader t = t.reader
  let writer t = t.writer
  let name t = t.name

  let close t = Tuntap.closetun t.name
end

module UdpAsync = struct
  module Client = struct
    type t = {
      fd : Fd.t;
      address : Unix.Socket.Address.Inet.t;
    }

    let connect address =
      let socket = Unix.Socket.(create Type.udp) in
      Unix.Socket.connect socket address
      >>| (fun socket ->
        let fd = Unix.Socket.fd socket in
        { fd; address }
      )

    let sendto t data =
      let buf = Iobuf.of_string data in
      let sender = Or_error.ok_exn (Udp.sendto ()) in
      try_with ~extract_exn:true (fun () -> sender t.fd buf t.address)
      >>| function
      | Ok () -> ()
      | Error (Unix.Unix_error (err, _, _)) ->
          printf "Could not sendto %s: %s\n%!"
            (Unix.Socket.Address.Inet.to_string t.address)
            (Core.Std.Unix.error_message  err)
      | Error e -> raise e
  end
end

let to_address ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let main local_address local_port remote_address remote_port =
  let start_sending () =
    let address = to_address remote_address remote_port in
    UdpAsync.Client.connect address >>= (fun client ->
      let rec keep_sending () =
        printf "Sending message\n%!";
        UdpAsync.Client.sendto client "Hello World!" >>= fun () ->
        after (Time.Span.of_sec 1.0) >>= fun () ->
        keep_sending ()
      in
      keep_sending ();
    )
  in
  ignore (start_sending ());
  
  never_returns (Scheduler.go ())
