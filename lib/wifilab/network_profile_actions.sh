#!/usr/bin/env bash

# WiFiLab Phase 8G guarded NetworkManager saved-profile actions.
# All mutations are adapter-explicit, user-scoped NetworkManager operations.
# No secrets are queried or passed. PRIMARY/default-route ownership is measured
# before and after every mutation, with best-effort rollback on validation loss.

set -o pipefail

wifilab_profile_action_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s","mutation_performed":false}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

wifilab_default_owners_json() {
    local context_json=$1
    jq -c '{ipv4:(.default_route_owners.ipv4 // [] | sort),ipv6:(.default_route_owners.ipv6 // [] | sort)}' <<<"$context_json"
}

wifilab_profile_active_uuid_on_iface() {
    local iface=$1
    LC_ALL=C nmcli -t -e no -f UUID,TYPE,DEVICE connection show --active 2>/dev/null |
        awk -F: -v iface="$iface" '($2 == "802-11-wireless" || $2 == "wifi") && $3 == iface {print $1; exit}'
}

wifilab_profile_action_blocked_json() {
    local action=$1 preflight_json=$2 reason=${3-}
    jq -cn \
      --arg action "$action" \
      --arg reason "$reason" \
      --argjson preflight "$preflight_json" '
      ($preflight.blocked_reasons // []) as $existing |
      ($existing + (if $reason == "" then [] else [$reason] end) | unique | sort) as $blocked |
      {
        ok:true,
        action:$action,
        mutation_performed:false,
        target:$preflight.target,
        profile:$preflight.profile,
        route_before:$preflight.route_before,
        blocked_reasons:$blocked,
        route_risks:($preflight.route_risks // []),
        ready_for_mutation:false,
        requires_post_route_validation:true
      }
    '
}

wifilab_network_profile_connect_json() {
    local iface=${1-} uuid=${2-} action=${3:-saved_profile_connect}
    local preflight_json ready role active active_device
    local route_risk_count before_context before_defaults
    local after_context after_defaults post_active_device route_safe active_ok
    local rollback_attempted=false rollback_succeeded=false rollback_context rollback_defaults

    preflight_json=$(wifilab_network_profile_preflight_json "$iface" "$uuid") || return $?
    ready=$(jq -r '.ready_for_mutation' <<<"$preflight_json")
    role=$(jq -r '.target.role // "UNKNOWN"' <<<"$preflight_json")
    active=$(jq -r '.profile.active // false' <<<"$preflight_json")
    active_device=$(jq -r '.profile.active_device // ""' <<<"$preflight_json")
    route_risk_count=$(jq -r '.route_risks | length' <<<"$preflight_json")

    if [[ $role == PRIMARY ]]; then
        wifilab_profile_action_blocked_json "$action" "$preflight_json" "primary_target_not_allowed"
        return 3
    fi

    if [[ $ready != true ]]; then
        wifilab_profile_action_blocked_json "$action" "$preflight_json"
        return 3
    fi

    if (( route_risk_count > 0 )); then
        wifilab_profile_action_blocked_json "$action" "$preflight_json" "profile_default_route_policy_unsafe"
        return 3
    fi

    if [[ $active == true && $active_device == "$iface" ]]; then
        jq -cn \
          --arg action "$action" \
          --argjson preflight "$preflight_json" '
          {
            ok:true,
            action:$action,
            mutation_performed:false,
            already_active:true,
            target:$preflight.target,
            profile:$preflight.profile,
            route_before:$preflight.route_before,
            route_after:$preflight.route_before,
            route_unchanged:true,
            blocked_reasons:[],
            route_risks:[],
            ready_for_mutation:true,
            post_validation:{profile_active_on_target:true,default_route_owners_unchanged:true},
            rollback:{attempted:false,succeeded:false}
          }
        '
        return 0
    fi

    before_context=$(wifilab_network_context_json) || {
        wifilab_profile_action_error_json "context_failed" "could not snapshot routes before activation"
        return 4
    }
    before_defaults=$(wifilab_default_owners_json "$before_context")

    if ! LC_ALL=C nmcli -w 30 connection up uuid "$uuid" ifname "$iface" >/dev/null 2>&1; then
        jq -cn \
          --arg action "$action" \
          --arg iface "$iface" \
          --arg uuid "$uuid" \
          --argjson before "$before_defaults" '
          {
            ok:false,
            error:"connection_activation_failed",
            action:$action,
            mutation_performed:false,
            target:{interface:$iface},
            profile:{uuid:$uuid},
            route_before:{default_route_owners:$before},
            rollback:{attempted:false,succeeded:false}
          }
        '
        return 1
    fi

    after_context=$(wifilab_network_context_json 2>/dev/null || true)
    if [[ -n $after_context ]]; then
        after_defaults=$(wifilab_default_owners_json "$after_context")
    else
        after_defaults='{"ipv4":[],"ipv6":[]}'
    fi

    post_active_device=$(wifilab_profile_active_device "$uuid")
    [[ $post_active_device == "$iface" ]] && active_ok=true || active_ok=false
    [[ $before_defaults == "$after_defaults" ]] && route_safe=true || route_safe=false

    if [[ $active_ok == true && $route_safe == true ]]; then
        jq -cn \
          --arg action "$action" \
          --arg iface "$iface" \
          --arg uuid "$uuid" \
          --arg active_device "$post_active_device" \
          --argjson before "$before_defaults" \
          --argjson after "$after_defaults" '
          {
            ok:true,
            action:$action,
            mutation_performed:true,
            target:{interface:$iface},
            profile:{uuid:$uuid,active_device:$active_device},
            route_before:{default_route_owners:$before},
            route_after:{default_route_owners:$after},
            route_unchanged:true,
            post_validation:{profile_active_on_target:true,default_route_owners_unchanged:true},
            rollback:{attempted:false,succeeded:false}
          }
        '
        return 0
    fi

    rollback_attempted=true
    LC_ALL=C nmcli -w 15 connection down uuid "$uuid" >/dev/null 2>&1 || \
        LC_ALL=C nmcli -w 15 device disconnect "$iface" >/dev/null 2>&1 || true

    rollback_context=$(wifilab_network_context_json 2>/dev/null || true)
    if [[ -n $rollback_context ]]; then
        rollback_defaults=$(wifilab_default_owners_json "$rollback_context")
        if [[ $rollback_defaults == "$before_defaults" ]] && [[ $(wifilab_profile_active_device "$uuid") != "$iface" ]]; then
            rollback_succeeded=true
        fi
    else
        rollback_defaults='{"ipv4":[],"ipv6":[]}'
    fi

    jq -cn \
      --arg action "$action" \
      --arg iface "$iface" \
      --arg uuid "$uuid" \
      --arg active_device "$post_active_device" \
      --argjson active_ok "$active_ok" \
      --argjson route_safe "$route_safe" \
      --argjson before "$before_defaults" \
      --argjson after "$after_defaults" \
      --argjson rollback_attempted "$rollback_attempted" \
      --argjson rollback_succeeded "$rollback_succeeded" \
      --argjson rollback_after "$rollback_defaults" '
      {
        ok:false,
        error:"post_activation_validation_failed",
        action:$action,
        mutation_performed:true,
        target:{interface:$iface},
        profile:{uuid:$uuid,active_device:$active_device},
        route_before:{default_route_owners:$before},
        route_after:{default_route_owners:$after},
        post_validation:{profile_active_on_target:$active_ok,default_route_owners_unchanged:$route_safe},
        rollback:{attempted:$rollback_attempted,succeeded:$rollback_succeeded,route_after:{default_route_owners:$rollback_after}}
      }
    '
    return 6
}

wifilab_network_profile_reconnect_json() {
    local iface=${1-} uuid=${2-}
    wifilab_network_profile_connect_json "$iface" "$uuid" "saved_profile_reconnect"
}

wifilab_network_profile_disconnect_json() {
    local iface=${1-}
    [[ -n $iface ]] || {
        wifilab_profile_action_error_json "interface_required" "an explicit target wireless interface is required"
        return 2
    }

    local inventory_json roles_json context_json iface_json role_json
    local role protected mode nm_managed nm_state active_uuid
    local before_defaults after_context after_defaults route_safe disconnected_ok
    local rollback_attempted=false rollback_succeeded=false rollback_context rollback_defaults

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_profile_action_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }
    roles_json=$(wifilab_network_roles_json) || {
        wifilab_profile_action_error_json "roles_failed" "could not derive interface roles"
        return 4
    }
    context_json=$(wifilab_network_context_json) || {
        wifilab_profile_action_error_json "context_failed" "could not snapshot routes before disconnect"
        return 4
    }

    iface_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // null' <<<"$inventory_json")
    [[ $iface_json != null ]] || {
        wifilab_profile_action_error_json "interface_not_found" "target interface is not present"
        return 4
    }
    [[ $(jq -r '.wireless // false' <<<"$iface_json") == true ]] || {
        wifilab_profile_action_error_json "not_wireless" "target interface is not wireless"
        return 4
    }

    role_json=$(jq -c --arg iface "$iface" '[.interfaces[] | select(.name == $iface)][0] // {}' <<<"$roles_json")
    role=$(jq -r '.role // "UNKNOWN"' <<<"$role_json")
    protected=$(jq -r '.protected // false' <<<"$role_json")
    mode=$(jq -r '.mode // ""' <<<"$iface_json")
    nm_managed=$(jq -r 'if .nm_managed == null then "unknown" else (.nm_managed|tostring) end' <<<"$iface_json")
    nm_state=$(jq -r '.nm_state // ""' <<<"$iface_json")
    before_defaults=$(wifilab_default_owners_json "$context_json")

    if [[ $role == PRIMARY || $protected == true ]]; then
        jq -cn \
          --arg iface "$iface" --arg role "$role" --argjson protected "$protected" --argjson before "$before_defaults" '
          {
            ok:true,
            action:"saved_profile_disconnect",
            mutation_performed:false,
            target:{interface:$iface,role:$role,protected:$protected},
            route_before:{default_route_owners:$before},
            blocked_reasons:["protected_primary_disconnect_not_allowed"],
            ready_for_mutation:false
          }
        '
        return 3
    fi

    if [[ $mode != managed || $nm_managed != true || $nm_state == unmanaged ]]; then
        jq -cn \
          --arg iface "$iface" --arg role "$role" --arg mode "$mode" --arg nm_state "$nm_state" --arg nm_managed "$nm_managed" --argjson before "$before_defaults" '
          {
            ok:true,
            action:"saved_profile_disconnect",
            mutation_performed:false,
            target:{interface:$iface,role:$role,mode:$mode,nm_state:$nm_state,nm_managed:(if $nm_managed=="true" then true elif $nm_managed=="false" then false else null end)},
            route_before:{default_route_owners:$before},
            blocked_reasons:["target_not_managed_for_disconnect"],
            ready_for_mutation:false
          }
        '
        return 3
    fi

    active_uuid=$(wifilab_profile_active_uuid_on_iface "$iface")
    if [[ -z $active_uuid ]]; then
        jq -cn \
          --arg iface "$iface" --arg role "$role" --argjson before "$before_defaults" '
          {
            ok:true,
            action:"saved_profile_disconnect",
            mutation_performed:false,
            already_disconnected:true,
            target:{interface:$iface,role:$role},
            route_before:{default_route_owners:$before},
            route_after:{default_route_owners:$before},
            route_unchanged:true,
            ready_for_mutation:true,
            rollback:{attempted:false,succeeded:false}
          }
        '
        return 0
    fi

    if ! LC_ALL=C nmcli -w 20 device disconnect "$iface" >/dev/null 2>&1; then
        jq -cn --arg iface "$iface" --arg uuid "$active_uuid" --argjson before "$before_defaults" '
          {ok:false,error:"disconnect_failed",action:"saved_profile_disconnect",mutation_performed:false,target:{interface:$iface},profile:{uuid:$uuid},route_before:{default_route_owners:$before},rollback:{attempted:false,succeeded:false}}
        '
        return 1
    fi

    after_context=$(wifilab_network_context_json 2>/dev/null || true)
    if [[ -n $after_context ]]; then
        after_defaults=$(wifilab_default_owners_json "$after_context")
    else
        after_defaults='{"ipv4":[],"ipv6":[]}'
    fi
    [[ $before_defaults == "$after_defaults" ]] && route_safe=true || route_safe=false
    [[ -z $(wifilab_profile_active_uuid_on_iface "$iface") ]] && disconnected_ok=true || disconnected_ok=false

    if [[ $route_safe == true && $disconnected_ok == true ]]; then
        jq -cn \
          --arg iface "$iface" --arg uuid "$active_uuid" --arg role "$role" \
          --argjson before "$before_defaults" --argjson after "$after_defaults" '
          {
            ok:true,
            action:"saved_profile_disconnect",
            mutation_performed:true,
            target:{interface:$iface,role:$role},
            profile:{uuid:$uuid},
            route_before:{default_route_owners:$before},
            route_after:{default_route_owners:$after},
            route_unchanged:true,
            post_validation:{disconnected:true,default_route_owners_unchanged:true},
            rollback:{attempted:false,succeeded:false}
          }
        '
        return 0
    fi

    rollback_attempted=true
    LC_ALL=C nmcli -w 30 connection up uuid "$active_uuid" ifname "$iface" >/dev/null 2>&1 || true
    rollback_context=$(wifilab_network_context_json 2>/dev/null || true)
    if [[ -n $rollback_context ]]; then
        rollback_defaults=$(wifilab_default_owners_json "$rollback_context")
        if [[ $rollback_defaults == "$before_defaults" ]] && [[ $(wifilab_profile_active_device "$active_uuid") == "$iface" ]]; then
            rollback_succeeded=true
        fi
    else
        rollback_defaults='{"ipv4":[],"ipv6":[]}'
    fi

    jq -cn \
      --arg iface "$iface" --arg uuid "$active_uuid" \
      --argjson route_safe "$route_safe" --argjson disconnected_ok "$disconnected_ok" \
      --argjson before "$before_defaults" --argjson after "$after_defaults" \
      --argjson rollback_attempted "$rollback_attempted" --argjson rollback_succeeded "$rollback_succeeded" \
      --argjson rollback_after "$rollback_defaults" '
      {
        ok:false,
        error:"post_disconnect_validation_failed",
        action:"saved_profile_disconnect",
        mutation_performed:true,
        target:{interface:$iface},
        profile:{uuid:$uuid},
        route_before:{default_route_owners:$before},
        route_after:{default_route_owners:$after},
        post_validation:{disconnected:$disconnected_ok,default_route_owners_unchanged:$route_safe},
        rollback:{attempted:$rollback_attempted,succeeded:$rollback_succeeded,route_after:{default_route_owners:$rollback_after}}
      }
    '
    return 6
}
