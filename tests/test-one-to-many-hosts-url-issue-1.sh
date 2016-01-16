#!/bin/bash

# Regression test for
# https://github.com/hverr/udptun/issues/1
#
# Resolving VPN hosts using HTTP does not handle 302 well.
#
# (((pid 466) (thread_id 0))
#  ((human_readable 2016-01-16T12:52:43-0500)
#   (int63_ns_since_epoch 1452966763096995000))
#  "unhandled exception in Async scheduler"
#  ("unhandled exception"
#   ((src/monitor.ml.Error_
#     ((exn (Failure "Could not fetch **redacted-url**: HTTP 302"))
#      (backtrace
#       ("Raised at file \"pervasives.ml\", line 30, characters 22-33"
#        "Called from file \"src/deferred0.ml\", line 59, characters 65-68"
#        "Called from file \"src/job_queue.ml\", line 164, characters 6-47" ""))
#      (monitor
#       (((name main) (here ()) (id 1) (has_seen_error true)
#         (is_detached false) (kill_index 0))))))
#    ((pid 466) (thread_id 0)))))


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
docker exec -i udptun_hosts /bin/sh -c 'cat > /usr/share/nginx/html/real-hosts.json' <<EOF
{
  nodes : {
    "192.168.111.1" : { "host" : "$IP1" },
    "192.168.111.2" : { "host" : "$IP2" }
  }
}
EOF
docker exec -i udptun_hosts /bin/sh -c 'cat > /etc/nginx/conf.d/default.conf' <<EOF
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    location /hosts.json {
        return 302 /real-hosts.json;
    }
}
EOF
docker stop udptun_hosts
docker start udptun_hosts
IP_HOSTS=$(docker inspect udptun_hosts | jq -r ".[0].NetworkSettings.IPAddress")
HOSTS_URL="http://$IP_HOSTS/hosts.json"
curl -L "$HOSTS_URL"

# Start udptun
docker exec -d udptun1 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun
docker exec -d udptun2 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun
docker exec -d udptun3 /usr/local/bin/udptun --hosts-url "$HOSTS_URL" --hosts-url-interval 0.5 -d udptun

# Give applications some time to create network devices
sleep 1

# Configure network devices
docker exec udptun1 ifconfig udptun 192.168.111.1 netmask 255.255.255.0
docker exec udptun2 ifconfig udptun 192.168.111.2 netmask 255.255.255.0
docker exec udptun3 ifconfig udptun 192.168.111.3 netmask 255.255.255.0

# Ping!
docker exec udptun2 ping -W 1 -c 3 192.168.111.1

# Ping should fail as there is no mapping for 192.168.111.3 (udptun3)
! docker exec udptun3 ping -W 1 -c 3 192.168.111.2

# Add 192.168.111.3 to hosts file
docker exec -i udptun_hosts /bin/sh -c 'cat > /usr/share/nginx/html/real-hosts.json' <<EOF
{
  nodes : {
    "192.168.111.1" : { "host" : "$IP1" },
    "192.168.111.2" : { "host" : "$IP2" },
    "192.168.111.3" : { "host" : "$IP3" }
  }
}
EOF
curl -L "$HOSTS_URL"

# Give udptun some time to update
sleep 2

# Ping should work now
docker exec udptun3 ping -W 1 -c 3 192.168.111.2

# Clean up
if [ "$1" != "--no-clean" ]; then
    "$0" clean
fi
