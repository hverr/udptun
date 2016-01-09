#!/bin/bash

set -ex

if [ -z "$VERSION" ]; then
    echo "No VERSION is set" >&2
    exit 1
fi


UNAME_M=$(uname -m)
if [ $UNAME_M = x86_64 ]; then
    ARCH=amd64
else
    echo "Unsupported architecture: $UNAME_M" >&2
    exit 1
fi

cd

mkdir -p udptun/DEBIAN

cat > udptun/DEBIAN/control <<EOF
Package: udptun
Architecture: $ARCH
Maintainer: Henri Verroken
Depends: libssl1.0.0, libffi6
Priority: optional
Version: $VERSION
Description: User space IPv4 over UDP tunneling
 Tunnel IPv4 packets over UDP in user space. Useful for older kernels dat do not
 include FOU. Ideal in combination with IPsec to create VPNs behind NAT.
Section: net
Homepage: https://github.com/hverr/udptun
EOF

cd
dpkg-deb --build udptun >&2

dpkg -i --force-depends udptun.deb >&2
apt-get install -f -y >&2

/usr/bin/udptun --help &>/dev/null

cat udptun.deb
