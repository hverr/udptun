open Core.Std
open Async.Std

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
