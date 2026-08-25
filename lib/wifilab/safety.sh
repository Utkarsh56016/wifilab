#!/usr/bin/env bash

# WiFiLab safety guards layered over the base state controller.
# This file intentionally redefines wifilab_refuse_system_iface so both
# interactive CLI calls and the privileged helper protect route ownership.

set -o pipefail

wifilab_iface_has_default_route() {
    local iface=$1

    if command -v ip >/dev/null 2>&1; then
        ip -4 route show default dev "$iface" 2>/dev/null | grep -q '^default ' && return 0
        ip -6 route show default dev "$iface" 2>/dev/null | grep -q '^default ' && return 0
    fi
    return 1
}

wifilab_iface_is_protected() {
    local iface=$1 state connection

    state=$(wifilab_nm_state "$iface")
    connection=$(wifilab_nm_connection "$iface")

    [[ $state == connected && -n $connection ]] && return 0
    wifilab_iface_has_default_route "$iface" && return 0
    return 1
}

wifilab_refuse_system_iface() {
    local iface=$1 state connection reason=''

    state=$(wifilab_nm_state "$iface")
    connection=$(wifilab_nm_connection "$iface")

    if [[ $state == connected && -n $connection ]]; then
        reason="active NetworkManager connection: $connection"
    elif wifilab_iface_has_default_route "$iface"; then
        reason='interface owns a system default route'
    fi

    if [[ -n $reason ]]; then
        printf 'wifilab: refusing to mutate protected system Wi-Fi interface %s\n' "$iface" >&2
        printf 'wifilab: protection reason: %s\n' "$reason" >&2
        return 3
    fi
}
