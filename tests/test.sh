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
