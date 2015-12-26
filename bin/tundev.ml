open Core.Std
open Async.Std

module Packet = struct
  type t = {
    destination : Unix.Inet_addr.t;
    raw : string;
  }

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

let read_packet t =
  let str = String.create 20 in
  let bs = Bitstring.bitstring_of_string str in
  match%bitstring bs with
  | {| v : 4 |} -> v
  | {| _ |} -> raise (Failure "Unknown format")
