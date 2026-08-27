#!/usr/bin/env bash

# WiFiLab Phase 8F NetworkManager-backed Wi-Fi discovery.
# This module is adapter-explicit and discovery-only. It may request a
# NetworkManager scan, but it never changes connection profiles, routes,
# interface ownership, radio mode, or saved credentials.

set -o pipefail

wifilab_wifi_scan_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s"}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

# Parse one nmcli terse row. nmcli escapes ':' and '\\' when -e yes is used,
# so BSSIDs and SSIDs containing ':' must not be split with plain IFS=':'.
wifilab_nmcli_split_escaped_colon() {
    local line=$1 ch field='' escaped=false i
    WIFILAB_NMCLI_FIELDS=()

    for (( i=0; i<${#line}; i++ )); do
        ch=${line:i:1}
        if [[ $escaped == true ]]; then
            field+="$ch"
            escaped=false
        elif [[ $ch == \\ ]]; then
            escaped=true
        elif [[ $ch == ':' ]]; then
            WIFILAB_NMCLI_FIELDS+=("$field")
            field=''
        else
            field+="$ch"
        fi
    done

    [[ $escaped == true ]] && field+='\'
    WIFILAB_NMCLI_FIELDS+=("$field")
}

wifilab_nmcli_unescape_value() {
    local value=$1 ch out='' escaped=false i
    for (( i=0; i<${#value}; i++ )); do
        ch=${value:i:1}
        if [[ $escaped == true ]]; then
            out+="$ch"
            escaped=false
        elif [[ $ch == \\ ]]; then
            escaped=true
        else
            out+="$ch"
        fi
    done
    [[ $escaped == true ]] && out+='\'
    printf '%s\n' "$out"
}

wifilab_wifi_band_for_frequency() {
    local freq=${1-}
    if [[ ! $freq =~ ^[0-9]+$ ]]; then
        printf 'unknown\n'
    elif (( freq >= 2400 && freq <= 2500 )); then
        printf '2.4GHz\n'
    elif (( freq >= 4900 && freq < 5925 )); then
        printf '5GHz\n'
    elif (( freq >= 5925 && freq <= 7125 )); then
        printf '6GHz\n'
    elif (( freq >= 57000 && freq <= 71000 )); then
        printf '60GHz\n'
    else
        printf 'unknown\n'
    fi
}

# Saved-profile discovery intentionally reads only UUID/type and SSID. No
# password, PSK, 802.1X secret, or secret-agent field is queried or emitted.
wifilab_wifi_saved_ssids_json() {
    local raw line uuid type ssid
    local -a records=()

    raw=$(LC_ALL=C nmcli -t -e yes -f UUID,TYPE connection show 2>/dev/null || true)

    while IFS= read -r line; do
        [[ -n $line ]] || continue
        wifilab_nmcli_split_escaped_colon "$line"
        (( ${#WIFILAB_NMCLI_FIELDS[@]} >= 2 )) || continue

        uuid=${WIFILAB_NMCLI_FIELDS[0]}
        type=${WIFILAB_NMCLI_FIELDS[1]}
        case "$type" in
            802-11-wireless|wifi) ;;
            *) continue ;;
        esac

        ssid=$(LC_ALL=C nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null | head -n1 || true)
        ssid=$(wifilab_nmcli_unescape_value "$ssid")
        [[ -n $ssid ]] || continue
        records+=("$(jq -cn --arg ssid "$ssid" '$ssid')")
    done <<<"$raw"

    if (( ${#records[@]} == 0 )); then
        printf '[]\n'
    else
        printf '%s\n' "${records[@]}" | jq -cs 'unique | sort'
    fi
}

wifilab_network_wifi_scan_json() {
    local iface=${1-}
    local inventory_json roles_json iface_json role_json
    local mode nm_state nm_managed role phy driver connection nm_type
    local saved_ssids_json raw line scan_rc=0
    local in_use ssid bssid signal freq channel security band connected hidden saved
    local aps_json warnings_json
    local -a blocked_reasons=() access_points=() warnings=()

    [[ -n $iface ]] || {
        wifilab_wifi_scan_error_json "interface_required" "an explicit wireless interface is required"
        return 2
    }

    command -v nmcli >/dev/null 2>&1 || {
        wifilab_wifi_scan_error_json "dependency_missing" "nmcli is required for Wi-Fi discovery"
        return 5
    }
    command -v jq >/dev/null 2>&1 || {
        wifilab_wifi_scan_error_json "dependency_missing" "jq is required for Wi-Fi discovery"
        return 5
    }

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_wifi_scan_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }
    roles_json=$(wifilab_network_roles_json) || {
        wifilab_wifi_scan_error_json "roles_failed" "could not derive interface roles"
        return 4
    }

    iface_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // null' <<<"$inventory_json")
    [[ $iface_json != null ]] || {
        wifilab_wifi_scan_error_json "interface_not_found" "requested interface is not present in the current kernel namespace"
        return 4
    }

    [[ $(jq -r '.wireless // false' <<<"$iface_json") == true ]] || {
        wifilab_wifi_scan_error_json "not_wireless" "requested interface is not a wireless netdev"
        return 4
    }

    role_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // {}' <<<"$roles_json")
    mode=$(jq -r '.mode // ""' <<<"$iface_json")
    nm_state=$(jq -r '.nm_state // ""' <<<"$iface_json")
    nm_managed=$(jq -r 'if .nm_managed == null then "unknown" else (.nm_managed|tostring) end' <<<"$iface_json")
    nm_type=$(jq -r '.nm_type // ""' <<<"$iface_json")
    role=$(jq -r '.role // "UNKNOWN"' <<<"$role_json")
    phy=$(jq -r '.phy // ""' <<<"$iface_json")
    driver=$(jq -r '.driver // ""' <<<"$iface_json")
    connection=$(jq -r '.connection // ""' <<<"$iface_json")

    [[ $mode == managed ]] || blocked_reasons+=("wireless_mode_not_managed")
    [[ $nm_managed == true ]] || blocked_reasons+=("networkmanager_not_managing_interface")
    [[ $nm_type == wifi ]] || blocked_reasons+=("networkmanager_type_not_wifi")
    case "$nm_state" in
        unmanaged) blocked_reasons+=("networkmanager_state_unmanaged") ;;
        unavailable) blocked_reasons+=("networkmanager_state_unavailable") ;;
        unknown|'') blocked_reasons+=("networkmanager_state_unknown") ;;
    esac

    if (( ${#blocked_reasons[@]} > 0 )); then
        printf '%s\n' "${blocked_reasons[@]}" | jq -R . | jq -cs \
          --arg iface "$iface" \
          --arg role "$role" \
          --arg mode "$mode" \
          --arg nm_state "$nm_state" \
          --arg nm_managed "$nm_managed" \
          --arg nm_type "$nm_type" \
          --arg phy "$phy" \
          --arg driver "$driver" \
          --arg connection "$connection" '
          unique as $reasons |
          {
            ok:true,
            source:"NetworkManager",
            scan_kind:"connectable_wifi",
            interface:{
              name:$iface,
              role:$role,
              mode:$mode,
              nm_state:$nm_state,
              nm_managed:(if $nm_managed == "true" then true elif $nm_managed == "false" then false else null end),
              nm_type:$nm_type,
              phy:$phy,
              driver:$driver,
              connection:$connection
            },
            scan:{
              ready:false,
              rescan_requested:false,
              blocked_reasons:$reasons,
              access_point_count:0
            },
            access_points:[],
            warnings:[]
          }
        '
        return 0
    fi

    saved_ssids_json=$(wifilab_wifi_saved_ssids_json)

    # This requests only NetworkManager Wi-Fi discovery. It does not activate,
    # disconnect, modify, or create any connection profile.
    if raw=$(LC_ALL=C nmcli -t -e yes \
        -f IN-USE,SSID,BSSID,SIGNAL,FREQ,CHAN,SECURITY \
        device wifi list ifname "$iface" --rescan yes 2>/dev/null); then
        scan_rc=0
    else
        scan_rc=$?
    fi

    if (( scan_rc != 0 )); then
        wifilab_wifi_scan_error_json "scan_failed" "NetworkManager could not scan the requested wireless interface"
        return 4
    fi

    while IFS= read -r line; do
        [[ -n $line ]] || continue
        wifilab_nmcli_split_escaped_colon "$line"
        if (( ${#WIFILAB_NMCLI_FIELDS[@]} != 7 )); then
            warnings+=("malformed_nmcli_scan_row")
            continue
        fi

        in_use=${WIFILAB_NMCLI_FIELDS[0]}
        ssid=${WIFILAB_NMCLI_FIELDS[1]}
        bssid=${WIFILAB_NMCLI_FIELDS[2]}
        signal=${WIFILAB_NMCLI_FIELDS[3]}
        freq=${WIFILAB_NMCLI_FIELDS[4]}
        channel=${WIFILAB_NMCLI_FIELDS[5]}
        security=${WIFILAB_NMCLI_FIELDS[6]}

        [[ $signal =~ ^[0-9]+$ ]] || signal=0
        if [[ $freq =~ ^[[:space:]]*([0-9]+)([[:space:]]*MHz)?[[:space:]]*$ ]]; then
            freq=${BASH_REMATCH[1]}
        else
            freq=0
        fi
        [[ $channel =~ ^[0-9]+$ ]] || channel=0

        band=$(wifilab_wifi_band_for_frequency "$freq")
        case "$in_use" in
            '*'|yes) connected=true ;;
            *) connected=false ;;
        esac
        [[ -z $ssid ]] && hidden=true || hidden=false

        if jq -e --arg ssid "$ssid" 'index($ssid) != null' <<<"$saved_ssids_json" >/dev/null; then
            saved=true
        else
            saved=false
        fi

        [[ -n $security && $security != -- ]] || security='open'

        access_points+=("$(jq -cn \
            --arg ssid "$ssid" \
            --arg bssid "$bssid" \
            --arg band "$band" \
            --arg security "$security" \
            --argjson signal "$signal" \
            --argjson frequency "$freq" \
            --argjson channel "$channel" \
            --argjson connected "$connected" \
            --argjson hidden "$hidden" \
            --argjson saved "$saved" '
            {
              ssid:$ssid,
              bssid:$bssid,
              signal_percent:$signal,
              rssi_dbm:null,
              signal_source:"networkmanager_percent",
              frequency_mhz:$frequency,
              channel:$channel,
              band:$band,
              security:$security,
              connected:$connected,
              saved_profile:$saved,
              hidden:$hidden
            }
        ')")
    done <<<"$raw"

    if (( ${#access_points[@]} == 0 )); then
        aps_json='[]'
    else
        aps_json=$(printf '%s\n' "${access_points[@]}" | jq -cs 'sort_by([-.signal_percent, .ssid, .bssid])')
    fi

    if (( ${#warnings[@]} == 0 )); then
        warnings_json='[]'
    else
        warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -cs 'unique')
    fi

    jq -cn \
        --arg iface "$iface" \
        --arg role "$role" \
        --arg mode "$mode" \
        --arg nm_state "$nm_state" \
        --arg nm_managed "$nm_managed" \
        --arg nm_type "$nm_type" \
        --arg phy "$phy" \
        --arg driver "$driver" \
        --arg connection "$connection" \
        --argjson aps "$aps_json" \
        --argjson warnings "$warnings_json" '
        {
          ok:true,
          source:"NetworkManager",
          scan_kind:"connectable_wifi",
          interface:{
            name:$iface,
            role:$role,
            mode:$mode,
            nm_state:$nm_state,
            nm_managed:(if $nm_managed == "true" then true elif $nm_managed == "false" then false else null end),
            nm_type:$nm_type,
            phy:$phy,
            driver:$driver,
            connection:$connection
          },
          scan:{
            ready:true,
            rescan_requested:true,
            blocked_reasons:[],
            access_point_count:($aps|length)
          },
          access_points:$aps,
          warnings:$warnings
        }
    '
}
