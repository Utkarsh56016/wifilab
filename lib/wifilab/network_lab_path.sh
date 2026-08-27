#!/usr/bin/env bash

# WiFiLab Phase 8D read-only LAB path derivation.
# This module combines the stabilized interface role model with the current
# address/route context. It describes LAB L3 state and the separate system
# default path without probing a destination or mutating network state.

set -o pipefail

wifilab_network_lab_path_json() {
    local roles_json context_json

    roles_json=$(wifilab_network_roles_json) || {
        printf '{"ok":false,"error":"roles_failed","message":"could not derive network roles"}\n'
        return 4
    }

    context_json=$(wifilab_network_context_json) || {
        printf '{"ok":false,"error":"context_failed","message":"could not collect network context"}\n'
        return 4
    }

    jq -cn \
        --argjson roles "$roles_json" \
        --argjson context "$context_json" '
        def ctx_for($name):
          ([ $context.interfaces[]? | select(.name == $name) ][0] // null);

        def role_for($name):
          ([ $roles.interfaces[]? | select(.name == $name) ][0] // null);

        ($roles.selected_lab // {configured:false,present:false,interface:""}) as $selected |
        ($selected.interface // "") as $lab_name |
        (if ($selected.present // false) then ctx_for($lab_name) else null end) as $lab_ctx |
        (if ($selected.present // false) then role_for($lab_name) else null end) as $lab_role |
        ($roles.role_index.PRIMARY // []) as $primary_names |
        ([ $primary_names[] as $name |
           (ctx_for($name)) as $ctx |
           (role_for($name)) as $role |
           {
             name: $name,
             addresses: ($ctx.addresses // []),
             gateways: ($ctx.gateways // {ipv4:[],ipv6:[]}),
             defaults: ($ctx.defaults // {ipv4:[],ipv6:[]}),
             default_route_owner: ($ctx.default_route_owner // {ipv4:false,ipv6:false}),
             protected: ($ctx.protected // false),
             protection_reasons: ($ctx.protection_reasons // []),
             connection: ($role.connection // ""),
             nm_state: ($role.nm_state // ""),
             mode: ($role.mode // ""),
             driver: ($role.driver // ""),
             bus: ($role.bus // "")
           }
         ]) as $primary |
        (if $lab_ctx == null then [] else ($lab_ctx.addresses // []) end) as $lab_addresses |
        (if $lab_ctx == null then [] else (($lab_ctx.routes.ipv4 // []) + ($lab_ctx.routes.ipv6 // [])) end) as $lab_routes |
        (if $lab_ctx == null then [] else (($lab_ctx.defaults.ipv4 // []) + ($lab_ctx.defaults.ipv6 // [])) end) as $lab_defaults |
        ([ $lab_routes[]? |
           select(.dst != "default" and ((.gateway // "") == "")) |
           {
             family: .family,
             prefix: .dst,
             source: (.prefsrc // ""),
             metric: (.metric // null),
             protocol: (.protocol // ""),
             scope: (.scope // "")
           }
         ] | unique) as $on_link_prefixes |
        ((($lab_addresses | length) > 0)) as $lab_has_address |
        ((($lab_routes | length) > 0)) as $lab_has_routes |
        ((($lab_defaults | length) > 0)) as $lab_has_default |
        (((($context.default_routes.ipv4 // []) | length) + (($context.default_routes.ipv6 // []) | length)) > 0) as $system_has_default |
        ([ ($context.default_route_owners.ipv4 // [])[], ($context.default_route_owners.ipv6 // [])[] ] | unique) as $system_default_owners |
        (
          if (($selected.configured // false) | not) then "lab_not_configured"
          elif (($selected.present // false) | not) then "lab_absent"
          elif $lab_has_default then "default_route_conflict"
          elif (($lab_addresses | length) == 0 and ($lab_routes | length) == 0) then "no_l3_path"
          elif (($lab_routes | length) > 0) then "specific_routes_only"
          elif (($lab_addresses | length) > 0) then "addressed_no_main_route"
          else "unknown"
          end
        ) as $lab_state |
        (
          if $lab_has_default then "conflict"
          elif $system_has_default then "separate_default_owner"
          else "no_system_default"
          end
        ) as $separation_state |
        {
          ok: true,
          route_scope: ($context.route_scope // "main-table"),
          selected_lab: $selected,
          lab: {
            interface: (if ($selected.present // false) then $lab_name else "" end),
            role: ($lab_role.role // ""),
            mode: ($lab_role.mode // ""),
            nm_state: ($lab_role.nm_state // ""),
            connection: ($lab_role.connection // ""),
            driver: ($lab_role.driver // ""),
            bus: ($lab_role.bus // ""),
            addresses: {
              ipv4: [ $lab_addresses[]? | select(.family == "ipv4") ],
              ipv6: [ $lab_addresses[]? | select(.family == "ipv6") ]
            },
            source_addresses: {
              ipv4: [ $lab_addresses[]? | select(.family == "ipv4") | .address ],
              ipv6: [ $lab_addresses[]? | select(.family == "ipv6") | .address ]
            },
            on_link_prefixes: {
              ipv4: [ $on_link_prefixes[]? | select(.family == "ipv4") ],
              ipv6: [ $on_link_prefixes[]? | select(.family == "ipv6") ]
            },
            routes: (if $lab_ctx == null then {ipv4:[],ipv6:[]} else ($lab_ctx.routes // {ipv4:[],ipv6:[]}) end),
            defaults: (if $lab_ctx == null then {ipv4:[],ipv6:[]} else ($lab_ctx.defaults // {ipv4:[],ipv6:[]}) end),
            gateways: (if $lab_ctx == null then {ipv4:[],ipv6:[]} else ($lab_ctx.gateways // {ipv4:[],ipv6:[]}) end),
            default_route_owner: (if $lab_ctx == null then {ipv4:false,ipv6:false} else ($lab_ctx.default_route_owner // {ipv4:false,ipv6:false}) end),
            has_l3_address: $lab_has_address,
            has_main_routes: $lab_has_routes,
            has_default_route: $lab_has_default,
            state: $lab_state,
            conflicts: ($lab_role.conflicts // [])
          },
          primary: {
            interfaces: $primary,
            role_index: $primary_names,
            default_route_owners: ($context.default_route_owners // {ipv4:[],ipv6:[]}),
            default_routes: ($context.default_routes // {ipv4:[],ipv6:[]})
          },
          separation: {
            state: $separation_state,
            system_has_default_route: $system_has_default,
            system_default_owners: $system_default_owners,
            lab_is_system_default_owner: $lab_has_default,
            separate_from_system_default: (
              if $lab_has_default then false
              elif $system_has_default then true
              else null
              end
            ),
            reasons: ([
              if (($selected.configured // false) | not) then "lab_not_configured" else empty end,
              if (($selected.configured // false) and (($selected.present // false) | not)) then "selected_lab_not_present" else empty end,
              if (($selected.present // false) and (($lab_addresses | length) == 0)) then "lab_has_no_l3_address" else empty end,
              if (($selected.present // false) and (($lab_routes | length) == 0)) then "lab_has_no_main_route" else empty end,
              if $lab_has_default then "lab_owns_system_default_route" else empty end,
              if ($system_has_default and ($lab_has_default | not)) then "system_default_owned_elsewhere" else empty end,
              if (($lab_role.mode // "") == "monitor") then "lab_monitor_mode" else empty end
            ] | unique)
          },
          conflicts: ($lab_role.conflicts // []),
          warnings: (($roles.warnings // []) +
            ([
              if (($primary_names | length) == 0 and $system_has_default) then "system_default_has_no_physical_primary" else empty end
            ]) | unique)
        }
    '
}
