#!/bin/bash


if [ "$1" = "clean" ]; then
    set -x
	docker stop udptun1
	docker stop udptun2
	docker rm udptun1
	docker rm udptun2
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
IP1=$(docker inspect udptun1 | jq -r ".[0].NetworkSettings.IPAddress")
IP2=$(docker inspect udptun2 | jq -r ".[0].NetworkSettings.IPAddress")

# Start udptun
docker exec -d udptun1 /usr/local/bin/udptun -A "$IP2" -d udptun
docker exec -d udptun2 /usr/local/bin/udptun -A "$IP1" -d udptun

# Give applications some time to create network devices
sleep 1

# Configure network devices
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.0
docker exec udptun2 ifconfig udptun 192.168.111.2 netmask 255.255.255.0

# Ping!
docker exec udptun2 ping -W 3 -c 3 192.168.111.1

# Send some gibberish
echo 'gibberish' | docker exec -i udptun2 netcat -u -w1 192.168.111.1 7777

# Ping!
docker exec udptun2 ping -W 3 -c 3 192.168.111.1

# Send an IPv4 header that is totally correct and expects IP-in-IP (protocol 4)
# If we ping after this, will the IP packet be used as the body of this IP and
# be discarded? Let's hope not!
IPV4_PACKET="45000020
             00000000
             FF045C85
             C0A86F02
             C0A86F01"
echo $IPV4_PACKET | docker exec -i udptun2 xxd -r -p | hexdump -C \
                  | docker exec -i udptun2 netcat -u -w1 192.168.111.1 7777

# Ping won't work in 6b9e4934114c90129b398b427d774690d7cff40f
# Kernel can't handle it!
docker exec udptun2 ping -W 3 -c 3 192.168.111.1

# Clean up
if [ "$1" != "--no-clean" ]; then
    "$0" clean
fi
