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
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.240
docker exec udptun2 ifconfig udptun 192.168.111.241 netmask 255.255.255.240
docker exec udptun1 route add -net 192.168.111.240/28 udptun
docker exec udptun2 route add -net 192.168.111.0/28 udptun

# Setup KAME
AH_KEY=$(openssl rand -hex 64)
ESP_KEY=$(openssl rand -hex 32)
SETKEY_HEADER=$(cat <<EOF
flush;
spdflush;

add 192.168.111.1 192.168.111.241 ah 15700 -A hmac-sha2-512 0x$AH_KEY;
add 192.168.111.241 192.168.111.1 ah 24500 -A hmac-sha2-512 0x$AH_KEY;
add 192.168.111.1 192.168.111.241 esp 15701 -E rijndael-cbc 0x$ESP_KEY;
add 192.168.111.241 192.168.111.1 esp 24501 -E rijndael-cbc 0x$ESP_KEY;

EOF)
echo "$SETKEY_HEADER" | docker exec -i udptun1 /bin/bash -c 'cat > /root/setkey.conf'
echo "$SETKEY_HEADER" | docker exec -i udptun2 /bin/bash -c 'cat > /root/setkey.conf'

docker exec -i udptun1 /bin/bash -c 'cat >> /root/setkey.conf' <<EOF
spdadd 192.168.111.1 192.168.111.241 any -P out ipsec
    esp/transport//require
    ah/transport//require;
spdadd 192.168.111.241 192.168.111.1 any -P in ipsec
    esp/transport//require
    ah/transport//require;
EOF
docker exec -i udptun2 /bin/bash -c 'cat >> /root/setkey.conf' <<EOF
spdadd 192.168.111.1 192.168.111.241 any -P in ipsec
    esp/transport//require
    ah/transport//require;
spdadd 192.168.111.241 192.168.111.1 any -P out ipsec
    esp/transport//require
    ah/transport//require;
EOF
docker exec udptun1 setkey -f /root/setkey.conf
# We do not setup encryption on udptun2 yet, see below
#docker exec udptun2 setkey -f /root/setkey.conf

# Make sure unencrypted pings from udptun2 to udptun1 are rejected!
# udptun2 hasn't got encryption setup yet, so this should fail
! docker exec udptun2 ping -W 3 -c 3 192.168.111.1
! docker exec udptun1 ping -W 3 -c 3 192.168.111.241

# Setup encryption on udptun2 and start the ping!
docker exec udptun2 setkey -f /root/setkey.conf
docker exec udptun2 ping -W 3 -c 3 192.168.111.1
docker exec udptun1 ping -W 3 -c 3 192.168.111.241

# Clean up
if [ "$1" != "--no-clean" ]; then
    "$0" clean
fi
