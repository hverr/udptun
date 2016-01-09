open Core.Std
open Async.Std

module Packet = struct
  type t = {
    source : int32;
    destination : int32;
    raw : string;
  }

  let create source destination raw =
    {source; destination; raw}
  let source t = t.source
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
  let open Ip.V4 in
  read t.reader >>| fun p ->
  let raw = p |> to_bitstring |> Bitstring.string_of_bitstring in
  Packet.create p.src p.dst raw
