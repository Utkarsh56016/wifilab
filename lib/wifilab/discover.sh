#!/usr/bin/env bash

# WiFiLab read-only adapter discovery backend.
# Phase 1 deliberately performs no state-changing operations.

set -o pipefail

WIFILAB_SEP=$'\x1f'

wifilab_have() {
    command -v "$1" >/dev/null 2>&1
}

wifilab_json_escape() {
    local s=${1-}
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

wifilab_wireless_ifaces() {
    local path
    for path in /sys/class/net/*; do
        [[ -d "$path/wireless" ]] || continue
        basename "$path"
    done
}

wifilab_phy_for_iface() {
    local iface=$1 target
    target=$(readlink -f "/sys/class/net/$iface/phy80211" 2>/dev/null) || return 0
    basename "$target"
}

wifilab_driver_for_iface() {
    local iface=$1 target
    target=$(readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null) || return 0
    basename "$target"
}

wifilab_udev_property() {
    local iface=$1 key=$2
    wifilab_have udevadm || return 0
    udevadm info -q property -p "/sys/class/net/$iface" 2>/dev/null |
        awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}'
}

wifilab_iface_type() {
    local iface=$1
    wifilab_have iw || return 0
    iw dev "$iface" info 2>/dev/null | awk '$1 == "type" {print $2; exit}'
}

wifilab_nm_state() {
    local iface=$1 raw
    wifilab_have nmcli || return 0
    raw=$(nmcli -g GENERAL.STATE device show "$iface" 2>/dev/null | head -n1)
    if [[ $raw =~ ^[0-9]+[[:space:]]+\((.*)\)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        printf '%s\n' "$raw"
    fi
}

wifilab_nm_connection() {
    local iface=$1 value
    wifilab_have nmcli || return 0
    value=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -n1)
    [[ $value == "--" ]] && value=""
    printf '%s\n' "$value"
}

wifilab_monitor_supported() {
    local phy=$1
    [[ -n $phy ]] || { printf 'unknown\n'; return; }
    wifilab_have iw || { printf 'unknown\n'; return; }

    if iw phy "$phy" info 2>/dev/null |
        sed -n '/Supported interface modes:/,/Band 1:/p' |
        grep -Eq '^[[:space:]]*\* monitor[[:space:]]*$'; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

wifilab_regdomain() {
    wifilab_have iw || return 0
    iw reg get 2>/dev/null |
        awk '/^country / {gsub(/:/, "", $2); print $2; exit}'
}

wifilab_human_device_name() {
    local iface=$1 bus=$2 vendor_id=$3 model_id=$4 device_path pci_addr usb_id result

    if [[ $bus == pci ]] && wifilab_have lspci; then
        device_path=$(readlink -f "/sys/class/net/$iface/device" 2>/dev/null)
        pci_addr=$(basename "$device_path")
        result=$(lspci -Dnn -s "$pci_addr" 2>/dev/null | sed -E 's/^[^ ]+ [^:]+: //')
        [[ -n $result ]] && { printf '%s\n' "$result"; return; }
    fi

    if [[ $bus == usb ]] && wifilab_have lsusb && [[ -n $vendor_id && -n $model_id ]]; then
        usb_id="${vendor_id#0x}:${model_id#0x}"
        result=$(lsusb -d "$usb_id" 2>/dev/null | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID [^ ]+ //')
        [[ -n $result ]] && { printf '%s\n' "$result"; return; }
    fi

    result=$(wifilab_udev_property "$iface" ID_MODEL)
    [[ -n $result ]] && printf '%s\n' "$result"
}

wifilab_role_for_iface() {
    local state=$1 connection=$2 bus=$3
    if [[ $state == connected && -n $connection ]]; then
        printf 'system\n'
    elif [[ $bus == usb ]]; then
        printf 'lab-candidate\n'
    else
        printf 'idle\n'
    fi
}

wifilab_collect_iface() {
    local iface=$1
    local phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path
    local monitor regdomain device_name role

    phy=$(wifilab_phy_for_iface "$iface")
    type=$(wifilab_iface_type "$iface")
    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
    operstate=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
    nm_state=$(wifilab_nm_state "$iface")
    connection=$(wifilab_nm_connection "$iface")
    driver=$(wifilab_driver_for_iface "$iface")
    bus=$(wifilab_udev_property "$iface" ID_BUS)
    vendor_id=$(wifilab_udev_property "$iface" ID_VENDOR_ID)
    model_id=$(wifilab_udev_property "$iface" ID_MODEL_ID)
    vendor=$(wifilab_udev_property "$iface" ID_VENDOR)
    model=$(wifilab_udev_property "$iface" ID_MODEL)
    path=$(wifilab_udev_property "$iface" ID_PATH)
    monitor=$(wifilab_monitor_supported "$phy")
    regdomain=$(wifilab_regdomain)
    device_name=$(wifilab_human_device_name "$iface" "$bus" "$vendor_id" "$model_id")
    role=$(wifilab_role_for_iface "$nm_state" "$connection" "$bus")

    printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
        "$iface" "$WIFILAB_SEP" "$phy" "$WIFILAB_SEP" "$type" "$WIFILAB_SEP" "$mac" "$WIFILAB_SEP" \
        "$operstate" "$WIFILAB_SEP" "$nm_state" "$WIFILAB_SEP" "$connection" "$WIFILAB_SEP" "$driver" "$WIFILAB_SEP" \
        "$bus" "$WIFILAB_SEP" "$vendor_id" "$WIFILAB_SEP" "$model_id" "$WIFILAB_SEP" "$vendor" "$WIFILAB_SEP" \
        "$model" "$WIFILAB_SEP" "$path" "$WIFILAB_SEP" "$monitor" "$WIFILAB_SEP" "$regdomain" "$WIFILAB_SEP" "$role|$device_name"
}

wifilab_discover_records() {
    local iface
    while IFS= read -r iface; do
        [[ -n $iface ]] || continue
        wifilab_collect_iface "$iface"
    done < <(wifilab_wireless_ifaces)
}

wifilab_discover_json() {
    local first=1
    local iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail role device_name

    printf '{"adapters":['
    while IFS="$WIFILAB_SEP" read -r iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail; do
        role=${tail%%|*}
        device_name=${tail#*|}
        (( first )) || printf ','
        first=0
        printf '{'
        printf '"interface":"%s",' "$(wifilab_json_escape "$iface")"
        printf '"phy":"%s",' "$(wifilab_json_escape "$phy")"
        printf '"type":"%s",' "$(wifilab_json_escape "$type")"
        printf '"mac":"%s",' "$(wifilab_json_escape "$mac")"
        printf '"operstate":"%s",' "$(wifilab_json_escape "$operstate")"
        printf '"nm_state":"%s",' "$(wifilab_json_escape "$nm_state")"
        printf '"connection":"%s",' "$(wifilab_json_escape "$connection")"
        printf '"driver":"%s",' "$(wifilab_json_escape "$driver")"
        printf '"bus":"%s",' "$(wifilab_json_escape "$bus")"
        printf '"vendor_id":"%s",' "$(wifilab_json_escape "$vendor_id")"
        printf '"model_id":"%s",' "$(wifilab_json_escape "$model_id")"
        printf '"vendor":"%s",' "$(wifilab_json_escape "$vendor")"
        printf '"model":"%s",' "$(wifilab_json_escape "$model")"
        printf '"device_name":"%s",' "$(wifilab_json_escape "$device_name")"
        printf '"path":"%s",' "$(wifilab_json_escape "$path")"
        printf '"monitor_supported":%s,' "$monitor"
        printf '"regdomain":"%s",' "$(wifilab_json_escape "$regdomain")"
        printf '"role":"%s"' "$(wifilab_json_escape "$role")"
        printf '}'
    done < <(wifilab_discover_records)
    printf ']}\n'
}

wifilab_discover_human() {
    local iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail role device_name

    while IFS="$WIFILAB_SEP" read -r iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail; do
        role=${tail%%|*}
        device_name=${tail#*|}

        printf '%s\n' "$iface"
        printf '  Role       : %s\n' "${role:-unknown}"
        printf '  Device     : %s\n' "${device_name:-unknown}"
        printf '  PHY        : %s\n' "${phy:-unknown}"
        printf '  Driver     : %s\n' "${driver:-unknown}"
        printf '  Bus        : %s\n' "${bus:-unknown}"
        [[ -n $vendor_id || -n $model_id ]] && printf '  Device ID  : %s:%s\n' "${vendor_id#0x}" "${model_id#0x}"
        printf '  Mode       : %s\n' "${type:-unknown}"
        printf '  Link       : %s\n' "${operstate:-unknown}"
        printf '  NM state   : %s\n' "${nm_state:-unknown}"
        [[ -n $connection ]] && printf '  Connection : %s\n' "$connection"
        printf '  Monitor    : %s\n' "$monitor"
        printf '  Regdomain  : %s\n' "${regdomain:-unknown}"
        printf '  MAC        : %s\n' "${mac:-unknown}"
        printf '\n'
    done < <(wifilab_discover_records)
}
