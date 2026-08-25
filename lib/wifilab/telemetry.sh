#!/usr/bin/env bash

# WiFiLab lightweight read-only telemetry backend.
# Provides counters suitable for UI rate calculation without packet capture.

set -o pipefail

wifilab_read_counter() {
    local iface=$1 name=$2 file="/sys/class/net/$iface/statistics/$name"
    [[ -r $file ]] || { printf '0\n'; return; }
    cat "$file" 2>/dev/null || printf '0\n'
}

wifilab_telemetry_json() {
    local iface='' present=false
    local rx_bytes=0 tx_bytes=0 rx_packets=0 tx_packets=0 rx_dropped=0 tx_dropped=0
    local timestamp_ms tshark_available=false

    timestamp_ms=$(date +%s%3N 2>/dev/null || date +%s000)
    command -v tshark >/dev/null 2>&1 && tshark_available=true

    if iface=$(wifilab_resolve_selected 2>/dev/null); then
        present=true
        rx_bytes=$(wifilab_read_counter "$iface" rx_bytes)
        tx_bytes=$(wifilab_read_counter "$iface" tx_bytes)
        rx_packets=$(wifilab_read_counter "$iface" rx_packets)
        tx_packets=$(wifilab_read_counter "$iface" tx_packets)
        rx_dropped=$(wifilab_read_counter "$iface" rx_dropped)
        tx_dropped=$(wifilab_read_counter "$iface" tx_dropped)
    fi

    printf '{'
    printf '"present":%s,' "$present"
    printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"timestamp_ms":%s,' "$timestamp_ms"
    printf '"rx_bytes":%s,' "${rx_bytes:-0}"
    printf '"tx_bytes":%s,' "${tx_bytes:-0}"
    printf '"rx_packets":%s,' "${rx_packets:-0}"
    printf '"tx_packets":%s,' "${tx_packets:-0}"
    printf '"rx_dropped":%s,' "${rx_dropped:-0}"
    printf '"tx_dropped":%s,' "${tx_dropped:-0}"
    printf '"protocol_sampler_available":%s' "$tshark_available"
    printf '}\n'
}
