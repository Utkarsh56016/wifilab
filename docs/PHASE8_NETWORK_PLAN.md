# WiFiLab Phase 8 — NETWORK Plan

Status: **Active implementation**

Base: accepted Phase 7 `main` at `fa166b79c54330a6ffca3c54526b53991532b59a`.

## Goal

Turn the NETWORK tab into a proper workstation network manager while preserving WiFiLab's existing safety model.

The NETWORK phase must support both:

1. complete read-only network topology visibility; and
2. controlled Wi-Fi connection management through NetworkManager.

The final NETWORK workspace should let the operator select a wireless adapter, scan available connectable Wi-Fi networks, inspect SSID details, connect/disconnect safely, and understand exactly which interface owns the default route.

## Important separation

Two different wireless discovery concepts must remain separate:

```text
NETWORK Wi-Fi scan
  -> NetworkManager-managed scan
  -> available/connectable SSIDs
  -> connection management

SURVEY passive scan
  -> monitor-mode observations / saved captures
  -> BSSID/SSID/frame/security/signal analysis
  -> no connection semantics
```

NETWORK is for connectivity. SURVEY is for passive wireless situational awareness.

## Target NETWORK workspace

```text
NETWORK
├── ADAPTERS
│   ├── PRIMARY
│   ├── LAB
│   ├── AUXILIARY
│   ├── VIRTUAL
│   └── TUNNEL
│
├── WIFI RADAR
│   ├── adapter selector
│   ├── SSID
│   ├── BSSID
│   ├── RSSI / signal quality
│   ├── band
│   ├── channel
│   ├── frequency
│   ├── security
│   ├── saved profile state
│   └── connected state
│
├── CONNECTION
│   ├── Connect saved profile
│   ├── Connect new network
│   ├── Disconnect
│   ├── Reconnect
│   ├── Autoconnect state
│   └── Forget profile
│
└── NETWORK CONTEXT
    ├── IPv4 / IPv6
    ├── subnet/prefix
    ├── gateway
    ├── DNS
    ├── routes
    ├── route metric
    ├── default-route owner
    ├── protected state
    └── LAB PATH
```

## Wi-Fi radar design

The radar is a deterministic visualization of NetworkManager scan results, not a fake distance map.

Recommended model:

```text
radial distance  = signal strength / RSSI
angle            = channel/frequency grouping
visual grouping  = band (2.4 / 5 / 6 GHz where supported)
```

Each access-point/SSID item should expose:

- SSID
- BSSID
- RSSI / signal percentage
- channel
- frequency
- band
- security
- connected state
- saved profile state
- selected adapter

Selecting a radar point opens a detail card with connection actions appropriate to the current adapter state.

## Adapter-aware behavior

A wireless adapter in monitor mode must not be presented as directly connectable.

Example:

```text
TP-Link 802.11ac NIC
Role: LAB
Mode: monitor
NetworkManager: unmanaged

Connection unavailable.
Restore the adapter to managed mode first.

[ RESTORE TO MANAGED ]
```

Restore must reuse the existing validated CONTROL/state-controller path. NETWORK must not invent a second raw `iw` mutation path.

## Route-safety model

Connecting to Wi-Fi may change:

- assigned addresses
- gateway
- DNS
- route metrics
- default-route ownership

Therefore connection actions are blocked until Phase 8 has a validated route/default-route model.

NETWORK must make route changes observable and must not silently move the workstation's production path away from the protected PRIMARY interface.

Initial rule:

> PRIMARY/default-route state must be measured before and after every connection mutation.

Any future operation that can alter default-route ownership requires its own explicit contract and regression test.

For saved-profile activation on a non-PRIMARY adapter, the initial implementation is stricter:

> A profile capable of installing an IPv4 or IPv6 default route is refused before activation.

This prevents a secondary LAB connection from becoming the preferred workstation path merely because its NetworkManager route metric is lower than the current PRIMARY route. The activation backend still snapshots default-route ownership before and after the action and performs best-effort rollback if the observed owner set changes.

## Credential handling

Wi-Fi passwords must not be placed in WiFiLab JSON, logs, shell history, or process arguments where avoidable.

Do not implement new-network authentication using a simple command line such as:

```text
nmcli dev wifi connect <ssid> password <secret>
```

The credential path must use a NetworkManager-compatible secret mechanism or another private input/IPC flow that does not expose secrets in logs or process listings.

Saved-profile connection support should be implemented and validated before new-network secret entry.

## Phase 8 implementation order

### 8A — Read-only interface inventory

Status: **STABILIZED**

Goal: produce a deterministic machine-readable inventory of all workstation network interfaces.

Read-only fields:

- interface name
- interface kind/type
- wireless PHY/driver where applicable
- managed/monitor state where applicable
- operstate/link state
- NetworkManager state
- MAC
- MTU
- RX/TX counters
- bridge/master relationship

No mutations.

### 8B — Addressing + route/default-route model

Status: **STABILIZED**

Add:

- IPv4 / IPv6 addresses
- prefix lengths
- subnet context
- gateway
- DNS context
- routes
- route metrics
- default-route ownership
- protected state

Acceptance requires `wlan0`/PRIMARY ownership to remain correctly identifiable.

### 8C — Interface role model

Status: **STABILIZED**

Roles:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

The persisted physical LAB adapter remains authoritative despite changing `wlanX` names.

### 8D — LAB PATH derivation

Status: **STABILIZED**

Derive:

```text
source interface
source address
subnet/prefix
gateway
route used
PRIMARY interface
PRIMARY default-route owner
LAB/PRIMARY isolation state
```

No route mutation yet.

### 8E — Virtual / bridge / tunnel relationships

Status: **STABILIZED**

Read-only topology for:

- Docker bridges
- libvirt bridges
- bridge/master membership
- VPN/tunnel devices
- other virtual interfaces where safely inferable

Do not couple container or VM lifecycle mutations into this phase.

### 8F — Wi-Fi discovery backend

Status: **STABILIZED**

Use NetworkManager-compatible scanning for connectable networks.

Expose:

- selected wireless adapter
- scan readiness
- SSID
- BSSID
- RSSI / signal quality
- channel
- frequency
- band
- security
- connected state
- saved profile state

Validated public command:

```text
wifilab network wifi-scan <iface> --json
```

The current implementation reports NetworkManager signal percentage as the source value and does not fabricate dBm RSSI when NetworkManager does not provide it through the selected scan contract.

This scan is distinct from Phase 9 SURVEY.

### 8G — Saved-profile connection manager

Status: **ACTIVE — 8G-1 STABILIZED; guarded connect/disconnect/reconnect validation next**

Controlled actions:

- inventory existing saved Wi-Fi profiles without querying secret fields
- preflight one explicit profile UUID against one explicit interface
- connect an existing saved profile on a selected managed non-PRIMARY adapter
- disconnect selected non-PRIMARY adapter
- reconnect an explicit saved profile
- inspect autoconnect state

Every action must validate pre/post:

- selected adapter
- NetworkManager state
- addressing
- default-route owner
- PRIMARY protection

Current guarded policy:

- PRIMARY activation/disconnect is refused by the generic saved-profile action path
- monitor/unmanaged adapters are refused until restored through CONTROL
- a profile active on another device is refused
- an interface-bound profile cannot silently move to another interface
- a target with another active profile is not silently replaced
- saved profiles that may install IPv4 or IPv6 default routes on a secondary adapter are refused
- successful activation/disconnect requires unchanged default-route-owner sets
- post-validation failure triggers best-effort rollback
- no credential values are accepted by these commands

No global NetworkManager restart/kill.

### 8H — New-network authentication

Status: **PENDING**

Add secure connection to previously unsaved SSIDs only after the saved-profile path is stable.

Requirements:

- secrets never emitted in JSON/logs
- secrets not intentionally exposed through command arguments
- authentication cancel/failure leaves route state sane
- profile creation behavior documented
- forget-profile action separately guarded

### 8I — NETWORK Quickshell tab

Status: **PENDING**

Add the fourth primary tab without changing the accepted 1040x720 shell contract:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK
```

Initial UI instruments:

- adapter/device list
- role/status badges
- network context/details
- LAB PATH
- Wi-Fi radar
- selected SSID detail card
- connection state/actions
- explicit blocked state for monitor/unmanaged adapters

Existing CONTROL, TRAFFIC, and CAPTURES layouts remain stabilized surfaces.

### 8J — Regression + checkpoint

Status: **PENDING**

Acceptance requires:

- backend contracts independently validated
- read-only topology correct
- saved-profile connect/disconnect validated
- new-network authentication validated if included
- PRIMARY route protection preserved
- monitor LAB adapter not accidentally connected
- no global NetworkManager disruption
- no credential leakage in logs/JSON
- CONTROL regression pass
- TRAFFIC regression pass
- CAPTURES regression pass
- NETWORK UI pass
- documentation updated
- rollback checkpoint branch created

## Current validated progress

```text
8A  interface inventory            STABILIZED
8B  addressing/routes              STABILIZED
8C  interface role model           STABILIZED
8D  LAB PATH                       STABILIZED
8E  topology graph                 STABILIZED
8F  NetworkManager Wi-Fi scan      STABILIZED
8G1 saved profile inventory        STABILIZED
8G2 guarded connect                VALIDATION NEXT
8G3 guarded disconnect/reconnect   VALIDATION NEXT
8H  secure new authentication      PENDING
8I  NETWORK QML/radar              PENDING
8J  regression/checkpoint          PENDING
```

## Non-goals for initial Phase 8

- arbitrary route editing UI
- firewall management
- global NetworkManager restart/kill
- container/VM lifecycle management
- monitor-mode passive survey analytics
- channel hopping
- offensive wireless actions

## Safety invariants

1. Existing physical LAB identity remains authoritative.
2. PRIMARY/default-route connectivity remains protected.
3. NETWORK cannot bypass CONTROL radio safety.
4. Monitor-mode adapters are not treated as connectable until restored through the validated state path.
5. No global NetworkManager disruption.
6. Connection mutations require pre/post route validation.
7. Secrets never enter WiFiLab telemetry/JSON/logs.
8. Wi-Fi radar uses NetworkManager scan data; passive wireless analysis stays in SURVEY.
9. Prior accepted tabs remain regression-tested.
10. Phase 8 receives a rollback checkpoint before Phase 9 begins.
