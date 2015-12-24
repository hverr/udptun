open Core.Std
open Async.Std

module Txer = struct
  type t = {
    fd : Fd.t;
    address : Unix.Socket.Address.Inet.t;
  }

  let packet_size = Udp.default_capacity

  let connect address =
    let socket = Unix.Socket.(create Type.udp) in
    Unix.Socket.connect socket address
    >>| (fun socket ->
      let fd = Unix.Socket.fd socket in
      { fd; address }
    )

  let send_packet t buf =
    let sender = Or_error.ok_exn (Udp.sendto ()) in
    try_with ~extract_exn:true (fun () -> sender t.fd buf t.address)
    >>| function
    | Ok () -> ()
    | Error (Unix.Unix_error (err, _, _)) ->
        printf "Could not sendto %s: %s\n%!"
          (Unix.Socket.Address.Inet.to_string t.address)
          (Core.Std.Unix.error_message  err)
    | Error e -> raise e

  let rec send_buf t buf = match Iobuf.length buf with
    | 0 -> return ()
    | l -> begin
      let s = min l packet_size in
      let head = Iobuf.sub_shared ~pos:0 ~len:s buf in
      let tail = Iobuf.sub_shared ~pos:s ~len:(l - s) buf in
      send_packet t head >>= fun () ->
      send_buf t tail
    end

  let send_string t data = send_buf t (Iobuf.of_string data)
end

module Rxer = struct
  type t = {
    fd : Fd.t;
    stopper : unit Ivar.t;
  }

  let create address =
    let socket = Unix.Socket.(create Type.udp) in
    Unix.Socket.bind socket address
    >>| fun socket -> {
      fd = Unix.Socket.fd socket;
      stopper = Ivar.create ();
    }

  let start t f =
    let config = Udp.Config.create ~stop:(Ivar.read t.stopper) () in
    Udp.recvfrom_loop ~config t.fd f

  let stop t = Ivar.fill t.stopper ()
end
