#!/usr/bin/env bash

# WiFiLab machine-readable contract hardening.
# Loaded after discover.sh and safety.sh to keep JSON valid even when optional
# capability probes are unavailable.

set -o pipefail

wifilab_json_bool_or_null() {
    case ${1-} in
        true|false) printf '%s' "$1" ;;
        *) printf 'null' ;;
    esac
}

wifilab_discover_json() {
    local first=1
    local iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail role device_name
    local protected=false

    printf '{"adapters":['
    while IFS="$WIFILAB_SEP" read -r iface phy type mac operstate nm_state connection driver bus vendor_id model_id vendor model path monitor regdomain tail; do
        role=${tail%%|*}
        device_name=${tail#*|}
        protected=false
        if declare -F wifilab_iface_is_protected >/dev/null 2>&1 && wifilab_iface_is_protected "$iface"; then
            protected=true
        fi

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
        printf '"monitor_supported":'
        wifilab_json_bool_or_null "$monitor"
        printf ','
        printf '"regdomain":"%s",' "$(wifilab_json_escape "$regdomain")"
        printf '"role":"%s",' "$(wifilab_json_escape "$role")"
        printf '"protected":%s' "$protected"
        printf '}'
    done < <(wifilab_discover_records)
    printf ']}\n'
}
