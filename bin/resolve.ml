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

type t = {
  hosts : (Int32.t * Destination.t) list;
  updater : t Pipe.Reader.t;
}

let wildcard = Int32.zero

let fetch ~ca_file ~ca_path url =
  let ssl_config =
    let open Conduit_async in
    Ssl.(configure ?ca_file ?ca_path ~verify:verify_certificate ())
  in
  Client.get ~ssl_config (Uri.of_string url) >>= fun (r, b) ->
    match r |> Response.status |> Code.code_of_status with
    | 200 -> Body.to_string b
    | status -> raise (Failure
        (sprintf "Could not fetch %s: HTTP %d" url status))

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

let fetch_all ~ca_file ~ca_path url =
  fetch url ~ca_file ~ca_path >>= parse

let from_host host port =
  let updater, _ = Pipe.create () in
  Destination.of_host_and_port host port >>| fun dest ->
  {hosts = [(wildcard, dest)]; updater}

let from_file filename =
  let updater, _ = Pipe.create () in
  Reader.file_contents filename >>= parse >>| fun hosts ->
  { hosts; updater }

let rec start_fetching t ~interval ~ca_file ~ca_path url w =
  try_with (fun () -> fetch_all ~ca_file ~ca_path url) >>= (function
  | Error e ->
    return (printf "Could not fetch %s: %s\n" url
      (Exn.to_string e))
  | Ok hosts -> Pipe.write w {t with hosts}
  ) >>= fun () ->
  after interval >>= fun () ->
  start_fetching t ~interval ~ca_file ~ca_path url w

let from_url ~interval ~ca_file ~ca_path url =
  let updater, w = Pipe.create () in
  fetch_all ~ca_file ~ca_path url >>| fun hosts ->
  let t = {hosts; updater } in
  ignore (start_fetching t ~interval ~ca_file ~ca_path url w); t

let resolve t ipv4 =
  match List.find t.hosts ~f:(fun (x, _) -> x = wildcard || ipv4 = x) with
  | None -> None
  | Some (source, dest) -> Some dest

let update t =
  Pipe.read t.updater
