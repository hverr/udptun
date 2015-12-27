open Core.Std
open Async.Std
open Cohttp
open Cohttp_async

module Destination = struct
  type t = {
    address : Unix.Inet_addr.t;
    port : int;
  }

  let default_port = 7777

  let create address port = { address; port}
  let address t = t.address
  let port t = t.port
  
  let to_inet t =
    Unix.Socket.Address.Inet.create t.address ~port:t.port

  let of_host_and_port host port =
    let open Unix.Host in
    getbyname_exn host >>| fun entry ->
    match Array.length entry.addresses with
    | 0 -> raise (Failure ("No host with name " ^ host))
    | _ -> create (Array.get entry.addresses 0) port

  let of_json json =
    let open Yojson.Basic.Util in
    let port = match json |> member "port" with
      | `Null -> default_port
      | x -> to_int x
    in
    let open Unix.Host in
    let host = json |> member "host" |> to_string in
    of_host_and_port host port
end

type t = (Int32.t * Destination.t) list

let wildcard = Int32.zero

let fetch url =
  Client.get (Uri.of_string url) >>= fun (r, b) ->
    match r |> Response.status |> Code.code_of_status with
    | 200 -> Body.to_string b
    | _ -> raise (Failure ("Could not fetch " ^ url))

let parse str =
  let json = Yojson.Basic.from_string str in
  let open Yojson.Basic.Util in
  let f = fun (tunip, dst) ->
    (tunip |> Unix.Inet_addr.of_string
           |> Unix.Inet_addr.inet4_addr_to_int32_exn,
    Destination.of_json dst)
  in
  let resolver = json |> member "nodes" |> to_assoc |> List.map ~f in
  let dests = List.map ~f:(fun (_, dst) -> dst) resolver in
  Deferred.all dests >>|
  List.map2_exn resolver ~f:(fun (x, _) y -> (x, y))

let from_host host port =
  Destination.of_host_and_port host port >>| fun dest ->
  [(wildcard, dest)]

let from_file filename =
  Reader.file_contents filename >>= parse

let resolve t ipv4 =
  match List.find t ~f:(fun (x, _) -> x = wildcard || ipv4 = x) with
  | None -> None
  | Some (source, dest) -> Some dest

let fetch_all url =
  fetch url >>= parse

let rec start_fetching ~interval url w =
  fetch_all url >>=
  Pipe.write w >>= fun () ->
  after interval >>= fun () ->
  start_fetching ~interval url w
