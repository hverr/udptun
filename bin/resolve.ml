open Core.Std
open Async.Std
open Cohttp
open Cohttp_async

module Destination = struct
  type t = {
    host : string;
    port : int;
  }

  let default_port = 7777

  let create host port = { host; port}
  let host t = t.host
  let port t = t.port
  
  let to_inet t =
    let open Core.Std.Unix.Host in
    let entry = getbyname_exn t.host in
    match Array.length entry.addresses with
    | 0 -> raise (Failure ("No host with name " ^ t.host))
    | _ -> begin
      let addr = Array.get entry.addresses 0 in
      Unix.Socket.Address.Inet.create addr ~port:t.port
    end
    
  let of_json json =
    let open Yojson.Basic.Util in
    let port = match json |> member "port" with
      | `Null -> default_port
      | x -> to_int x
    in
    create (json |> member "host" |> to_string) port
end

let fetch url =
  Client.get (Uri.of_string url) >>= fun (r, b) ->
    match r |> Response.status |> Code.code_of_status with
    | 200 -> Body.to_string b
    | _ -> raise (Failure ("Could not fetch " ^ url))

let parse str =
  let json = Yojson.Basic.from_string str in
  let open Yojson.Basic.Util in
  let f = fun (tunip, dst) -> (tunip, Destination.of_json dst) in
  json |> member "nodes" |> to_assoc |> List.map ~f

let fetch_all url =
  fetch url >>| parse

let rec start_fetching ~interval url w =
  fetch_all url >>=
  Pipe.write w >>= fun () ->
  after interval >>= fun () ->
  start_fetching ~interval url w
