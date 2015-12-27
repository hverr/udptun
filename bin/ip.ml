open Core.Std

type protocol =
  | Icmp

let int_of_protocol = function
  | Icmp -> 1

module V4 = struct
  type t = {
	dscp : int;
	ecn : int;
	identification : int;
	flags : int;
	offset : int;
	ttl : int;
	protocol : int;
	chksum : int;
	src : int32;
	dst : int32;
	body : string;
  }

  let create ?(dscp=0) ?(ecn=0) ?(id=0) ?(flags=0)
		     ?(offset=0) ?(ttl=255) ?(chksum=0)
			 protocol ~src ~dst body =
	let protocol = int_of_protocol protocol in
	{ dscp; ecn; identification = id; flags; offset; ttl;
	  protocol; chksum; src; dst; body }

  let header_to_bitstring t =
	let open Bitstring in
	let total_len = 20 + (String.length t.body) in
	let buf = Buffer.create () in
	let e = Failure "Can't create bitstring" in
	construct_int_be_unsigned buf 4 4 e; (* version *)
	construct_int_be_unsigned buf 5 4 e; (* IHL *)
	construct_int_be_unsigned buf t.dscp 6 e;
	construct_int_be_unsigned buf t.ecn 2 e;
	construct_int_be_unsigned buf total_len 16 e;
	construct_int_be_unsigned buf t.identification 16 e;
	construct_int_be_unsigned buf t.flags 3 e;
	construct_int_be_unsigned buf t.offset 13 e;
	construct_int_be_unsigned buf t.ttl 8 e;
	construct_int_be_unsigned buf t.protocol 8 e;
	construct_int_be_unsigned buf t.chksum 16 e;
	construct_int32_be_unsigned buf t.src 32 e;
	construct_int32_be_unsigned buf t.dst 32 e;
	Buffer.contents buf

  let calc_chksum t =
	let bs = header_to_bitstring t in
	let str = Bitstring.string_of_bitstring bs in
	let cstr = Cstruct.of_string str in
	let chksum = Tcpip_checksum.ones_complement cstr in
	{ t with chksum }

  let to_bitstring t =
	let t = { t with chksum = 0 } in
	let h = t |> calc_chksum |> header_to_bitstring in
	Bitstring.(concat [h; bitstring_of_string t.body])
end
