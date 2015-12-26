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

  let rec send_buf t addr buf = match Iobuf.length buf with
    | 0 -> return ()
    | l -> begin
      let s = min l packet_size in
      let head = Iobuf.sub_shared ~pos:0 ~len:s buf in
      let tail = Iobuf.sub_shared ~pos:s ~len:(l - s) buf in
      send_packet t addr head >>= fun () ->
      send_buf t addr tail
    end
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
