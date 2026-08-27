#!/usr/bin/env bash

# WiFiLab Phase 8B read-only addressing and route/default-route model.
# This module observes kernel address/route state plus NetworkManager DNS
# context. It performs no link, route, DNS, NetworkManager, or radio mutation.

set -o pipefail

wifilab_network_context_error_json() {
    local code=$1 message=$2
    printf '{"ok":false,"error":"%s","message":"%s"}\n' \
        "$(wifilab_json_escape "$code")" \
        "$(wifilab_json_escape "$message")"
}

wifilab_network_context_require_deps() {
    command -v ip >/dev/null 2>&1 || {
        wifilab_network_context_error_json "dependency_missing" "ip is required for network context"
        return 5
    }
    command -v jq >/dev/null 2>&1 || {
        wifilab_network_context_error_json "dependency_missing" "jq is required for structured network context"
        return 5
    }
}

wifilab_network_normalize_addresses_json() {
    local raw=$1
    jq -c '
        [ .[] |
          {
            name: (.ifname // ""),
            addresses: [
              .addr_info[]? |
              select(.family == "inet" or .family == "inet6") |
              {
                family: (if .family == "inet" then "ipv4" else "ipv6" end),
                address: (.local // ""),
                prefixlen: (.prefixlen // 0),
                scope: (.scope // ""),
                broadcast: (.broadcast // ""),
                label: (.label // ""),
                dynamic: (.dynamic // false),
                temporary: (.temporary // false),
                deprecated: (.deprecated // false),
                tentative: (.tentative // false)
              }
            ]
          }
        ]
    ' <<<"$raw"
}

wifilab_network_normalize_routes_json() {
    local family=$1 raw=$2
    jq -c --arg family "$family" '
        [ .[] |
          {
            family: $family,
            dst: (.dst // "default"),
            dev: (.dev // ""),
            gateway: (.gateway // ""),
            prefsrc: (.prefsrc // ""),
            protocol: (.protocol // ""),
            scope: (.scope // ""),
            metric: (.metric // null),
            table: (.table // "main"),
            type: (.type // "unicast"),
            preference: (.pref // ""),
            flags: (.flags // [])
          }
        ]
    ' <<<"$raw"
}

wifilab_network_nm_dns_record_json() {
    local iface=$1 dns4='' dns6=''

    if command -v nmcli >/dev/null 2>&1; then
        dns4=$(nmcli -g IP4.DNS device show "$iface" 2>/dev/null || true)
        dns6=$(nmcli -g IP6.DNS device show "$iface" 2>/dev/null || true)
    fi

    jq -cn \
        --arg name "$iface" \
        --arg dns4 "$dns4" \
        --arg dns6 "$dns6" '
        def normalize_dns($value):
          ($value
            | gsub("\\|"; "\n")
            | split("\n")
            | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
            | map(select(length > 0 and . != "--"))
            | unique);
        {
          name: $name,
          dns: {
            ipv4: normalize_dns($dns4),
            ipv6: normalize_dns($dns6)
          }
        }
    '
}

wifilab_network_dns_records_json() {
    local inventory_json=$1 iface first=1 record

    printf '['
    while IFS= read -r iface; do
        [[ -n $iface ]] || continue
        record=$(wifilab_network_nm_dns_record_json "$iface")
        (( first )) || printf ','
        first=0
        printf '%s' "$record"
    done < <(jq -r '.interfaces[].name' <<<"$inventory_json")
    printf ']'
}

wifilab_network_resolver_json() {
    local nameservers='' searches=''

    if [[ -r /etc/resolv.conf ]]; then
        nameservers=$(awk '$1 == "nameserver" && NF >= 2 {print $2}' /etc/resolv.conf 2>/dev/null || true)
        searches=$(awk '
            $1 == "search" {
                for (i = 2; i <= NF; i++) print $i
            }
        ' /etc/resolv.conf 2>/dev/null || true)
    fi

    jq -cn \
        --arg nameservers "$nameservers" \
        --arg searches "$searches" '
        {
          source: "/etc/resolv.conf",
          nameservers: ($nameservers | split("\n") | map(select(length > 0)) | unique),
          search: ($searches | split("\n") | map(select(length > 0)) | unique)
        }
    '
}

wifilab_network_context_json() {
    wifilab_network_context_require_deps || return $?

    local inventory_json addr_raw route4_raw route6_raw
    local addresses_json routes4_json routes6_json dns_json resolver_json

    inventory_json=$(wifilab_network_interfaces_json) || {
        wifilab_network_context_error_json "inventory_failed" "could not collect interface inventory"
        return 4
    }

    addr_raw=$(ip -j address show 2>/dev/null) || {
        wifilab_network_context_error_json "address_snapshot_failed" "could not read kernel address state"
        return 4
    }

    route4_raw=$(ip -j -4 route show table main 2>/dev/null) || route4_raw='[]'
    route6_raw=$(ip -j -6 route show table main 2>/dev/null) || route6_raw='[]'

    addresses_json=$(wifilab_network_normalize_addresses_json "$addr_raw") || {
        wifilab_network_context_error_json "address_parse_failed" "could not normalize kernel address state"
        return 4
    }
    routes4_json=$(wifilab_network_normalize_routes_json "ipv4" "$route4_raw") || {
        wifilab_network_context_error_json "route_parse_failed" "could not normalize IPv4 routes"
        return 4
    }
    routes6_json=$(wifilab_network_normalize_routes_json "ipv6" "$route6_raw") || {
        wifilab_network_context_error_json "route_parse_failed" "could not normalize IPv6 routes"
        return 4
    }

    dns_json=$(wifilab_network_dns_records_json "$inventory_json") || dns_json='[]'
    resolver_json=$(wifilab_network_resolver_json) || resolver_json='{"source":"/etc/resolv.conf","nameservers":[],"search":[]}'

    jq -cn \
        --argjson inventory "$inventory_json" \
        --argjson addresses "$addresses_json" \
        --argjson routes4 "$routes4_json" \
        --argjson routes6 "$routes6_json" \
        --argjson dns "$dns_json" \
        --argjson resolver "$resolver_json" '
        def addr_for($name):
          ([ $addresses[]? | select(.name == $name) | .addresses ][0] // []);
        def dns_for($name):
          ([ $dns[]? | select(.name == $name) | .dns ][0] // {ipv4:[], ipv6:[]});
        def routes_for($routes; $name):
          [ $routes[]? | select(.dev == $name) ];
        def defaults_for($routes; $name):
          [ $routes[]? | select(.dev == $name and .dst == "default") ];
        def active_connection($iface):
          ($iface.nm_state == "connected" and (($iface.connection // "") | length) > 0);

        ($routes4 | map(select(.dst == "default"))) as $defaults4 |
        ($routes6 | map(select(.dst == "default"))) as $defaults6 |
        {
          ok: true,
          route_scope: "main-table",
          interfaces: [
            $inventory.interfaces[] as $iface |
            (addr_for($iface.name)) as $addrs |
            (routes_for($routes4; $iface.name)) as $r4 |
            (routes_for($routes6; $iface.name)) as $r6 |
            (defaults_for($routes4; $iface.name)) as $d4 |
            (defaults_for($routes6; $iface.name)) as $d6 |
            (active_connection($iface)) as $active |
            {
              name: $iface.name,
              addresses: $addrs,
              dns: dns_for($iface.name),
              routes: {
                ipv4: $r4,
                ipv6: $r6
              },
              defaults: {
                ipv4: $d4,
                ipv6: $d6
              },
              gateways: {
                ipv4: ([ $r4[] | select((.gateway // "") != "") | .gateway ] | unique),
                ipv6: ([ $r6[] | select((.gateway // "") != "") | .gateway ] | unique)
              },
              default_route_owner: {
                ipv4: (($d4 | length) > 0),
                ipv6: (($d6 | length) > 0)
              },
              protected: ($active or (($d4 | length) > 0) or (($d6 | length) > 0)),
              protection_reasons: ([
                if $active then "active_networkmanager_connection" else empty end,
                if (($d4 | length) > 0) then "ipv4_default_route" else empty end,
                if (($d6 | length) > 0) then "ipv6_default_route" else empty end
              ])
            }
          ],
          routes: {
            ipv4: $routes4,
            ipv6: $routes6
          },
          default_routes: {
            ipv4: $defaults4,
            ipv6: $defaults6
          },
          default_route_owners: {
            ipv4: ([ $defaults4[].dev | select(length > 0) ] | unique),
            ipv6: ([ $defaults6[].dev | select(length > 0) ] | unique)
          },
          resolver: $resolver
        }
    '
}
