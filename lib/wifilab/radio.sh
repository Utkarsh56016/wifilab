#!/usr/bin/env bash

# WiFiLab read-only radio/channel helpers.
# The kernel regulatory database remains authoritative; this file never changes it.

set -o pipefail

wifilab_iface_channel() {
    local iface=$1
    iw dev "$iface" info 2>/dev/null | awk '$1 == "channel" {print $2; exit}'
}

wifilab_iface_frequency_mhz() {
    local iface=$1 value
    value=$(iw dev "$iface" info 2>/dev/null | awk '$1 == "channel" {print $3; exit}')
    value=${value#(}
    printf '%s\n' "${value:-0}"
}

wifilab_channels_json() {
    local iface phy line frequency channel tail first=1
    local disabled no_ir radar band

    iface=$(wifilab_resolve_selected) || return $?
    phy=$(wifilab_phy_for_iface "$iface")
    [[ -n $phy ]] || {
        printf 'wifilab: unable to resolve PHY for %s\n' "$iface" >&2
        return 4
    }

    printf '{"interface":"%s","phy":"%s","regdomain":"%s","channels":[' \
        "$(wifilab_json_escape "$iface")" \
        "$(wifilab_json_escape "$phy")" \
        "$(wifilab_json_escape "$(wifilab_regdomain)")"

    while IFS= read -r line; do
        [[ $line =~ \*[[:space:]]+([0-9]+)[[:space:]]+MHz[[:space:]]+\[([0-9]+)\](.*)$ ]] || continue
        frequency=${BASH_REMATCH[1]}
        channel=${BASH_REMATCH[2]}
        tail=${BASH_REMATCH[3]}

        disabled=false
        no_ir=false
        radar=false
        [[ $tail == *disabled* ]] && disabled=true
        [[ $tail == *"no IR"* || $tail == *"no-ir"* ]] && no_ir=true
        [[ $tail == *"radar detection"* || $tail == *radar* ]] && radar=true

        if (( frequency < 3000 )); then
            band='2.4 GHz'
        elif (( frequency < 5925 )); then
            band='5 GHz'
        else
            band='6 GHz'
        fi

        (( first )) || printf ','
        first=0
        printf '{"channel":%s,"frequency_mhz":%s,"band":"%s","disabled":%s,"no_ir":%s,"radar":%s}' \
            "$channel" "$frequency" "$(wifilab_json_escape "$band")" "$disabled" "$no_ir" "$radar"
    done < <(iw phy "$phy" channels 2>/dev/null)

    printf ']}\n'
}
