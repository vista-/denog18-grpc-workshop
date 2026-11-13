#!/bin/bash
# Copyright 2020 Nokia
# Licensed under the BSD 3-Clause License.
# SPDX-License-Identifier: BSD-3-Clause

# Sends a steady stream of pings (about 1 Mbit/s) from the loopback of leaf1 to
# the loopback of leaf2, so the path the traffic takes shows up on the Grafana
# dashboard.

set -eu

SOURCE=1.1.1.1
DESTINATION=2.2.2.2

start() {
    echo "starting traffic from leaf1 to ${DESTINATION}"
    docker exec leaf1 pkill -f "ping -q -i 0.01" || true
    docker exec -d leaf1 ip netns exec srbase-default ping -q -i 0.01 -s 1400 -I "${SOURCE}" "${DESTINATION}"
}

stop() {
    echo "stopping traffic from leaf1 to ${DESTINATION}"
    docker exec leaf1 pkill -f "ping -q -i 0.01" || true
}

case "${1:-}" in
    start) start ;;
    stop) stop ;;
    *) echo "usage: $0 start|stop" >&2; exit 1 ;;
esac
