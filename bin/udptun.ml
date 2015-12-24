open Core.Std
open Async.Std

let copy_reader_to_txer r txer =
  let buf = String.create Tunnel.Txer.packet_size in
  let rec copier () =
    Reader.read r buf >>= function
    | `Eof -> return ()
    | `Ok l -> begin
      let iobuf = Iobuf.(sub_shared ~len:l (of_string buf)) in
      Tunnel.Txer.send_buf txer iobuf >>= fun () ->
      copier ()
    end
  in
  copier ()

let copy_rxer_to_writer rxer w =
  let f buf addr = Writer.write w (Iobuf.to_string buf) in
  Tunnel.Rxer.start rxer f

let to_address ip port =
  let a = Unix.Inet_addr.of_string ip in
  Unix.Socket.Address.Inet.create a ~port

let main local_address local_port remote_address remote_port =
  let tundev = Tundev.create () in
  let start_receiving () =
    let address = to_address local_address local_port in
    Tunnel.Rxer.create address >>= fun rxer ->
    copy_rxer_to_writer rxer (Tundev.writer tundev)
  in
  let start_sending () =
    let address = to_address remote_address remote_port in
    Tunnel.Txer.connect address >>= fun txer ->
    copy_reader_to_txer (Tundev.reader tundev) txer
  in
  ignore (start_receiving ());
  ignore (start_sending ());
  
  never_returns (Scheduler.go ())
