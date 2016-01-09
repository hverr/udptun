open Core.Std
open Async.Std

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
    Bitstring.(concat [h; (bitstring_of_string t.body)])

  let of_bitstring ?body bs =
    match%bitstring bs with
    | {| _ : 8; (* version and IHL *)
         dscp : 6;
         ecn : 2;
         total_length : 16 : bigendian;
         identification : 16 : bigendian;
         flags : 3;
         offset : 13 : bigendian;
         ttl : 8;
         protocol : 8;
         chksum : 16 : bigendian;
         src : 32 : bigendian;
         dst : 32 : bigendian;
         default_body : -1 : bitstring
      |} -> begin
        let open Bitstring in
        let default_body = string_of_bitstring default_body in
        let body = Option.value body ~default:default_body in
        match String.length body with
        | x when x = total_length - 20 ->
          { dscp; ecn; identification; flags; offset; ttl;
            protocol; chksum; src; dst; body }
        | _ -> failwith "The IPv4 packet length did not match"
      end
    | {| _ |} -> failwith "Could not read IPv4 packet"

  let read r =
    let str = String.create 20 in
    Reader.really_read r str >>= function
    | `Eof _ -> failwith "EOF"
    | `Ok -> begin
      let bs = Bitstring.bitstring_of_string str in
      match%bitstring bs with
      | {| 4 : 4; _ : 12; len : 16 : bigendian |} -> begin
          let body_len = len - 20 in
          match body_len with
          | x when x >= 0 -> begin
            let body = String.create body_len in
            Reader.really_read r body >>| function
            | `Eof _ -> failwith "EOF"
            | `Ok -> of_bitstring ~body bs
          end
          | x -> failwith "Invalid IPv4 packet length."
        end
      | {| _ |} -> failwith "Could not read IPv4 packet."
    end
end
