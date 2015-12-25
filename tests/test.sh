#!/bin/bash

set -ex

# Compile and build container
pushd ..
make
popd
cat ../udptun.native > udptun
chmod 0755 udptun
docker build -t udptun .
rm udptun

# Create dockers
docker run -itd --name udptun1 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
docker run -itd --name udptun2 --cap-add=NET_ADMIN --device=/dev/net/tun udptun /bin/bash
IP1=$(docker inspect udptun1 | jq -r ".[0].NetworkSettings.IPAddress")
IP2=$(docker inspect udptun2 | jq -r ".[0].NetworkSettings.IPAddress")

# Start udptun
docker exec -d udptun1 /usr/local/bin/udptun -A "$IP2" -d udptun
docker exec -d udptun2 /usr/local/bin/udptun -A "$IP1" -d udptun

# Configure network devices
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.0
docker exec udptun2 ifconfig udptun 192.168.111.2 netmask 255.255.255.0

# Ping!
docker exec udptun2 ping -W 10 -c 10 192.168.111.1

# Clean up
if [ "$1" != "--no-clean" ]; then
    ./clean.sh
fi
