#!/usr/bin/env bash

# WiFiLab lightweight read-only telemetry backend.
# Counter telemetry needs no packet capture or elevated privilege.
# Optional protocol sampling uses the caller's existing tshark/dumpcap permissions only.

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
    printf '"protocol_sampler_available":%s' "$tshark_available"
    printf '}\n'
}

wifilab_protocols_json() {
    local iface='' present=false available=false permitted=false
    local sample total=0 first=1 count protocol

    if ! iface=$(wifilab_resolve_selected 2>/dev/null); then
        printf '{"present":false,"available":false,"permitted":false,"sample_packets":0,"protocols":[]}\n'
        return 0
    fi
    present=true

    if ! command -v tshark >/dev/null 2>&1 || ! command -v timeout >/dev/null 2>&1; then
        printf '{"present":true,"available":false,"permitted":false,"sample_packets":0,"protocols":[]}\n'
        return 0
    fi
    available=true

    # One short passive sample. We never use pkexec here: dumpcap permissions remain
    # an explicit user/system configuration decision rather than an implicit escalation.
    if sample=$(timeout 2s tshark -n -i "$iface" -a duration:1 -T fields -e _ws.col.Protocol 2>/dev/null); then
        permitted=true
    else
        printf '{"present":true,"available":true,"permitted":false,"sample_packets":0,"protocols":[]}\n'
        return 0
    fi

    total=$(printf '%s\n' "$sample" | awk 'NF {n++} END {print n+0}')
    printf '{"present":%s,"available":%s,"permitted":%s,"sample_packets":%s,"protocols":[' \
        "$present" "$available" "$permitted" "$total"

    while read -r count protocol; do
        [[ -n $protocol ]] || continue
        (( first )) || printf ','
        first=0
        printf '{"name":"%s","count":%s}' "$(wifilab_json_escape "$protocol")" "$count"
    done < <(printf '%s\n' "$sample" | awk 'NF' | sort | uniq -c | sort -nr | head -8)

    printf ']}\n'
}
