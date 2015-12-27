open Core.Std

type packet_type =
  | Destination_unreachable

type packet_code =
  | Destination_host_unreachable

type t = {
  packet_type : int;
  code : int;
  chksum : int;
  body : string;
}

let int_of_packet_type = function
  | Destination_unreachable -> 3

let int_of_code = function
  | Destination_host_unreachable -> 1

let create packet_type code body =
  let packet_type = int_of_packet_type packet_type in
  let code = int_of_code code in
  {packet_type; code; chksum = 0; body}

let destination_host_unreachable packet =
  let ip_raw = Tundev.Packet.raw packet in
  let ip_len = min 28 (String.length ip_raw) in
  let ip_body = String.sub ip_raw 0 ip_len in
  let first_32 = String.create 4 in
  String.fill first_32 ~pos:0 ~len:4 (Char.of_int_exn 0);
  let body = first_32 ^ ip_body in
  create Destination_unreachable Destination_host_unreachable body

let to_bitstring t =
  let open Bitstring in
  let buf = Buffer.create () in
  let e = Failure "Can't create bitstring" in
  construct_int_be_unsigned buf t.packet_type 8 e;
  construct_int_be_unsigned buf t.code 8 e;
  construct_int_be_unsigned buf t.chksum 16 e;
  construct_string buf t.body;
  Buffer.contents buf

let calc_chksum t =
  let bs = to_bitstring t in
  let str = Bitstring.string_of_bitstring bs in
  let cstr = Cstruct.of_string str in
  let chksum = Tcpip_checksum.ones_complement cstr in
  { t with chksum }

let chksum_and_bitstring t =
  {t with chksum = 0} |> calc_chksum |> to_bitstring
