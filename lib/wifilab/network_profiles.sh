#!/usr/bin/env bash

# WiFiLab Phase 8G-1 saved NetworkManager Wi-Fi profile inventory + preflight.
# This module is intentionally read-only. It never activates, disconnects,
# modifies, creates, forgets, or writes a NetworkManager connection profile.

set -o pipefail

wifilab_profiles_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s"}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

wifilab_nm_profile_field() {
    local uuid=$1 field=$2
    LC_ALL=C nmcli -e no -g "$field" connection show uuid "$uuid" 2>/dev/null | head -n1 || true
}

wifilab_bool_from_nm() {
    case "${1-}" in
        yes|true|1) printf 'true\n' ;;
        no|false|0|'') printf 'false\n' ;;
        *) printf 'false\n' ;;
    esac
}

wifilab_metric_json_value() {
    local value=${1-}
    if [[ $value =~ ^-?[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        printf 'null\n'
    fi
}

wifilab_profile_active_device() {
    local uuid=$1
    LC_ALL=C nmcli -t -e no -f UUID,DEVICE connection show --active 2>/dev/null |
        awk -F: -v uuid="$uuid" '$1 == uuid {print $2; exit}'
}

wifilab_network_profiles_json() {
    command -v nmcli >/dev/null 2>&1 || {
        wifilab_profiles_error_json "dependency_missing" "nmcli is required for saved-profile discovery"
        return 5
    }
    command -v jq >/dev/null 2>&1 || {
        wifilab_profiles_error_json "dependency_missing" "jq is required for saved-profile discovery"
        return 5
    }

    local raw line uuid type
    local name ssid autoconnect interface_name ipv4_never ipv6_never
    local ipv4_metric ipv6_metric ipv4_method ipv6_method active_device active
    local -a profiles=()

    raw=$(LC_ALL=C nmcli -t -e no -f UUID,TYPE connection show 2>/dev/null || true)

    while IFS= read -r line; do
        [[ -n $line ]] || continue
        uuid=${line%%:*}
        type=${line#*:}

        case "$type" in
            802-11-wireless|wifi) ;;
            *) continue ;;
        esac

        name=$(wifilab_nm_profile_field "$uuid" connection.id)
        ssid=$(wifilab_nm_profile_field "$uuid" 802-11-wireless.ssid)
        autoconnect=$(wifilab_bool_from_nm "$(wifilab_nm_profile_field "$uuid" connection.autoconnect)")
        interface_name=$(wifilab_nm_profile_field "$uuid" connection.interface-name)
        ipv4_never=$(wifilab_bool_from_nm "$(wifilab_nm_profile_field "$uuid" ipv4.never-default)")
        ipv6_never=$(wifilab_bool_from_nm "$(wifilab_nm_profile_field "$uuid" ipv6.never-default)")
        ipv4_metric=$(wifilab_metric_json_value "$(wifilab_nm_profile_field "$uuid" ipv4.route-metric)")
        ipv6_metric=$(wifilab_metric_json_value "$(wifilab_nm_profile_field "$uuid" ipv6.route-metric)")
        ipv4_method=$(wifilab_nm_profile_field "$uuid" ipv4.method)
        ipv6_method=$(wifilab_nm_profile_field "$uuid" ipv6.method)
        active_device=$(wifilab_profile_active_device "$uuid")
        [[ -n $active_device ]] && active=true || active=false

        profiles+=("$(jq -cn \
            --arg uuid "$uuid" \
            --arg name "$name" \
            --arg ssid "$ssid" \
            --arg type "$type" \
            --arg interface_name "$interface_name" \
            --arg active_device "$active_device" \
            --arg ipv4_method "$ipv4_method" \
            --arg ipv6_method "$ipv6_method" \
            --argjson autoconnect "$autoconnect" \
            --argjson active "$active" \
            --argjson ipv4_never "$ipv4_never" \
            --argjson ipv6_never "$ipv6_never" \
            --argjson ipv4_metric "$ipv4_metric" \
            --argjson ipv6_metric "$ipv6_metric" '
            {
              uuid:$uuid,
              name:$name,
              ssid:$ssid,
              type:$type,
              autoconnect:$autoconnect,
              interface_name:$interface_name,
              active:$active,
              active_device:$active_device,
              route_policy:{
                ipv4:{method:$ipv4_method, never_default:$ipv4_never, metric:$ipv4_metric},
                ipv6:{method:$ipv6_method, never_default:$ipv6_never, metric:$ipv6_metric}
              }
            }
        ')")
    done <<<"$raw"

    local profiles_json='[]'
    if (( ${#profiles[@]} > 0 )); then
        profiles_json=$(printf '%s\n' "${profiles[@]}" | jq -cs 'sort_by(.name, .uuid)')
    fi

    jq -cn --argjson profiles "$profiles_json" '
      {
        ok:true,
        source:"NetworkManager",
        profile_kind:"saved_wifi",
        secret_fields_queried:false,
        count:($profiles|length),
        profiles:$profiles
      }
    '
}

wifilab_network_profile_preflight_json() {
    local iface=${1-} uuid=${2-}

    [[ -n $iface ]] || {
        wifilab_profiles_error_json "interface_required" "an explicit target wireless interface is required"
        return 2
    }
    [[ -n $uuid ]] || {
        wifilab_profiles_error_json "profile_uuid_required" "an explicit saved profile UUID is required"
        return 2
    }

    local inventory_json roles_json context_json profiles_json
    local iface_json role_json profile_json
    local mode nm_state nm_managed nm_type role protected
    local profile_active profile_active_device profile_interface
    local ipv4_never ipv6_never
    local -a blocked=() risks=()

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_profiles_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }
    roles_json=$(wifilab_network_roles_json) || {
        wifilab_profiles_error_json "roles_failed" "could not derive interface roles"
        return 4
    }
    context_json=$(wifilab_network_context_json) || {
        wifilab_profiles_error_json "context_failed" "could not collect route context"
        return 4
    }
    profiles_json=$(wifilab_network_profiles_json) || return $?

    iface_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // null' <<<"$inventory_json")
    [[ $iface_json != null ]] || {
        wifilab_profiles_error_json "interface_not_found" "target interface is not present in the current kernel namespace"
        return 4
    }
    [[ $(jq -r '.wireless // false' <<<"$iface_json") == true ]] || {
        wifilab_profiles_error_json "not_wireless" "target interface is not wireless"
        return 4
    }

    profile_json=$(jq -c --arg uuid "$uuid" '[.profiles[] | select(.uuid == $uuid)][0] // null' <<<"$profiles_json")
    [[ $profile_json != null ]] || {
        wifilab_profiles_error_json "profile_not_found" "saved Wi-Fi profile UUID was not found"
        return 4
    }

    role_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // {}' <<<"$roles_json")
    mode=$(jq -r '.mode // ""' <<<"$iface_json")
    nm_state=$(jq -r '.nm_state // ""' <<<"$iface_json")
    nm_managed=$(jq -r 'if .nm_managed == null then "unknown" else (.nm_managed|tostring) end' <<<"$iface_json")
    nm_type=$(jq -r '.nm_type // ""' <<<"$iface_json")
    role=$(jq -r '.role // "UNKNOWN"' <<<"$role_json")
    protected=$(jq -r '.protected // false' <<<"$role_json")

    profile_active=$(jq -r '.active' <<<"$profile_json")
    profile_active_device=$(jq -r '.active_device // ""' <<<"$profile_json")
    profile_interface=$(jq -r '.interface_name // ""' <<<"$profile_json")
    ipv4_never=$(jq -r '.route_policy.ipv4.never_default' <<<"$profile_json")
    ipv6_never=$(jq -r '.route_policy.ipv6.never_default' <<<"$profile_json")

    [[ $mode == managed ]] || blocked+=("wireless_mode_not_managed")
    [[ $nm_managed == true ]] || blocked+=("networkmanager_not_managing_interface")
    [[ $nm_type == wifi ]] || blocked+=("networkmanager_type_not_wifi")
    case "$nm_state" in
        unmanaged) blocked+=("networkmanager_state_unmanaged") ;;
        unavailable) blocked+=("networkmanager_state_unavailable") ;;
        unknown|'') blocked+=("networkmanager_state_unknown") ;;
    esac

    if [[ -n $profile_interface && $profile_interface != "$iface" ]]; then
        blocked+=("profile_bound_to_other_interface")
    fi

    if [[ $profile_active == true && -n $profile_active_device && $profile_active_device != "$iface" ]]; then
        blocked+=("profile_active_on_other_device")
    fi

    if [[ $role == PRIMARY && $protected == true ]]; then
        blocked+=("protected_primary_mutation_requires_dedicated_action")
    fi

    if [[ $role != PRIMARY ]]; then
        [[ $ipv4_never == true ]] || risks+=("profile_may_install_ipv4_default_route")
        [[ $ipv6_never == true ]] || risks+=("profile_may_install_ipv6_default_route")
    fi

    local blocked_json='[]' risks_json='[]'
    if (( ${#blocked[@]} > 0 )); then
        blocked_json=$(printf '%s\n' "${blocked[@]}" | jq -R . | jq -cs 'unique | sort')
    fi
    if (( ${#risks[@]} > 0 )); then
        risks_json=$(printf '%s\n' "${risks[@]}" | jq -R . | jq -cs 'unique | sort')
    fi

    jq -cn \
      --arg iface "$iface" \
      --arg role "$role" \
      --arg mode "$mode" \
      --arg nm_state "$nm_state" \
      --arg nm_managed "$nm_managed" \
      --arg nm_type "$nm_type" \
      --argjson protected "$protected" \
      --argjson profile "$profile_json" \
      --argjson blocked "$blocked_json" \
      --argjson risks "$risks_json" \
      --argjson defaults "$(jq -c '.default_route_owners' <<<"$context_json")" '
      {
        ok:true,
        action:"saved_profile_connect_preflight",
        mutation_performed:false,
        target:{
          interface:$iface,
          role:$role,
          mode:$mode,
          nm_state:$nm_state,
          nm_managed:(if $nm_managed == "true" then true elif $nm_managed == "false" then false else null end),
          nm_type:$nm_type,
          protected:$protected
        },
        profile:$profile,
        route_before:{default_route_owners:$defaults},
        blocked_reasons:$blocked,
        route_risks:$risks,
        ready_for_mutation:(($blocked|length)==0),
        requires_post_route_validation:true
      }
    '
}
