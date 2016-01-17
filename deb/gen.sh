#!/bin/bash

set -ex

if [ -z "$VERSION" ]; then
    echo "No VERSION is set" >&2
    exit 1
fi


UNAME_M=$(uname -m)
if [ $UNAME_M = x86_64 ]; then
    ARCH=amd64
elif [ $UNAME_M = i686 ]; then
    ARCH=i386
else
    echo "Unsupported architecture: $UNAME_M" >&2
    exit 1
fi

ARGS=$(getopt -o "" --long local -- "$@")
eval set -- "$ARGS"
while true; do
    case "$1" in
        --local) LOCAL=1; shift ;;
	--) shift; break ;;
        *) echo "getopt: error: unsupported flag $1" >&2; exit 1;;
    esac
done

if [ "$LOCAL" != 1 ]; then
    cd
fi

mkdir -p udptun/DEBIAN

if [ "$LOCAL" = 1 ]; then
    pushd .. && make && popd
    mkdir -p udptun/usr/bin/
    cp ../udptun.native ./udptun/usr/bin/udptun
fi

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

if [ "$LOCAL" != 1 ]; then
    cd
fi
dpkg-deb --build udptun >&2

dpkg -i --force-depends udptun.deb >&2
apt-get install -f -y >&2

/usr/bin/udptun --help &>/dev/null

if [ "$LOCAL" != 1 ]; then
    cat udptun.deb
else
    mv udptun.deb udptun_${VERSION}_$(uname -m).deb
    rm -rf udptun
fi
