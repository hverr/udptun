open Core.Std
open Async.Std

module Packet = struct
  type t = {
    destination : Unix.Inet_addr.t;
    raw : string;
  }

  let create destination raw = {destination; raw}
  let destination t = t.destination
  let raw t = t.raw
end

type t = {
  name : string;
  reader : Reader.t;
  writer : Writer.t;
}

let create devname =
  let file, name = Tuntap.opentun ~devname () in
  let fd = Fd.create Fd.Kind.Fifo file (Info.of_string name) in
  let reader = Reader.create fd in
  let writer = Writer.create fd in
  {name; reader; writer}

let reader t = t.reader
let writer t = t.writer
let name t = t.name

let close t = Tuntap.closetun t.name

let _read_ipv4 t hd =
  match%bitstring hd with
  | {|
      _ : 16;
      total_length : 16 : bigendian;
      _ : 64;
      _source : 32;
      dest : 32 : bigendian
    |} -> begin
      let addr = Unix.Inet_addr.inet4_addr_of_int32 dest in
      let r = total_length - (Bitstring.bitstring_length hd)/8 in
      let body = String.create r in
      Reader.really_read t.reader body >>| function
      | `Eof _ -> raise (Failure "EOF")
      | `Ok ->
        let full = (Bitstring.string_of_bitstring hd) ^ body in
        Packet.create addr full
    end
  | {| _ |} -> raise (Failure "Could not read IPv4 packet")

let read_packet t =
  let str = String.create 20 in
  Reader.really_read t.reader str >>= function
  | `Eof _ -> raise (Failure "EOF")
  | `Ok -> begin
    let bs = Bitstring.bitstring_of_string str in
    match%bitstring bs with
    | {| v : 4 |} when v = 4 -> _read_ipv4 t bs
    | {| _ |} -> raise (Failure "Could not read IP packet")
  end
