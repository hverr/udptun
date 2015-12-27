open Core.Std
open Async.Std

module Txer = struct
  type t = Fd.t
  let packet_size = Udp.default_capacity

  let create () =
    Unix.Socket.(create Type.udp) |> Unix.Socket.fd

  let send_packet t addr buf =
    let sender = Or_error.ok_exn (Udp.sendto ()) in
    try_with ~extract_exn:true (fun () -> sender t buf addr)
    >>| function
    | Ok () -> ()
    | Error (Unix.Unix_error (err, _, _)) ->
        printf "Could not sendto %s: %s\n%!"
          (Unix.Socket.Address.Inet.to_string addr)
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
