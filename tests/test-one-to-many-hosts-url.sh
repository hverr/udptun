#!/bin/bash


if [ "$1" = "clean" ]; then
    set -x
	docker stop udptun1
	docker stop udptun2
	docker stop udptun3
    docker stop udptun_hosts
	docker rm udptun1
	docker rm udptun2
	docker rm udptun3
    docker rm udptun_hosts
	exit
elif [ -n "$1" ]; then
    echo "unknown command: $1" >&2
    exit 1
fi

set -ex

# Compile and build container
make

# Create dockers
docker run -itd --name udptun1 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
docker run -itd --name udptun2 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
docker run -itd --name udptun3 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
IP1=$(docker inspect udptun1 | jq -r ".[0].NetworkSettings.IPAddress")
IP2=$(docker inspect udptun2 | jq -r ".[0].NetworkSettings.IPAddress")
IP3=$(docker inspect udptun3 | jq -r ".[0].NetworkSettings.IPAddress")

# Create docker to serve hosts file
docker run -d --name udptun_hosts nginx
IP_HOSTS=$(docker inspect udptun_hosts | jq -r ".[0].NetworkSettings.IPAddress")
docker exec -i udptun_hosts /bin/sh -c 'cat > /usr/share/nginx/html/hosts.json' <<EOF
{
  nodes : {
    "192.168.111.1" : { "host" : "$IP1" },
    "192.168.111.2" : { "host" : "$IP2" }
  }
}
EOF
HOSTS_URL="http://$IP_HOSTS/hosts.json"
curl "$HOSTS_URL"

# Start udptun
docker exec -d udptun1 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun
docker exec -d udptun2 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun
docker exec -d udptun3 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun

# Give applications some time to create network devices
sleep 1

# Configure network devices
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.0
docker exec udptun2 ifconfig udptun 192.168.111.2 netmask 255.255.255.0

# Ping!
docker exec udptun2 ping -W 1 -c 3 192.168.111.1

# Ping should fail as there is no mapping for 192.168.111.3 (udptun3)
! docker exec udptun3 ping -W 1 -c 3 192.168.111.2

# Add 192.168.111.3 to hosts file
docker exec -i udptun_hosts /bin/sh -c 'cat > /usr/share/nginx/html/hosts.json' <<EOF
{
  nodes : {
    "192.168.111.1" : { "host" : "$IP1" },
    "192.168.111.2" : { "host" : "$IP2" },
    "192.168.111.3" : { "host" : "$IP3" }
  }
}
EOF
curl "$HOSTS_URL"

# Give udptun some time to update
sleep 2

# Ping should work now
docker exec udptun3 ping -W 1 -c 3 192.168.111.2

# Clean up
if [ "$1" != "--no-clean" ]; then
    "$0" clean
fi
