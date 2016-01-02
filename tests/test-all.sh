#!/bin/bash

function run {
    echo "========= RUNNING INTEGRATION TEST $1 ========="
    echo ""
    if ! "$1"; then
        "$1" clean
        echo "FAILURE FOR TEST $1" >&2
        exit 1
    fi
    echo ""
}

run "./test-one-to-one.sh"
run "./test-one-to-many.sh"
run "./test-one-to-one-hosts-url.sh"
run "./test-one-to-many-hosts-url.sh"
run "./test-destination-host-unreachable.sh"
run "./test-tunnel-gateway.sh
