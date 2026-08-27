#!/usr/bin/env bash

# WiFiLab Phase 8E read-only network relationship graph.
# Combines kernel/sysfs relationship evidence with Phase 8A inventory and 8C
# roles. This module performs no link, namespace, bridge, tunnel, route, or
# NetworkManager mutation.

set -o pipefail

wifilab_network_topology_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s"}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

wifilab_network_topology_link_snapshot_json() {
    local raw
    raw=$(ip -j -d link show 2>/dev/null) || {
        wifilab_network_topology_error_json "link_snapshot_failed" "could not read detailed kernel link state"
        return 4
    }

    jq -c '
      [ .[] |
        {
          name: (.ifname // ""),
          ifindex: (.ifindex // 0),
          peer_ifindex: (.link_index // null),
          linked_name: (.link // ""),
          link_kind: (.linkinfo.info_kind // ""),
          slave_kind: (.linkinfo.info_slave_kind // ""),
          operstate: (.operstate // ""),
          group: (.group // ""),
          link_type: (.link_type // "")
        }
      ]
    ' <<<"$raw"
}

wifilab_network_topology_sysfs_edges_json() {
    local inventory_json=$1 iface base master lower target
    local -a records=()

    while IFS= read -r iface; do
        [[ -n $iface ]] || continue
        base="/sys/class/net/$iface"
        [[ -d $base ]] || continue

        if [[ -L $base/master ]]; then
            master=$(basename "$(readlink -f "$base/master" 2>/dev/null || true)")
            if [[ -n $master ]]; then
                records+=("$(jq -cn --arg source "$iface" --arg target "$master" '{source:$source,target:$target,relation:"member_of",evidence:"sysfs_master"}')")
            fi
        fi

        for lower in "$base"/lower_*; do
            [[ -L $lower ]] || continue
            target=${lower##*/lower_}
            [[ -n $target ]] || continue
            records+=("$(jq -cn --arg source "$iface" --arg target "$target" '{source:$source,target:$target,relation:"lower_device",evidence:"sysfs_lower"}')")
        done
    done < <(jq -r '.interfaces[].name' <<<"$inventory_json")

    if (( ${#records[@]} == 0 )); then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "${records[@]}" | jq -cs 'unique_by([.source,.target,.relation])'
}

wifilab_network_topology_json() {
    command -v ip >/dev/null 2>&1 || {
        wifilab_network_topology_error_json "dependency_missing" "ip is required for network topology"
        return 5
    }
    command -v jq >/dev/null 2>&1 || {
        wifilab_network_topology_error_json "dependency_missing" "jq is required for network topology"
        return 5
    }

    local inventory_json roles_json links_json sysfs_edges_json

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_network_topology_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }

    roles_json=$(wifilab_network_roles_json) || {
        wifilab_network_topology_error_json "roles_failed" "could not derive network roles"
        return 4
    }

    links_json=$(wifilab_network_topology_link_snapshot_json) || return $?
    sysfs_edges_json=$(wifilab_network_topology_sysfs_edges_json "$inventory_json") || sysfs_edges_json='[]'

    jq -cn \
        --argjson inventory "$inventory_json" \
        --argjson roles "$roles_json" \
        --argjson links "$links_json" \
        --argjson sysfs_edges "$sysfs_edges_json" '
        def role_for($name):
          ([ $roles.interfaces[]? | select(.name == $name) | .role ][0] // "UNKNOWN");
        def role_record_for($name):
          ([ $roles.interfaces[]? | select(.name == $name) ][0] // {});
        def link_for($name):
          ([ $links[]? | select(.name == $name) ][0] // {});
        def name_for_index($idx):
          ([ $inventory.interfaces[]? | select(.ifindex == $idx) | .name ][0] // "");
        def is_tunnel_kind($kind):
          ["tun","tap","wireguard","gre","gretap","ip6gre","ip6gretap","sit","ipip","vxlan","geneve","erspan","ip6tnl","vti","vti6"] | index($kind) != null;

        [
          $inventory.interfaces[] as $iface |
          (link_for($iface.name)) as $link |
          (role_record_for($iface.name)) as $role |
          {
            name: $iface.name,
            ifindex: $iface.ifindex,
            kind: $iface.kind,
            role: (role_for($iface.name)),
            virtual: ($iface.virtual // false),
            loopback: ($iface.loopback // false),
            wireless: ($iface.wireless // false),
            operstate: ($iface.operstate // ""),
            master: ($iface.master // ""),
            nm_type: ($iface.nm_type // ""),
            link_kind: ($link.link_kind // ""),
            slave_kind: ($link.slave_kind // ""),
            peer_ifindex: ($link.peer_ifindex // null),
            peer_name: (if (($link.peer_ifindex // null) != null) then name_for_index($link.peer_ifindex) else "" end),
            topology_class: (
              if (($iface.loopback // false) == true) then "loopback"
              elif (($iface.kind // "") == "bridge" or ($link.link_kind // "") == "bridge") then "bridge"
              elif is_tunnel_kind(($link.link_kind // "")) or (($iface.nm_type // "") == "tun") or (($iface.nm_type // "") == "wireguard") then "tunnel"
              elif (($link.link_kind // "") == "veth") then "veth"
              elif (($iface.virtual // false) == true) then "virtual"
              else "physical"
              end
            ),
            selected_lab: ($role.selected_lab // false),
            primary_path: ($role.primary_path // false)
          }
        ] as $nodes |

        [
          $links[]? |
          select((.peer_ifindex // null) != null) |
          (name_for_index(.peer_ifindex)) as $peer |
          select($peer != "" and $peer != .name) |
          {
            source: .name,
            target: $peer,
            relation: "peer",
            evidence: "ip_link_peer_ifindex"
          }
        ] as $peer_edges |

        (($sysfs_edges + $peer_edges) | unique_by([.source,.target,.relation])) as $edges |

        [
          $links[]? |
          select((.peer_ifindex // null) != null) |
          select((name_for_index(.peer_ifindex)) == "") |
          {
            interface: .name,
            peer_ifindex: .peer_ifindex,
            reason: "peer_not_in_current_namespace_snapshot"
          }
        ] as $unresolved_peers |

        [
          $nodes[] |
          select(.topology_class == "bridge") as $bridge |
          {
            name: $bridge.name,
            role: $bridge.role,
            members: ([ $edges[]? | select(.relation == "member_of" and .target == $bridge.name) | .source ] | unique | sort)
          }
        ] as $bridges |

        [ $nodes[] | select(.topology_class == "tunnel") ] as $tunnels |
        [ $nodes[] | select(.virtual == true) ] as $virtual_nodes |
        [ $nodes[] | select(.topology_class == "veth") ] as $veth_nodes |
        [ $nodes[] | select(.role == "UNKNOWN") | .name ] as $role_snapshot_misses |

        {
          ok: true,
          snapshot_scope: "current-network-namespace",
          node_count: ($nodes | length),
          edge_count: ($edges | length),
          nodes: $nodes,
          edges: $edges,
          bridges: $bridges,
          tunnels: $tunnels,
          virtual_interfaces: ($virtual_nodes | map(.name) | unique | sort),
          veth_interfaces: ($veth_nodes | map(.name) | unique | sort),
          unresolved_peers: $unresolved_peers,
          warnings: ([
            if (($role_snapshot_misses | length) > 0) then {code:"role_snapshot_changed",interfaces:$role_snapshot_misses} else empty end,
            if (($unresolved_peers | length) > 0) then {code:"peer_outside_current_namespace_or_snapshot",count:($unresolved_peers|length)} else empty end
          ])
        }
    '
}
