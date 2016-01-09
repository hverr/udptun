FROM ubuntu:15.10
MAINTAINER Henri Verroken <henriverroken@gmail.com>

RUN apt-get update

RUN mkdir -p /root/udptun/usr/bin
ADD udptun /root/udptun/usr/bin/udptun
ADD gen.sh /usr/local/bin/gen.sh

ENTRYPOINT [ "gen.sh" ]
