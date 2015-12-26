#!/bin/bash

if [ "$1" = "clean" ]; then
    set -x
	docker stop udptun1
	docker stop udptun2
	docker stop udptun3
	docker rm udptun1
	docker rm udptun2
	docker rm udptun3
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

# Configure hosts file
function setup_hosts {
  s=$(cat <<EOF
export IP1="$IP1"
export IP2="$IP2"
export IP3="$IP3"
/etc/udptun/genhosts.json.sh > /etc/udptun/hosts.json
EOF)
  docker exec "$1" /bin/bash -c "$s"
}
setup_hosts udptun1
setup_hosts udptun2
setup_hosts udptun3

# Start udptun
HOSTS_FILE=/etc/udptun/hosts.json
docker exec -d udptun1 /usr/local/bin/udptun --hosts-file "$HOSTS_FILE" -d udptun
docker exec -d udptun2 /usr/local/bin/udptun --hosts-file "$HOSTS_FILE" -d udptun
docker exec -d udptun3 /usr/local/bin/udptun --hosts-file "$HOSTS_FILE" -d udptun

# Configure network devices
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.0
docker exec udptun2 ifconfig udptun 192.168.111.2 netmask 255.255.255.0
docker exec udptun3 ifconfig udptun 192.168.111.3 netmask 255.255.255.0

# Ping!
docker exec udptun2 ping -W 1 -c 3 192.168.111.1
docker exec udptun2 ping -W 1 -c 3 192.168.111.3
docker exec udptun1 ping -W 1 -c 3 192.168.111.3
docker exec udptun3 ping -W 1 -c 3 192.168.111.2

# Clean up
"$0" clean
