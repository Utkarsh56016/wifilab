# WiFiLab Workstation Expansion Plan

## Scope

This plan governs the current Archcraft workstation build.

Portability and broad cross-distribution packaging are intentionally deferred. The immediate goal is to expand WiFiLab as a stable wireless-lab, adapter-management, capture-analysis, network-context, and authorized pentesting-support utility on the validated workstation.

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

Validated baseline capabilities:

- persistent physical LAB-adapter identity
- protected PRIMARY Wi-Fi/default-route guard
- managed/monitor lifecycle
- legal channel control
- scoped NetworkManager coordination
- non-root bounded `dumpcap` capture
- PCAPNG + radiotap output
- capture manifest sidecars + SHA-256
- legacy capture compatibility
- offline `tshark -r` analysis
- `capinfos` inspection
- CAPTURES library/inspector UI
- safe viewer/reveal actions
- no repeated live `tshark -i` protocol sampling
- no persistent capture-analysis process churn
- accepted `1040 × 720` shell geometry

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

Primary instruments:

- adapter selector
- device/vendor identity
- runtime interface/PHY
- driver
- MAN/MON state
- NetworkManager state
- band/channel/frequency
- regulatory state
- monitor capability
- protected/default-route guard
- Restore
- activity/errors

Policy: do not turn CONTROL into a general security-tool launcher.

---

## TRAFFIC — Live Adapter Telemetry

Status: **Stable**

Purpose:

> Show current LAB-adapter telemetry and provide the bounded capture action.

Primary instruments:

- RX/TX bytes/sec
- RX/TX packets/sec
- live graph
- current runtime adapter/mode
- capture ready/busy/blocked state
- bounded capture action
- saved capture count
- offline latest-capture protocol summary

The old periodic live `tshark -i` sampling path has been removed. Protocol visualization now derives from saved capture data.

---

## CAPTURES — PCAP Workspace

Status: **Accepted / checkpointed**

Purpose:

> Turn saved bounded captures into a deterministic offline analysis workspace.

Implemented:

```text
CAPTURE LIBRARY
  -> newest-first saved capture inventory
  -> complete / legacy / invalid metadata state
  -> runtime capture-time adapter/channel metadata where available

CAPTURE INSPECTOR
  -> packets
  -> duration
  -> size
  -> file type
  -> encapsulation
  -> first / last frame timestamp
  -> SHA-256 integrity state
  -> offline protocol labels
  -> Reveal
  -> Open in Wireshark when available
```

Backend contracts:

```bash
wifilab captures --json
wifilab capture latest --json
wifilab capture inspect <id|latest> --json
wifilab capture protocols <id|latest> --json
wifilab capture viewer status --json
wifilab capture open <id|latest>
wifilab capture reveal <id|latest>
```

Compatibility:

```bash
wifilab protocols --json
```

reads the latest saved capture offline.

Accepted CAPTURES safety properties:

- only `capture run` can invoke live capture
- saved analysis never opens a live interface
- capture IDs are validated; arbitrary paths are not accepted
- traversal, missing files, and symlinks are refused
- old Phase 6 PCAPs remain valid without rewriting them
- manifest failure does not delete a successful PCAP
- `capinfos` runs only on demand
- `tshark` analysis is `-r` only
- viewer/reveal are normal-user desktop actions
- viewer absence is represented explicitly rather than forcing installation

Current workstation viewer state:

```text
Wireshark CLI tools: available
Wireshark GUI:       unavailable
Reveal opener:       xdg-open
```

Deferred packaging item:

- matching desktop registration for `io.github.utkarsh56016.wifilab` to remove the current non-blocking portal AppId warning.

---

## NETWORK — Workstation Networking Device Manager

Expansion priority: **1 — next feature**

Purpose:

> Make the workstation network topology visible while making the protected production path and intended LAB path explicit.

### Phase 8 implementation order

Build NETWORK with the same bounded methodology:

```text
8A  read-only interface inventory
8B  address + route/default-route model
8C  interface role model
8D  LAB PATH derivation
8E  virtual/bridge/tunnel relationships
8F  NETWORK QML tab
8G  regression + checkpoint
```

Do not start with mutations.

### Interface role model

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

Expected examples on the workstation may include:

```text
wlan0      PRIMARY
wlanX      LAB
Ethernet   AUXILIARY
virbr0     VIRTUAL
docker0    VIRTUAL
tun*/wg*   TUNNEL
```

Runtime names are observations, not persistent physical LAB identity.

### Planned read-only instruments

- interface name and type/kind
- wireless PHY/driver where applicable
- MAN/MON state where applicable
- link/operstate
- NetworkManager state
- MAC
- MTU
- IPv4 / IPv6 addresses and prefix lengths
- subnet context
- gateway
- DNS context
- routes + metrics
- default-route ownership
- protected state
- bridge/master membership
- virtual interface relationships
- tunnel/VPN context
- Docker/libvirt relationships where safely inferable
- RX/TX counters
- explicit role

### LAB PATH instrument

```text
LAB PATH
------------------------------
source interface
source address
subnet/prefix
gateway
route used for target/default
PRIMARY interface
PRIMARY default-route owner
LAB/PRIMARY isolation state
```

### Phase 8 safety rules

- PRIMARY remains protected and cannot be converted into a convenience LAB target.
- Existing default-route safety code remains authoritative.
- Physical LAB identity remains tied to existing persistent selection metadata.
- Do not duplicate or weaken CONTROL guards.
- Initial Docker/libvirt/tunnel discovery is read-only.
- No global NetworkManager manipulation.
- No route mutation until a later bounded subphase explicitly defines and validates it.

---

## SURVEY — Passive Wireless Environment

Expansion priority: **2**

Purpose:

> Build passive current-channel situational awareness from monitor-mode observations and/or saved captures.

Initial instruments where capture metadata supports them:

- BSSID
- SSID / hidden state
- observed channel
- first/last seen
- frame count
- beacon/probe counts
- management/data/control mix
- advertised security metadata
- OUI/vendor
- RSSI/signal values when radiotap data is reliable

First-iteration non-goals: channel hopping, deauthentication, injection, association attacks, disruptive active scanning.

---

## LAB — Controlled Pentesting Workspace

Expansion priority: **3**

Purpose:

> Coordinate authorized lab-security workflows only after NETWORK provides a validated LAB interface, protected PRIMARY path, and explicit scope context.

Planned modules:

- Discovery
- Services
- Wireless
- Session / notes / capture references / scope

Design rule:

> WiFiLab orchestrates and constrains external lab tools; it does not reimplement every security utility.

Active wireless attack workflows remain separate future safety/design work.

---

## SYSTEM / DOCTOR Utility

Status: **Existing, incremental**

Keep diagnostics available without turning SYSTEM into an alternate mutation path.

Useful capability state includes backend status, physical selection, helper/polkit availability, capture permission, dumpcap/tshark/capinfos/viewer state, regulatory state, protected/default-route state, errors, and data paths.

---

## Expansion Order

```text
CURRENT ACCEPTED STATE
CONTROL + TRAFFIC + CAPTURES
        |
        v
Phase 8  NETWORK
        |
        v
stabilize + checkpoint
        |
        v
Phase 9  SURVEY
        |
        v
stabilize + checkpoint
        |
        v
Phase 10 LAB
        |
        v
stabilize + checkpoint
```

No later-phase feature is pulled forward unless it is an explicit dependency and is added to the active phase scope before implementation.

## UI Expansion Policy

The window remains `1040 × 720` during workstation expansion unless a shell-size change is separately justified and validated.

Existing CONTROL, TRAFFIC, and CAPTURES layouts are stabilized surfaces. New tabs should be added without broad refactoring of accepted geometry.

## Definition of Done for Every New Tab

A tab is stable only when:

- backend contract works independently of UI
- success path works on the real workstation
- meaningful refusal/error paths are validated
- PRIMARY `wlan0` connectivity remains protected
- LAB physical identity remains correct across runtime names
- UI agrees with backend JSON
- prior tabs pass regression
- no unexpected process churn exists
- final documentation is updated
- a rollback checkpoint branch is created

See `docs/BUILD_AND_STABILIZATION_METHOD.md`.
