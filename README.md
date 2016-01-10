udptun
======

Tunnel IPv4 packets over UDP in user space. Useful for older kernels that do not include [fou][fou-article].

 [fou-article]: https://lwn.net/Articles/614348/


## Features and Use Cases

  - IPsec behind NAT
  - One-to-many tunneling
    - **Dynamic virtual IP to real IP lookup using HTTPS**
    - Static virtual IP to real IP lookup using a json file
  - One-to-one tunneling
    - Virtual IP to real IP using command line flag
  - Tunnel gateway
    - Use one tunnel gateway to interconnect multiple subnets
  - User space
    - Only needs `NET_ADMIN` capability
    - Uses [`/dev/net/tun`][ocaml-tuntap] to create a virtual TUN interface
  - [Examples](tests)

  [ocaml-tuntap]: https://github.com/mirage/ocaml-tuntap

## One-to-One Example

```sh
# Setup a one-to-one tunnel between two machines
# On vps1.example.org
vps1$ udptun -A vps2.example.org -d udptun
vps1$ ifconfig udptun 192.168.100.1 netmask 255.255.255.0

# On vps2.example.org
vps2$ udptun -A vps1.example.org -d udptun
vps2$ ifconfig udptun 192.168.100.2 netmask 255.255.255.0

# You can now ping, you will get a response
# On vps1.example.org
$ ping 192.168.100.2 -c 1
PING 192.168.100.2 56(84) bytes of data.
64 bytes from 192.168.100.2: icmp_seq=1 ttl=63 time=14.5 ms

--- 192.168.100.2 statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 14.571/14.571/14.571/0.000 ms
```

## Static One-to-Many Example
![One-to-many layout][one-to-many-layout]

```sh
$ cat hosts.json
{
  "nodes" : {
    "192.168.100.1" : { "host" : "vps1.example.org" },
    "192.168.100.2" : { "host" : "vps2.example.org" },
    "192.168.100.3" : { "host" : "vps3.example.org" }
  }
}
# Setup a one-to-one tunnel between two machines
# On vps1.example.org
vps1$ udptun --hosts-file hosts.json -d udptun
vps1$ ifconfig udptun 192.168.100.1 netmask 255.255.255.0

# On vps2.example.org
vps2$ udptun --hosts-file hosts.json -d udptun
vps2$ ifconfig udptun 192.168.100.2 netmask 255.255.255.0

# On vps3.example.org
vps3$ udptun --hosts-file hosts.json -d udptun
vps3$ ifconfig udptun 192.168.100.3 netmask 255.255.255.0

# You can now ping, you will get a response from both machines
# On vps1.example.org
$ ping 192.168.100.2 -c 1
PING 192.168.100.2 56(84) bytes of data.
64 bytes from 192.168.100.2: icmp_seq=1 ttl=63 time=14.5 ms
[...]
$ ping 192.168.100.3 -c 1
PING 192.168.100.3 56(84) bytes of data.
64 bytes from 192.168.100.3: icmp_seq=1 ttl=63 time=41.1 ms
[...]
```

## Tunnel Gateway
![Tunnel gateway layout][tunnel-gateway-layout]

```sh
# On s1.example.org, s2.example.org and s3.example.org
s1$ ifconfig eth0 192.168.100.10 netmask 255.255.255.248
s2$ ifconfig eth0 192.168.100.11 netmask 255.255.255.248
s3$ ifconfig eth0 192.168.100.12 netmask 255.255.255.248
s1$ route add -net 192.168.100.0/29 gw 192.168.100.9
s2$ route add -net 192.168.100.0/29 gw 192.168.100.9
s3$ route add -net 192.168.100.0/29 gw 192.168.100.9

# On the gateway (with public IP on eth1 already configured)
gw$ sysctl -w net.ipv4.ip_forward=1
gw$ ifconfig eth0 192.168.100.9 netmask 255.255.255.248
gw$ udptun -A 8.8.4.4 -d udptun
gw$ ifconfig udptun 192.168.100.1 netmask 255.255.255.248

# On the right most server (with public IP on eth0 already configured)
right$ udptun -A 8.8.8.8 -d udptun
right$ ifconfig udptun 192.168.100.2 netmask 255.255.255.248
right$ route add -net 192.168.100.8/29 gw 192.168.100.1
```

## Security
`udptun` does not provide any authentication or confidentiality. Anyone can e.g. claim to be `192.168.100.2` and send spoofed packets to a machine.

You should use e.g. IPsec to provide authentication and if necessary confidentiality.

## Development

HTTPS requires SSL which is provided by `Async`'s `SSL` library which requires

```
$ sudo apt-get install libssl-dev libffi-dev libncurses-dev time
$ opam install async_ssl
```

Currently `ocaml-conduit` and `ocaml-cohttp` do not include support for checking CA certificates using `Async`, so use the following patches

```
$ opam pin add -k git conduit https://github.com/hverr/ocaml-conduit
$ opam pin add -k git cohttp https://github.com/hverr/ocaml-cohttp
```

The project requires a patched version of `ppx_bitstring`

```
$ opam pin add -k git ppx_bitstring https://github.com/xguerin/ppx_bitstring
```

Now you can run `make` to build the project.



 [one-to-many-layout]: https://github.com/hverr/udptun/blob/docs/one-to-many.png
 [tunnel-gateway-layout]: https://github.com/hverr/udptun/blob/docs/tunnel-gateway.png
