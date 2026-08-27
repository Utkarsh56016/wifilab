# WiFiLab Roadmap

WiFiLab is developed as a workstation-first wireless-lab, adapter-management, passive-capture, network-management, and authorized pentesting-support console for the validated Archcraft workstation.

Cross-distribution portability and broad packaging remain deferred until the workstation feature set is mature.

## Engineering Rule

WiFiLab follows:

```text
stable main
  -> one bounded feature
  -> backend contract
  -> implementation
  -> CLI/JSON validation
  -> real hardware validation
  -> Quickshell integration
  -> regression validation
  -> stabilization
  -> documentation
  -> checkpoint
  -> next phase
```

Existing stabilized behavior is infrastructure and should not be opportunistically rewritten.

See:

- `docs/BUILD_AND_STABILIZATION_METHOD.md`
- `docs/WORKSTATION_EXPANSION_PLAN.md`
- `docs/ROLLBACK_CHECKPOINTS.md`
- `docs/PHASE8_NETWORK_PLAN.md`

---

# Phase Summary

| Phase | Scope | State |
|---|---|---|
| 0 | Hardware validation | Complete |
| 1 | Read-only discovery | Complete |
| 2 | Safe state controller | Complete |
| 3 | Persistent physical selection + CLI hardening | Complete |
| 4 | Quickshell integration | Complete |
| 5 | UI reliability + telemetry | Complete |
| 6 | Non-root bounded passive capture baseline | Stabilized / checkpointed |
| 7 | CAPTURES workspace | Accepted / checkpointed |
| 8 | NETWORK manager + Wi-Fi radar + LAB path | **Active** |
| 9 | SURVEY passive wireless environment | Planned |
| 10 | LAB controlled pentesting workspace | Planned |
| 11 | Post-expansion hardening / packaging / portability | Deferred |

Target navigation:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

SYSTEM/DOCTOR remains a utility surface rather than a permanent primary tab.

---

## Phases 0–5 — Foundation

Status: **Complete**

The accepted foundation includes hardware/driver validation, read-only discovery, protected radio state control, persistent physical LAB-adapter selection, Quickshell integration, telemetry, hotplug recovery, default-route protection, regulatory-aware channel control, scoped NetworkManager coordination, and guarded privileged mutations through the existing helper/polkit boundary.

Design conclusion:

> Runtime `wlanX`, `phyX`, and MAC values are observations, not persistent physical identity.

## Phase 6 — Non-Root Bounded Passive Capture

Status: **Stabilized / checkpointed**

Validated normal-user `dumpcap`, monitor-mode-only bounded PCAPNG capture, protected/default-route refusal, private capture storage, TRAFFIC capture controls, radiotap output, reboot/re-enumeration survival, and preserved `wlan0` default route.

Checkpoint:

```text
ac1af9f4c970d02d906a5625619a75f72a1faeec
checkpoint/phase6-capture-ui-validated-2026-08-26
```

## Phase 7 — CAPTURES Workspace

Status: **Accepted / checkpointed**

Implemented and validated:

- `CONTROL | TRAFFIC | CAPTURES` in the fixed `1040 × 720` shell
- per-capture JSON manifests
- capture-time interface/PHY/driver/channel/frequency/regdomain metadata
- SHA-256 metadata and integrity verification
- richer backward-compatible capture inventory and latest-capture API
- legacy Phase 6 capture support without rewrite
- strict capture-ID/path confinement and refusal tests
- offline `tshark -r` protocol analysis
- removal of repeated live `tshark -i` protocol sampling
- on-demand `capinfos` inspection
- safe viewer/reveal actions
- viewer-unavailable state
- CAPTURES library/inspector UI
- no persistent capture-analysis process churn
- CONTROL/TRAFFIC regression pass
- PRIMARY default route preserved

Checkpoint:

```text
17c79c134c1b66f56cc9821191e7c1fdbb533709
checkpoint/phase7-captures-validated-2026-08-27
```

Deferred packaging item:

- install a matching `io.github.utkarsh56016.wifilab.desktop` entry so the QML AppId registers cleanly with XDG Desktop Portal.

---

# Phase 8 — NETWORK Manager, Wi-Fi Radar, and LAB Path

Status: **Active**

Goal:

> Turn NETWORK into a proper workstation network manager: understand the complete topology first, then safely scan and connect Wi-Fi through NetworkManager while preserving the protected PRIMARY route and existing LAB-adapter safety model.

Phase 8 is no longer only a topology viewer. Its accepted target includes adapter-aware Wi-Fi discovery and controlled connection management.

## Critical scan separation

NETWORK and SURVEY have different purposes:

```text
NETWORK Wi-Fi scan
  -> NetworkManager-managed scan
  -> connectable SSIDs
  -> saved/connected profile state
  -> connection management

SURVEY passive scan
  -> monitor-mode observations / saved captures
  -> passive BSSID/SSID/frame/security/signal analysis
  -> no connection semantics
```

The NETWORK radar must use NetworkManager-compatible scan data. Passive monitor-mode survey analytics stay in Phase 9.

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
│   ├── SSID / BSSID
│   ├── RSSI / signal quality
│   ├── band / channel / frequency
│   ├── security
│   ├── saved profile state
│   └── connected state
│
├── CONNECTION
│   ├── Connect saved profile
│   ├── Connect new network
│   ├── Disconnect / reconnect
│   ├── Autoconnect state
│   └── Forget profile
│
└── NETWORK CONTEXT
    ├── IPv4 / IPv6
    ├── subnet/prefix
    ├── gateway / DNS
    ├── routes / metrics
    ├── default-route owner
    ├── protected state
    └── LAB PATH
```

## Wi-Fi radar model

The radar is a deterministic visualization rather than fake physical ranging:

```text
radial distance = RSSI / signal strength
angle           = channel/frequency grouping
visual grouping = band (2.4 / 5 / 6 GHz when supported)
```

Each item should expose SSID, BSSID, signal, channel, frequency, band, security, saved state, connected state, and selected adapter.

## Adapter-aware connection behavior

A monitor-mode/unmanaged LAB adapter is not connectable until restored through the existing validated state controller.

NETWORK must show an explicit blocked state such as:

```text
LAB adapter
mode: monitor
NetworkManager: unmanaged

Connection unavailable.
Restore to managed mode first.
```

NETWORK must reuse CONTROL/state-controller logic; it must not invent a second raw `iw` mutation path.

## Route and credential safety

Wi-Fi connection changes can alter addresses, gateway, DNS, route metrics, and default-route ownership. Therefore connection mutations are not introduced until the read-only route model is validated.

Initial rule:

> Measure PRIMARY/default-route state before and after every connection mutation.

Wi-Fi secrets must never be emitted in WiFiLab JSON/logs or intentionally placed in process arguments. Saved-profile connection support is implemented before new-network password entry.

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

Inventory all network interfaces with name, kind/type, wireless PHY/driver where applicable, MAN/MON state, operstate, NetworkManager state, MAC, MTU, RX/TX counters, and bridge/master membership.

No mutations.

### 8B — Addressing + route/default-route model

Add IPv4/IPv6, prefixes, subnet context, gateway, DNS, routes, metrics, default-route ownership, and protected state.

### 8C — Interface role model

Roles:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

The selected physical LAB identity remains authoritative across runtime `wlanX` changes.

### 8D — LAB PATH derivation

Derive source interface/address, subnet, gateway, route used, PRIMARY interface/default-route owner, and LAB/PRIMARY isolation state.

No route mutation.

### 8E — Virtual / bridge / tunnel relationships

Read-only Docker/libvirt bridge relationships, master membership, VPN/tunnel devices, and other virtual topology where safely inferable.

### 8F — Wi-Fi discovery backend

Use NetworkManager-compatible scanning for connectable wireless networks and expose selected adapter, scan readiness, SSID, BSSID, signal, band, channel, frequency, security, saved-profile state, and connected state.

### 8G — Saved-profile connection manager

Controlled connection/disconnection/reconnection of already-saved NetworkManager profiles on a selected managed adapter, with pre/post validation of NetworkManager, addressing, default-route ownership, and PRIMARY protection.

No global NetworkManager restart/kill.

### 8H — Secure new-network authentication

Add previously-unsaved network authentication only after 8G is stable. Secrets must not appear in JSON/logs/process arguments. Cancellation/failure must leave routing sane.

### 8I — NETWORK Quickshell tab

Add:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK
```

within the accepted `1040 × 720` shell.

Initial UI instruments:

- adapter/device list
- role/status badges
- addressing/routing context
- LAB PATH
- radar-style Wi-Fi scanner
- selected SSID detail card
- connection state/actions
- explicit blocked state for monitor/unmanaged adapters

Existing tabs remain stabilized surfaces.

### 8J — Regression + checkpoint

Acceptance requires correct topology, route ownership, saved-profile connect/disconnect, secure new-network authentication if included, no credential leakage, PRIMARY protection, no global NetworkManager disruption, prior-tab regression passes, NETWORK UI pass, documentation, and a Phase 8 rollback checkpoint.

Detailed contract: `docs/PHASE8_NETWORK_PLAN.md`.

---

## Phase 9 — SURVEY Passive Wireless Environment

Status: **Planned**

Current-channel passive wireless situational awareness from monitor-mode observations and/or saved captures: BSSID/SSID, frame counts, timestamps, beacon/probe summaries, frame-type mix, security advertisement, OUI/vendor, and signal metadata where radiotap supports it reliably.

Explicit first-iteration non-goals: channel hopping, deauthentication, frame injection, and disruptive active scanning.

## Phase 10 — LAB Controlled Pentesting Workspace

Status: **Planned**

Coordinate authorized lab workflows only after NETWORK provides a validated LAB interface, protected PRIMARY path, and explicit scope context. WiFiLab should orchestrate and constrain external tools rather than reimplement them.

## Phase 11 — Post-Expansion Hardening / Packaging / Portability

Status: **Deferred**

Potential scope includes desktop registration, installer/package model, shell completion, dependency diagnostics, compositor/theme portability, and broader Linux support.

---

# Release-Blocking Invariants

Every expansion phase must preserve:

1. `wlan0` / default-route connectivity remains protected.
2. Physical LAB identity remains authoritative despite runtime re-enumeration.
3. No global NetworkManager disruption.
4. No `airmon-ng check kill` workflow.
5. No regulatory bypass.
6. Quickshell never runs as root.
7. Capture never gains a root/pkexec path.
8. Only `capture run` may initiate capture.
9. New-feature failure cannot mutate unrelated network state.
10. NETWORK cannot bypass existing CONTROL radio safety.
11. Wi-Fi credentials never enter WiFiLab logs/JSON.
12. NETWORK connectable scans and SURVEY passive scans remain separate concepts.
13. Accepted prior tabs remain regression-tested surfaces.
14. Each accepted phase receives a rollback checkpoint before the next phase starts.
