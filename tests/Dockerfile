FROM ubuntu:15.10
MAINTAINER Henri Verroken <henriverroken@gmail.com>

RUN apt-get update && apt-get install -y \
    net-tools \
    iputils-ping \
    libssl1.0.0

ADD udptun /usr/local/bin/udptun
RUN chmod 0755 /usr/local/bin/udptun

RUN mkdir -p /etc/udptun
