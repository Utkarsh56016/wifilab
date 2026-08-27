#!/usr/bin/env bash

# WiFiLab Phase 8C read-only interface role model.
# Roles are derived from validated 8A inventory, 8B route context, and the
# persisted physical LAB-adapter selection. This module performs no mutation.

set -o pipefail

wifilab_network_roles_json() {
    local inventory_json context_json
    local selected_configured=false selected_present=false selected_iface=''

    inventory_json=$(wifilab_network_interfaces_json) || {
        printf '{"ok":false,"error":"inventory_failed","message":"could not collect interface inventory"}\n'
        return 4
    }

    context_json=$(wifilab_network_context_json) || {
        printf '{"ok":false,"error":"context_failed","message":"could not collect network context"}\n'
        return 4
    }

    if [[ -r ${WIFILAB_SELECTION_FILE:-} ]]; then
        selected_configured=true
        if selected_iface=$(wifilab_resolve_selected 2>/dev/null); then
            selected_present=true
        else
            selected_iface=''
        fi
    fi

    jq -cn \
        --argjson inventory "$inventory_json" \
        --argjson context "$context_json" \
        --argjson selected_configured "$selected_configured" \
        --argjson selected_present "$selected_present" \
        --arg selected_iface "$selected_iface" '
        def context_for($name):
          ([ $context.interfaces[]? | select(.name == $name) ][0] // {
            default_route_owner:{ipv4:false,ipv6:false},
            protected:false,
            protection_reasons:[]
          });

        def is_tunnel($iface):
          (($iface.kind // "") == "tunnel") or
          (($iface.nm_type // "") == "tun") or
          (($iface.nm_type // "") == "wireguard");

        def primary_path($ctx):
          (($ctx.default_route_owner.ipv4 // false) or
           ($ctx.default_route_owner.ipv6 // false));

        [
          $inventory.interfaces[] as $iface |
          (context_for($iface.name)) as $ctx |
          (($selected_present == true) and ($iface.name == $selected_iface)) as $is_lab |
          (is_tunnel($iface)) as $is_tunnel |
          (primary_path($ctx)) as $owns_default |
          (
            if $is_lab then "LAB"
            elif $is_tunnel then "TUNNEL"
            elif (($iface.virtual // false) == true or ($iface.loopback // false) == true) then "VIRTUAL"
            elif $owns_default then "PRIMARY"
            else "AUXILIARY"
            end
          ) as $role |
          {
            name: $iface.name,
            kind: ($iface.kind // ""),
            role: $role,
            selected_lab: $is_lab,
            primary_path: $owns_default,
            protected: ($ctx.protected // false),
            role_reasons: ([
              if $is_lab then "selected_physical_lab_adapter" else empty end,
              if $owns_default then "default_route_owner" else empty end,
              if $is_tunnel then "tunnel_interface" else empty end,
              if (($iface.loopback // false) == true) then "loopback" else empty end,
              if (($iface.virtual // false) == true and (($iface.loopback // false) != true)) then "virtual_netdev" else empty end,
              if (($iface.kind // "") == "bridge") then "bridge_interface" else empty end,
              if ($role == "AUXILIARY") then "non_default_physical_interface" else empty end
            ] | unique),
            conflicts: ([
              if ($is_lab and $owns_default) then "selected_lab_owns_default_route" else empty end,
              if ($is_lab and ($ctx.protected // false)) then "selected_lab_is_protected" else empty end
            ] | unique),
            default_route_owner: ($ctx.default_route_owner // {ipv4:false,ipv6:false}),
            protection_reasons: ($ctx.protection_reasons // []),
            wireless: ($iface.wireless // false),
            virtual: ($iface.virtual // false),
            loopback: ($iface.loopback // false),
            nm_type: ($iface.nm_type // ""),
            nm_state: ($iface.nm_state // ""),
            connection: ($iface.connection // ""),
            mode: ($iface.mode // ""),
            phy: ($iface.phy // ""),
            driver: ($iface.driver // ""),
            bus: ($iface.bus // "")
          }
        ] as $roles |
        ($roles | map(select(.role == "PRIMARY")) | map(.name)) as $primary |
        ($roles | map(select(.role == "LAB")) | map(.name)) as $lab |
        ($roles | map(select(.role == "AUXILIARY")) | map(.name)) as $aux |
        ($roles | map(select(.role == "VIRTUAL")) | map(.name)) as $virtual |
        ($roles | map(select(.role == "TUNNEL")) | map(.name)) as $tunnel |
        ($roles | map(select((.conflicts | length) > 0))) as $conflicted |
        {
          ok: true,
          selected_lab: {
            configured: $selected_configured,
            present: $selected_present,
            interface: (if $selected_present then $selected_iface else "" end)
          },
          primary_route_owners: ($context.default_route_owners // {ipv4:[],ipv6:[]}),
          interfaces: $roles,
          role_index: {
            PRIMARY: $primary,
            LAB: $lab,
            AUXILIARY: $aux,
            VIRTUAL: $virtual,
            TUNNEL: $tunnel
          },
          conflicts: $conflicted,
          warnings: ([
            if ($selected_configured and ($selected_present | not)) then "selected_lab_not_present" else empty end,
            if (($primary | length) == 0 and (((($context.default_route_owners.ipv4 // []) | length) + (($context.default_route_owners.ipv6 // []) | length)) > 0)) then "default_route_has_no_physical_primary_role" else empty end,
            if (($primary | length) > 1) then "multiple_primary_interfaces" else empty end
          ])
        }
    '
}
