#!/usr/bin/env bash

# WiFiLab state controller.
# All state-changing operations are scoped to one validated wireless interface.

set -o pipefail

wifilab_is_wireless_iface() {
    local iface=$1
    [[ -d "/sys/class/net/$iface/wireless" ]]
}

wifilab_require_wireless_iface() {
    local iface=${1-}
    [[ -n $iface ]] || {
        printf 'wifilab: missing wireless interface\n' >&2
        return 2
    }
    wifilab_is_wireless_iface "$iface" || {
        printf 'wifilab: %s is not a live wireless interface\n' "$iface" >&2
        return 2
    }
}

wifilab_is_connected_system_iface() {
    local iface=$1 state connection
    state=$(wifilab_nm_state "$iface")
    connection=$(wifilab_nm_connection "$iface")
    [[ $state == connected && -n $connection ]]
}

wifilab_refuse_system_iface() {
    local iface=$1
    if wifilab_is_connected_system_iface "$iface"; then
        printf 'wifilab: refusing to mutate active system Wi-Fi interface %s\n' "$iface" >&2
        printf 'wifilab: active connection: %s\n' "$(wifilab_nm_connection "$iface")" >&2
        return 3
    fi
}

wifilab_sudo() {
    if (( EUID == 0 )); then
        "$@"
    else
        sudo "$@"
    fi
}

wifilab_validate_type() {
    local iface=$1 expected=$2 actual
    actual=$(wifilab_iface_type "$iface")
    if [[ $actual != "$expected" ]]; then
        printf 'wifilab: validation failed for %s: expected type %s, got %s\n' \
            "$iface" "$expected" "${actual:-unknown}" >&2
        return 1
    fi
}

wifilab_validate_nm_managed() {
    local iface=$1 expected=$2 state
    state=$(wifilab_nm_state "$iface")

    case "$expected" in
        no)
            [[ $state == unmanaged ]] || {
                printf 'wifilab: validation failed for %s: expected NetworkManager unmanaged, got %s\n' \
                    "$iface" "${state:-unknown}" >&2
                return 1
            }
            ;;
        yes)
            [[ $state != unmanaged ]] || {
                printf 'wifilab: validation failed for %s: NetworkManager still reports unmanaged\n' "$iface" >&2
                return 1
            }
            ;;
    esac
}

wifilab_monitor_rollback() {
    local iface=$1
    wifilab_sudo ip link set "$iface" down >/dev/null 2>&1 || true
    wifilab_sudo iw dev "$iface" set type managed >/dev/null 2>&1 || true
    wifilab_sudo ip link set "$iface" up >/dev/null 2>&1 || true
    wifilab_sudo nmcli device set "$iface" managed yes >/dev/null 2>&1 || true
}

wifilab_monitor() {
    local iface=$1 phy current

    wifilab_require_wireless_iface "$iface" || return
    wifilab_refuse_system_iface "$iface" || return

    phy=$(wifilab_phy_for_iface "$iface")
    [[ $(wifilab_monitor_supported "$phy") == true ]] || {
        printf 'wifilab: %s (%s) does not advertise monitor-mode support\n' "$iface" "${phy:-unknown}" >&2
        return 4
    }

    current=$(wifilab_iface_type "$iface")
    if [[ $current == monitor ]]; then
        printf '%s is already in monitor mode\n' "$iface"
        return 0
    fi

    printf 'WiFiLab: %s -> monitor\n' "$iface"
    printf '  releasing only %s from NetworkManager\n' "$iface"

    if ! wifilab_sudo nmcli device set "$iface" managed no; then
        printf 'wifilab: failed to release %s from NetworkManager\n' "$iface" >&2
        return 1
    fi

    if ! wifilab_sudo ip link set "$iface" down; then
        wifilab_sudo nmcli device set "$iface" managed yes >/dev/null 2>&1 || true
        return 1
    fi

    if ! wifilab_sudo iw dev "$iface" set type monitor; then
        printf 'wifilab: mode transition failed; attempting rollback to managed\n' >&2
        wifilab_monitor_rollback "$iface"
        return 1
    fi

    # Development-only deterministic fault injection used to validate rollback.
    # It is inert unless explicitly set for a test invocation.
    if [[ ${WIFILAB_TEST_FAIL_AFTER_TYPE:-0} == 1 ]]; then
        printf 'wifilab: injected test failure after monitor type change; attempting rollback\n' >&2
        wifilab_monitor_rollback "$iface"
        return 70
    fi

    if ! wifilab_sudo ip link set "$iface" up; then
        printf 'wifilab: failed to bring %s up; attempting rollback\n' "$iface" >&2
        wifilab_monitor_rollback "$iface"
        return 1
    fi

    if ! wifilab_validate_type "$iface" monitor || ! wifilab_validate_nm_managed "$iface" no; then
        printf 'wifilab: post-transition validation failed; attempting restore\n' >&2
        wifilab_monitor_rollback "$iface"
        return 1
    fi

    printf '  mode        : monitor\n'
    printf '  NetworkManager: unmanaged\n'
}

wifilab_managed() {
    local iface=$1 current

    wifilab_require_wireless_iface "$iface" || return
    wifilab_refuse_system_iface "$iface" || return

    current=$(wifilab_iface_type "$iface")

    printf 'WiFiLab: %s -> managed\n' "$iface"

    if [[ $current != managed ]]; then
        wifilab_sudo ip link set "$iface" down || return 1
        if ! wifilab_sudo iw dev "$iface" set type managed; then
            wifilab_sudo ip link set "$iface" up >/dev/null 2>&1 || true
            return 1
        fi
        wifilab_sudo ip link set "$iface" up || return 1
    fi

    wifilab_sudo nmcli device set "$iface" managed yes || return 1

    wifilab_validate_type "$iface" managed || return 1
    wifilab_validate_nm_managed "$iface" yes || return 1

    printf '  mode        : managed\n'
    printf '  NetworkManager: managed\n'
}

wifilab_restore() {
    local iface=$1

    wifilab_require_wireless_iface "$iface" || return
    wifilab_refuse_system_iface "$iface" || return

    printf 'WiFiLab: restoring %s\n' "$iface"

    wifilab_sudo ip link set "$iface" down || return 1
    wifilab_sudo iw dev "$iface" set type managed || {
        wifilab_sudo ip link set "$iface" up >/dev/null 2>&1 || true
        return 1
    }
    wifilab_sudo ip link set "$iface" up || return 1
    wifilab_sudo nmcli device set "$iface" managed yes || return 1

    wifilab_validate_type "$iface" managed || return 1
    wifilab_validate_nm_managed "$iface" yes || return 1

    printf '  mode        : managed\n'
    printf '  NetworkManager: managed\n'
}

wifilab_channel() {
    local iface=$1 channel=$2 type

    wifilab_require_wireless_iface "$iface" || return
    wifilab_refuse_system_iface "$iface" || return

    [[ $channel =~ ^[0-9]+$ ]] || {
        printf 'wifilab: channel must be a positive integer\n' >&2
        return 2
    }

    type=$(wifilab_iface_type "$iface")
    [[ $type == monitor ]] || {
        printf 'wifilab: channel changes are allowed only while %s is in monitor mode\n' "$iface" >&2
        return 4
    }

    wifilab_sudo iw dev "$iface" set channel "$channel" || return 1

    if iw dev "$iface" info 2>/dev/null | grep -q "channel $channel "; then
        printf 'WiFiLab: %s channel -> %s\n' "$iface" "$channel"
    else
        printf 'wifilab: channel validation failed for %s\n' "$iface" >&2
        return 1
    fi
}
