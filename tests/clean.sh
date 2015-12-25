#!/bin/bash

set -x
docker stop udptun1
docker stop udptun2
docker rm udptun1
docker rm udptun2
