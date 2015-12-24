open Core.Std
open Async.Std

module Txer = struct
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
