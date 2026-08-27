#!/usr/bin/env bash

# WiFiLab Phase 8H new-network authentication preflight.
# This module is read-only. It never accepts, reads, stores, logs, or emits a
# Wi-Fi secret and never creates/activates/deletes a NetworkManager profile.

set -o pipefail

wifilab_new_auth_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s","mutation_performed":false,"secret_fields_queried":false}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

wifilab_new_auth_security_class() {
    local security=${1-}
    local upper=${security^^}

    if [[ -z $security || $upper == OPEN || $upper == -- ]]; then
        printf 'open\n'
    elif [[ $upper == *802.1X* || $upper == *EAP* || $upper == *ENTERPRISE* ]]; then
        printf 'enterprise\n'
    elif [[ $upper == *WPA3* && $upper != *WPA2* && $upper != *WPA1* ]]; then
        printf 'sae\n'
    elif [[ $upper == *WPA* ]]; then
        # WPA2/WPA3 transition networks are intentionally treated as PSK-first
        # for the initial 8H contract. A later UI may expose SAE preference.
        printf 'psk\n'
    else
        printf 'unsupported\n'
    fi
}

wifilab_network_new_preflight_json() {
    local iface=${1-} ssid=${2-}

    [[ -n $iface ]] || {
        wifilab_new_auth_error_json "interface_required" "an explicit target wireless interface is required"
        return 2
    }
    [[ -n $ssid ]] || {
        wifilab_new_auth_error_json "ssid_required" "an explicit visible SSID is required"
        return 2
    }

    local inventory_json roles_json context_json profiles_json scan_json
    local iface_json role_json aps_json strongest_json saved_json
    local role protected mode nm_state nm_managed nm_type connection permanent_mac
    local security auth_class requires_secret supported
    local -a blocked=()

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_new_auth_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }
    roles_json=$(wifilab_network_roles_json) || {
        wifilab_new_auth_error_json "roles_failed" "could not derive interface roles"
        return 4
    }
    context_json=$(wifilab_network_context_json) || {
        wifilab_new_auth_error_json "context_failed" "could not collect route context"
        return 4
    }
    profiles_json=$(wifilab_network_profiles_json) || return $?

    iface_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // null' <<<"$inventory_json")
    [[ $iface_json != null ]] || {
        wifilab_new_auth_error_json "interface_not_found" "target interface is not present in the current kernel namespace"
        return 4
    }
    [[ $(jq -r '.wireless // false' <<<"$iface_json") == true ]] || {
        wifilab_new_auth_error_json "not_wireless" "target interface is not wireless"
        return 4
    }

    role_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // {}' <<<"$roles_json")
    role=$(jq -r '.role // "UNKNOWN"' <<<"$role_json")
    protected=$(jq -r '.protected // false' <<<"$role_json")
    mode=$(jq -r '.mode // ""' <<<"$iface_json")
    nm_state=$(jq -r '.nm_state // ""' <<<"$iface_json")
    nm_managed=$(jq -r 'if .nm_managed == null then "unknown" else (.nm_managed|tostring) end' <<<"$iface_json")
    nm_type=$(jq -r '.nm_type // ""' <<<"$iface_json")
    connection=$(jq -r '.connection // ""' <<<"$iface_json")
    permanent_mac=$(wifilab_iface_permanent_mac "$iface")

    [[ $role != PRIMARY ]] || blocked+=("primary_target_not_allowed")
    [[ $mode == managed ]] || blocked+=("wireless_mode_not_managed")
    [[ $nm_managed == true ]] || blocked+=("networkmanager_not_managing_interface")
    [[ $nm_type == wifi ]] || blocked+=("networkmanager_type_not_wifi")
    case "$nm_state" in
        unmanaged) blocked+=("networkmanager_state_unmanaged") ;;
        unavailable) blocked+=("networkmanager_state_unavailable") ;;
        unknown|'') blocked+=("networkmanager_state_unknown") ;;
    esac
    if [[ $protected == true || $nm_state == connected || -n $connection ]]; then
        blocked+=("target_has_active_or_protected_connection")
    fi

    scan_json=$(wifilab_network_wifi_scan_json "$iface") || {
        wifilab_new_auth_error_json "scan_failed" "could not obtain NetworkManager Wi-Fi discovery data"
        return 4
    }

    if [[ $(jq -r '.scan.ready // false' <<<"$scan_json") != true ]]; then
        blocked+=("networkmanager_scan_not_ready")
    fi

    aps_json=$(jq -c --arg ssid "$ssid" '[.access_points[] | select(.ssid == $ssid)] | sort_by(-.signal_percent)' <<<"$scan_json")
    if [[ $(jq 'length' <<<"$aps_json") -eq 0 ]]; then
        blocked+=("ssid_not_visible_on_target")
        strongest_json='null'
        security=''
        auth_class='unsupported'
        requires_secret=false
        supported=false
    else
        strongest_json=$(jq -c '.[0]' <<<"$aps_json")
        security=$(jq -r '.security // ""' <<<"$strongest_json")
        auth_class=$(wifilab_new_auth_security_class "$security")
        case "$auth_class" in
            open)
                requires_secret=false
                supported=true
                ;;
            psk|sae)
                requires_secret=true
                supported=true
                ;;
            enterprise)
                requires_secret=true
                supported=false
                blocked+=("enterprise_auth_not_supported_in_initial_8h")
                ;;
            *)
                requires_secret=false
                supported=false
                blocked+=("unsupported_security_mode")
                ;;
        esac
    fi

    saved_json=$(jq -c --arg ssid "$ssid" '[.profiles[] | select(.ssid == $ssid) | {uuid,name,active,active_device,interface_name}]' <<<"$profiles_json")
    if [[ $(jq 'length' <<<"$saved_json") -gt 0 ]]; then
        blocked+=("saved_profile_already_exists")
    fi

    local blocked_json='[]'
    if (( ${#blocked[@]} > 0 )); then
        blocked_json=$(printf '%s\n' "${blocked[@]}" | jq -R . | jq -cs 'unique | sort')
    fi

    jq -cn \
      --arg iface "$iface" \
      --arg ssid "$ssid" \
      --arg role "$role" \
      --arg mode "$mode" \
      --arg nm_state "$nm_state" \
      --arg nm_managed "$nm_managed" \
      --arg nm_type "$nm_type" \
      --arg connection "$connection" \
      --arg permanent_mac "$permanent_mac" \
      --arg security "$security" \
      --arg auth_class "$auth_class" \
      --argjson protected "$protected" \
      --argjson requires_secret "$requires_secret" \
      --argjson supported "$supported" \
      --argjson aps "$aps_json" \
      --argjson strongest "$strongest_json" \
      --argjson saved "$saved_json" \
      --argjson blocked "$blocked_json" \
      --argjson defaults "$(jq -c '.default_route_owners' <<<"$context_json")" '
      {
        ok:true,
        action:"new_network_auth_preflight",
        mutation_performed:false,
        secret_fields_queried:false,
        target:{
          interface:$iface,
          permanent_mac:$permanent_mac,
          role:$role,
          mode:$mode,
          nm_state:$nm_state,
          nm_managed:(if $nm_managed == "true" then true elif $nm_managed == "false" then false else null end),
          nm_type:$nm_type,
          connection:$connection,
          protected:$protected
        },
        network:{
          ssid:$ssid,
          visible_ap_count:($aps|length),
          strongest_ap:$strongest,
          security:$security,
          auth_class:$auth_class,
          requires_secret:$requires_secret,
          supported:$supported,
          existing_saved_profiles:$saved
        },
        planned_profile:{
          autoconnect:false,
          interface_name:$iface,
          permanent_mac_binding:"",
          bssid_binding:"",
          ipv4:{never_default:true,metric:900},
          ipv6:{never_default:true,metric:900}
        },
        route_before:{default_route_owners:$defaults},
        blocked_reasons:$blocked,
        ready_for_auth:(($blocked|length)==0 and $supported),
        credential_contract:{
          secret_in_json:false,
          secret_in_cli_arguments:false,
          secret_fields_queried:false,
          private_input_required:$requires_secret
        }
      }
    '
}
