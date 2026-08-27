#!/usr/bin/env bash

# WiFiLab Phase 8A read-only network interface inventory.
# This module reports observed netdev state only. Addressing/routes, interface
# roles, relationship graphs, Wi-Fi discovery, and connection mutations belong
# to later bounded Phase 8 subphases.

set -o pipefail

wifilab_network_nm_type() {
    local iface=$1 value
    wifilab_have nmcli || return 0
    value=$(nmcli -g GENERAL.TYPE device show "$iface" 2>/dev/null | head -n1 || true)
    printf '%s\n' "$value"
}

wifilab_network_bool() {
    [[ ${1-} == true ]] && printf 'true' || printf 'false'
}

wifilab_network_uint() {
    local value=${1-}
    [[ $value =~ ^[0-9]+$ ]] && printf '%s' "$value" || printf '0'
}

wifilab_network_nullable_uint() {
    local value=${1-}
    [[ $value =~ ^[0-9]+$ ]] && printf '%s' "$value" || printf 'null'
}

wifilab_network_kind() {
    local wireless=$1 loopback=$2 virtual=$3 nm_type=$4

    if [[ $loopback == true ]]; then
        printf 'loopback\n'
    elif [[ $wireless == true ]]; then
        printf 'wireless\n'
    else
        case "$nm_type" in
            ethernet) printf 'ethernet\n' ;;
            bridge)   printf 'bridge\n' ;;
            tun)      printf 'tunnel\n' ;;
            *)
                if [[ $virtual == true ]]; then
                    printf 'virtual\n'
                else
                    printf 'other\n'
                fi
                ;;
        esac
    fi
}

wifilab_network_interface_json() {
    local iface=$1 base="/sys/class/net/$1"
    local sysfs_path device_path ifindex arphrd_type operstate carrier mtu mac driver bus master
    local rx_bytes tx_bytes rx_packets tx_packets
    local wireless=false virtual=false loopback=false nm_type nm_state connection nm_managed=true
    local mode phy kind

    [[ -d $base ]] || return 1

    sysfs_path=$(readlink -f "$base" 2>/dev/null || true)
    [[ $sysfs_path == /sys/devices/virtual/net/* ]] && virtual=true

    arphrd_type=$(cat "$base/type" 2>/dev/null || true)
    if [[ $iface == lo || $arphrd_type == 772 ]]; then
        loopback=true
    fi

    if [[ -d $base/wireless ]]; then
        wireless=true
    fi

    ifindex=$(cat "$base/ifindex" 2>/dev/null || true)
    operstate=$(cat "$base/operstate" 2>/dev/null || true)
    carrier=$(cat "$base/carrier" 2>/dev/null || true)
    mtu=$(cat "$base/mtu" 2>/dev/null || true)
    mac=$(cat "$base/address" 2>/dev/null || true)
    driver=$(wifilab_driver_for_iface "$iface")
    bus=$(wifilab_udev_property "$iface" ID_BUS)

    device_path=""
    if [[ -e $base/device || -L $base/device ]]; then
        device_path=$(readlink -f "$base/device" 2>/dev/null || true)
    fi

    master=""
    if [[ -L $base/master ]]; then
        master=$(basename "$(readlink -f "$base/master" 2>/dev/null || true)")
    fi

    rx_bytes=$(cat "$base/statistics/rx_bytes" 2>/dev/null || true)
    tx_bytes=$(cat "$base/statistics/tx_bytes" 2>/dev/null || true)
    rx_packets=$(cat "$base/statistics/rx_packets" 2>/dev/null || true)
    tx_packets=$(cat "$base/statistics/tx_packets" 2>/dev/null || true)

    nm_type=$(wifilab_network_nm_type "$iface")
    nm_state=$(wifilab_nm_state "$iface")
    connection=$(wifilab_nm_connection "$iface")
    [[ $nm_state == unmanaged ]] && nm_managed=false

    mode=""
    phy=""
    if [[ $wireless == true ]]; then
        mode=$(wifilab_iface_type "$iface")
        phy=$(wifilab_phy_for_iface "$iface")
    fi

    kind=$(wifilab_network_kind "$wireless" "$loopback" "$virtual" "$nm_type")

    printf '{'
    printf '"name":"%s",' "$(wifilab_json_escape "$iface")"
    printf '"ifindex":%s,' "$(wifilab_network_uint "$ifindex")"
    printf '"kind":"%s",' "$(wifilab_json_escape "$kind")"
    printf '"wireless":%s,' "$(wifilab_network_bool "$wireless")"
    printf '"virtual":%s,' "$(wifilab_network_bool "$virtual")"
    printf '"loopback":%s,' "$(wifilab_network_bool "$loopback")"
    printf '"arphrd_type":%s,' "$(wifilab_network_uint "$arphrd_type")"
    printf '"operstate":"%s",' "$(wifilab_json_escape "$operstate")"
    printf '"carrier":%s,' "$(wifilab_network_nullable_uint "$carrier")"
    printf '"nm_type":"%s",' "$(wifilab_json_escape "$nm_type")"
    printf '"nm_state":"%s",' "$(wifilab_json_escape "$nm_state")"
    printf '"nm_managed":%s,' "$(wifilab_network_bool "$nm_managed")"
    printf '"connection":"%s",' "$(wifilab_json_escape "$connection")"
    printf '"mode":"%s",' "$(wifilab_json_escape "$mode")"
    printf '"phy":"%s",' "$(wifilab_json_escape "$phy")"
    printf '"driver":"%s",' "$(wifilab_json_escape "$driver")"
    printf '"bus":"%s",' "$(wifilab_json_escape "$bus")"
    printf '"mac":"%s",' "$(wifilab_json_escape "$mac")"
    printf '"mtu":%s,' "$(wifilab_network_uint "$mtu")"
    printf '"master":"%s",' "$(wifilab_json_escape "$master")"
    printf '"rx_bytes":%s,' "$(wifilab_network_uint "$rx_bytes")"
    printf '"tx_bytes":%s,' "$(wifilab_network_uint "$tx_bytes")"
    printf '"rx_packets":%s,' "$(wifilab_network_uint "$rx_packets")"
    printf '"tx_packets":%s,' "$(wifilab_network_uint "$tx_packets")"
    printf '"device_path":"%s",' "$(wifilab_json_escape "$device_path")"
    printf '"sysfs_path":"%s"' "$(wifilab_json_escape "$sysfs_path")"
    printf '}'
}

wifilab_network_interfaces_json() {
    local path iface first=1 count=0
    local -a ifaces=()

    for path in /sys/class/net/*; do
        [[ -d $path ]] || continue
        ifaces+=("${path##*/}")
    done

    count=${#ifaces[@]}
    printf '{"ok":true,"count":%d,"interfaces":[' "$count"

    for iface in "${ifaces[@]}"; do
        (( first )) || printf ','
        first=0
        wifilab_network_interface_json "$iface"
    done

    printf ']}\n'
}
