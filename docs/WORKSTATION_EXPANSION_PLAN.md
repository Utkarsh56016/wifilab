# WiFiLab Workstation Expansion Plan

## Scope

This plan governs the current Archcraft workstation build.

Portability and broad cross-distribution packaging are intentionally deferred. The immediate goal is to expand WiFiLab as a stable wireless-lab, adapter-management, capture-analysis, network-management, and authorized pentesting-support utility on the validated workstation.

## Stable Baseline

Accepted primary UI:

```text
CONTROL | TRAFFIC | CAPTURES
```

Current functional checkpoint:

```text
commit: 17c79c134c1b66f56cc9821191e7c1fdbb533709
branch: checkpoint/phase7-captures-validated-2026-08-27
```

Validated baseline capabilities include persistent physical LAB identity, protected PRIMARY/default-route state, managed/monitor lifecycle, regulatory-aware channel control, scoped NetworkManager coordination, non-root bounded capture, capture manifests and integrity, offline saved-PCAP analysis, CAPTURES UI, and preserved `1040 × 720` shell geometry.

## Final Navigation Target

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

SYSTEM/DOCTOR remains a utility drawer/panel unless later scope justifies promotion.

---

## CONTROL — Radio and Adapter Command Center

Status: **Stable**

Purpose:

> Safely control the selected physical wireless LAB adapter.

CONTROL remains authoritative for physical adapter selection, MAN/MON state, channel/frequency, regulatory state, monitor capability, protected/default-route guard, Restore, and radio-state mutation.

NETWORK may reuse these validated state transitions but must not duplicate or bypass them.

---

## TRAFFIC — Live Adapter Telemetry

Status: **Stable**

Purpose:

> Show current LAB-adapter telemetry and provide the bounded capture action.

The old periodic live `tshark -i` path is gone; protocol visualization derives from saved capture data.

---

## CAPTURES — PCAP Workspace

Status: **Accepted / checkpointed**

Purpose:

> Turn saved bounded captures into a deterministic offline analysis workspace.

Accepted safety properties remain frozen: only `capture run` can initiate capture, saved analysis never opens a live interface, IDs/paths are confined, legacy captures remain readable, `capinfos` is on demand, `tshark` is `-r` only, viewer/reveal actions are unprivileged, and viewer absence is represented explicitly.

---

# NETWORK — Workstation Network Manager

Expansion priority: **1 — active phase**

Purpose:

> Provide complete workstation network visibility and a safe adapter-aware Wi-Fi manager while keeping the PRIMARY production route explicit and protected.

NETWORK is now planned as both a topology/context workspace and a real NetworkManager-backed Wi-Fi connection manager.

## Critical boundary: NETWORK scan vs SURVEY scan

These are separate products inside WiFiLab:

```text
NETWORK
  NetworkManager Wi-Fi scan
  -> connectable SSIDs
  -> profile/connection state
  -> connect/disconnect management

SURVEY
  passive monitor-mode observation
  -> BSSID/SSID/frame/security/signal analysis
  -> no connection semantics
```

Do not reuse passive SURVEY capture logic as the connection scanner.

## NETWORK target layout

```text
NETWORK
├── ADAPTERS
│   ├── physical / wireless / ethernet
│   ├── PRIMARY / LAB / AUXILIARY
│   ├── VIRTUAL / TUNNEL
│   └── selected adapter state
│
├── WIFI RADAR
│   ├── SSID / BSSID
│   ├── signal / RSSI
│   ├── band
│   ├── channel / frequency
│   ├── security
│   ├── saved profile
│   └── connected state
│
├── CONNECTION
│   ├── connect saved profile
│   ├── connect new network
│   ├── disconnect / reconnect
│   ├── autoconnect state
│   └── forget profile
│
└── NETWORK CONTEXT
    ├── addresses / prefixes
    ├── subnet
    ├── gateway
    ├── DNS
    ├── routes / metrics
    ├── default-route ownership
    ├── protected state
    └── LAB PATH
```

## Wi-Fi radar

The radar should be visually strong but still represent real backend state.

Recommended mapping:

```text
radial distance = RSSI / signal quality
angle           = channel/frequency grouping
band grouping   = 2.4 / 5 / 6 GHz where supported
```

A radar point is selectable and should expose:

- SSID
- BSSID
- signal percentage / RSSI when available
- channel
- frequency
- band
- security
- connected state
- saved-profile state
- adapter being used for the scan

The radar does not claim physical distance to an AP.

## Adapter-aware connection state

A monitor-mode LAB adapter is not connectable through NETWORK.

Expected blocked presentation:

```text
TP-Link 802.11ac NIC
Role: LAB
Mode: monitor
NetworkManager: unmanaged

Wi-Fi connection unavailable.
Restore to managed mode first.

[ RESTORE TO MANAGED ]
```

Restore must route through the already-validated WiFiLab state-controller/helper path. NETWORK must not directly invoke a separate `iw` mode-switch workflow.

## Interface roles

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

PRIMARY means the protected production/internet path, not merely "the first Wi-Fi device".

LAB remains tied to persistent physical selection metadata rather than a runtime `wlanX` name.

## LAB PATH

NETWORK must derive an explicit LAB PATH context:

```text
LAB PATH
------------------------------
source interface
source address
subnet/prefix
gateway
route used
PRIMARY interface
PRIMARY default-route owner
LAB/PRIMARY isolation state
```

This is a prerequisite for later LAB orchestration.

## Route safety

Connection management can change:

- IPv4/IPv6 assignment
- gateway
- DNS
- route metrics
- default-route ownership

Therefore connection mutation comes only after the read-only route model is validated.

Required mutation invariant:

> Capture PRIMARY/default-route state before and after every connection action and refuse/flag unexpected production-path movement.

NETWORK does not introduce arbitrary route-editing controls in the initial phase.

## Credential safety

New-network passwords must never be emitted in WiFiLab JSON, normal logs, or intentionally passed through a process argument where they can appear in process listings.

The implementation sequence is deliberate:

```text
saved-profile connection first
secure new-network authentication later
```

The eventual secret path must use NetworkManager-compatible secret handling or another private input/IPC mechanism.

## Phase 8 implementation order

```text
8A  read-only interface inventory
8B  addressing + route/default-route model
8C  interface role model
8D  LAB PATH derivation
8E  virtual / bridge / tunnel relationships
8F  Wi-Fi discovery backend
8G  saved-profile connection manager
8H  secure new-network authentication
8I  NETWORK QML tab + Wi-Fi radar
8J  regression + checkpoint
```

### 8A — Read-only interface inventory

First feature only.

Collect:

- interface name
- interface kind/type
- wireless PHY/driver where applicable
- MAN/MON state where applicable
- operstate/link state
- NetworkManager state
- MAC
- MTU
- RX/TX counters
- bridge/master relationship

No network mutations.

### 8B — Addressing + route/default-route model

Add:

- IPv4 / IPv6
- prefix lengths
- subnet context
- gateway
- DNS context
- routes
- metrics
- default-route ownership
- protected state

### 8C — Interface role model

Derive/represent PRIMARY, LAB, AUXILIARY, VIRTUAL, and TUNNEL without weakening persistent physical LAB identity.

### 8D — LAB PATH derivation

Build deterministic source-path context. No route mutation.

### 8E — Virtual / bridge / tunnel relationships

Read-only discovery of Docker bridges, libvirt bridges, master membership, VPN/tunnel interfaces, and other safe virtual topology.

No Docker/libvirt lifecycle mutations.

### 8F — Wi-Fi discovery backend

NetworkManager-backed connectable-network scan on a selected managed wireless adapter.

Expose:

- adapter
- scan readiness
- SSID
- BSSID
- signal
- band
- channel
- frequency
- security
- saved-profile state
- connected state

### 8G — Saved-profile connection manager

Controlled actions:

- connect existing profile
- disconnect selected managed adapter
- reconnect
- inspect autoconnect state

Validate before/after:

- selected adapter
- NetworkManager state
- addressing
- route/default-route owner
- PRIMARY protection

No global NetworkManager restart or kill.

### 8H — Secure new-network authentication

Only after 8G is stable.

Requirements:

- private secret input path
- no secrets in JSON/logs
- no intentional password exposure in command arguments
- cancel/failure leaves route state sane
- profile creation and forget semantics documented

### 8I — NETWORK QML tab

Add the fourth tab:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK
```

Keep the accepted `1040 × 720` shell unless a separate shell-size change is explicitly justified and tested.

Initial NETWORK UI:

- adapter list
- role/status badges
- selected adapter context
- addresses/routes/default owner
- LAB PATH
- radar-style Wi-Fi scanner
- selected SSID details
- connect/disconnect state/actions
- explicit monitor-mode blocked state

CONTROL, TRAFFIC, and CAPTURES remain stabilized surfaces.

### 8J — Regression + checkpoint

Definition of done:

- backend contracts work independently of UI
- interface/topology data is correct on the real workstation
- PRIMARY/default-route ownership remains accurate
- LAB physical identity survives runtime renaming
- Wi-Fi radar data matches NetworkManager scan evidence
- saved-profile connection/disconnection is validated
- new-network authentication is validated if included
- monitor-mode LAB adapter is never silently treated as connectable
- no global NetworkManager disruption
- no credential leakage in logs/JSON
- CONTROL regression pass
- TRAFFIC regression pass
- CAPTURES regression pass
- NETWORK UI pass
- documentation updated
- rollback checkpoint branch created

Detailed Phase 8 contract: `docs/PHASE8_NETWORK_PLAN.md`.

---

## SURVEY — Passive Wireless Environment

Expansion priority: **2**

Purpose:

> Build passive current-channel situational awareness from monitor-mode observations and/or saved captures.

Initial instruments may include BSSID, SSID/hidden state, channel, timestamps, frame count, beacon/probe summaries, management/data/control mix, security metadata, OUI/vendor, and signal values when radiotap supports them reliably.

First-iteration non-goals: channel hopping, deauthentication, injection, association attacks, disruptive active scanning.

SURVEY is not the UI used to connect to Wi-Fi networks.

---

## LAB — Controlled Pentesting Workspace

Expansion priority: **3**

Purpose:

> Coordinate authorized lab-security workflows only after NETWORK provides a validated LAB interface, protected PRIMARY path, and explicit scope context.

WiFiLab should orchestrate and constrain external tools rather than reimplement every security utility.

---

## SYSTEM / DOCTOR Utility

Status: **Existing, incremental**

Keep diagnostics available without turning SYSTEM into an alternate mutation path.

---

## Expansion Order

```text
CURRENT ACCEPTED STATE
CONTROL + TRAFFIC + CAPTURES
        |
        v
Phase 8 NETWORK
  topology
  roles
  LAB PATH
  Wi-Fi scan
  connection manager
  radar UI
        |
        v
stabilize + checkpoint
        |
        v
Phase 9 SURVEY
        |
        v
stabilize + checkpoint
        |
        v
Phase 10 LAB
```

No later-phase feature is pulled forward unless it is an explicit dependency and is added to the active phase scope before implementation.

## UI Expansion Policy

The window remains `1040 × 720` unless a shell-size change is separately justified and validated.

Existing CONTROL, TRAFFIC, and CAPTURES layouts are stabilized surfaces. New tabs are added without broad accepted-geometry refactoring.

## Definition of Done for Every New Tab

A tab is stable only when its backend contract works independently, real-hardware success and refusal paths are validated, PRIMARY connectivity remains protected, LAB physical identity remains correct, UI agrees with backend JSON, prior tabs pass regression, process churn is controlled, documentation is updated, and a rollback checkpoint exists.

See `docs/BUILD_AND_STABILIZATION_METHOD.md`.
