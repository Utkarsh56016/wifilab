#!/usr/bin/env bash

# WiFiLab lightweight read-only telemetry backend.
# Counter telemetry reads /sys/class/net only; it never captures packets.

set -o pipefail

wifilab_read_counter() {
    # Keep declarations separate under `set -u`: Bash expands all RHS values
    # in a single `local` command before completing the assignments, so using
    # $name in the same declaration that creates `name` can trigger an
    # "unbound variable" failure.
    local iface=$1
    local name=$2
    local file="/sys/class/net/$iface/statistics/$name"

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
    # Legacy compatibility field. Protocol work is now offline against saved
    # PCAPs, so this means the offline tshark analyzer is installed.
    printf '"protocol_sampler_available":%s' "$tshark_available"
    printf '}\n'
}
