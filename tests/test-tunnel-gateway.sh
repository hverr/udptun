#!/bin/bash

if [ "$1" = "clean" ]; then
    set -x
	docker stop udptun1
	docker stop udptun2
	docker stop router
	docker rm udptun1
	docker rm udptun2
	docker rm router
	exit
elif [ -n "$1" ]; then
    echo "unknown command: $1" >&2
    exit 1
fi

set -ex

# Compile and build container
make

# Create dockers
docker run -itd --name router --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
docker run -itd --name udptun1 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
docker run -itd --name udptun2 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
IP_ROUTER=$(docker inspect router | jq -r ".[0].NetworkSettings.IPAddress")
IP1=$(docker inspect udptun1 | jq -r ".[0].NetworkSettings.IPAddress")
IP2=$(docker inspect udptun2 | jq -r ".[0].NetworkSettings.IPAddress")

# Configure hosts file
function setup_hosts {
  docker exec -i "$1" /bin/bash -c 'cat > /etc/udptun/hosts.json' <<EOF
{
  "nodes" : {
    "192.168.111.2" : { "host" : "$IP_ROUTER" },
    "192.168.111.5" : { "host" : "$IP_ROUTER" },
    "192.168.111.6" : { "host" : "$IP2" }
  }
}
EOF
}
setup_hosts router
setup_hosts udptun2

# Start udptun
HOSTS_FILE=/etc/udptun/hosts.json
docker exec -d router /usr/local/bin/udptun --hosts-file "$HOSTS_FILE" -d udptun
docker exec -d udptun2 /usr/local/bin/udptun --hosts-file "$HOSTS_FILE" -d udptun

# Give applications some time to create network devices
sleep 1

# Configure network devices
docker exec udptun1 ifconfig eth0:1 192.168.111.2 netmask 255.255.255.252
docker exec udptun1 route add -net 192.168.111.4 netmask 255.255.255.252 gw 192.168.111.1
docker exec router ifconfig eth0:1 192.168.111.1 netmask 255.255.255.252
docker exec router ifconfig udptun 192.168.111.5 netmask 255.255.255.252
docker exec router sysctl -w net.ipv4.ip_forward=1
docker exec router cat /proc/sys/net/ipv4/ip_forward
docker exec udptun2 ifconfig udptun 192.168.111.6 netmask 255.255.255.252
docker exec udptun2 route add -net 192.168.111.0 netmask 255.255.255.252 gw 192.168.111.5

# Ping!
docker exec udptun1 ping -W 1 -c 3 192.168.111.1
docker exec udptun1 ping -W 1 -c 3 192.168.111.6
docker exec udptun2 ping -W 3 -c 3 192.168.111.2

# Clean up
"$0" clean
