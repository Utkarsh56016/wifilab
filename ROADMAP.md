# WiFiLab Roadmap

WiFiLab is currently being developed as a dedicated wireless-lab, adapter-management, passive-capture, and pentesting-support console for the validated Archcraft workstation.

Cross-distribution portability and packaging are intentionally deferred until the workstation feature set is mature and stable.

## Engineering Rule From This Point Forward

WiFiLab uses a strict **build one feature → test → stabilize → checkpoint → continue** workflow.

```text
stable main
    |
    v
one bounded feature phase
    |
    +--> backend contract
    +--> backend implementation
    +--> CLI / JSON validation
    +--> real-hardware validation
    +--> Quickshell integration
    +--> UI + regression validation
    +--> stabilization only
    |
    v
accepted main
    |
    v
immutable checkpoint branch
    |
    v
next phase
```

No later feature phase starts while the current phase is still being implemented or stabilized.

Existing stabilized behavior is treated as infrastructure, not as a place for opportunistic rewrites.

See:

- `docs/BUILD_AND_STABILIZATION_METHOD.md`
- `docs/WORKSTATION_EXPANSION_PLAN.md`
- `docs/ROLLBACK_CHECKPOINTS.md`

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
| 6 | Non-root bounded passive capture baseline | Stabilized / validated checkpoint |
| 7 | CAPTURES workspace | **Next** |
| 8 | NETWORK device manager + interface roles/LAB path | Planned |
| 9 | SURVEY passive wireless environment | Planned |
| 10 | LAB controlled pentesting workspace | Planned |
| 11 | Post-expansion hardening / packaging / portability | Deferred |

Target workstation navigation after expansion:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

SYSTEM/DOCTOR remains a utility drawer/panel rather than a permanent primary tab for now.

---

## Phase 0 — Hardware Validation

Status: **Complete**

Validated:

- dynamic adapter / PHY / driver mapping
- RTL8822BU monitor capability
- legal `IN` regulatory domain
- managed → monitor → managed lifecycle
- passive 802.11 reception
- NetworkManager restore
- system Wi-Fi isolation

---

## Phase 1 — Read-Only Discovery

Status: **Complete**

Implemented and validated:

- sysfs wireless enumeration
- PHY, driver, bus, VID:PID and human-readable device identity
- NetworkManager state and connection detection
- monitor capability and regulatory reporting
- human-readable CLI output
- machine-readable JSON
- system-vs-lab role inference
- symlink-safe launcher resolution

Design conclusion:

> Interface names, PHY names, and MAC addresses are runtime properties, not stable physical identity keys.

---

## Phase 2 — Safe State Controller

Status: **Complete**

Implemented and validated:

- `wifilab monitor [iface]`
- `wifilab managed [iface]`
- `wifilab restore [iface]`
- `wifilab channel [iface] <channel>`
- active-system-interface refusal
- IPv4/IPv6 default-route protection
- live-wireless-interface validation
- monitor-capability validation
- per-interface NetworkManager release / restore
- post-transition validation
- deterministic rollback helper
- development-only rollback fault injection
- regulatory rejection delegated to kernel/cfg80211 without bypass

---

## Phase 3 — Persistent Selection and CLI Hardening

Status: **Complete**

Implemented and validated:

- persistent physical adapter identity based on bus/device/driver/path metadata
- argument-free control of the selected lab adapter
- runtime re-resolution after USB re-enumeration
- stale `wlanX` hints treated as non-authoritative
- structured JSON endpoints for UI/agent consumers
- clear non-zero error paths for malformed and unsupported operations

Validated across repeated runtime re-enumeration and reboot, including names such as:

```text
wlan13
wlan15
wlan17
wlan2
```

---

## Phase 4 — Quickshell Integration

Status: **Complete**

Implemented and validated:

- Quickshell 0.3.1 integration under Wayland/niri
- centered floating niri window rule
- DMS-aligned translucent/glass styling
- CONTROL and TRAFFIC views
- adapter selector with protected-system-device state
- selected adapter state reconstruction from backend JSON
- privileged mutation boundary through `pkexec` and the root-owned helper
- authorization cancellation with zero radio mutation
- activity/error feedback
- close-without-restore state persistence

---

## Phase 5 — Floating Panel Reliability and Telemetry

Status: **Complete**

Implemented and validated:

- live RX/TX byte and packet telemetry from sysfs
- graceful telemetry degradation while selected hardware is absent
- regulatory-aware channel controls
- automatic UI recovery after hot unplug/replug
- physical identity retained while stale runtime netdev state is discarded
- active monitor-mode unplug/replug recovery
- protected `wlan0` connectivity and default-route isolation
- malformed privileged requests rejected before mutation
- disabled channel requests rejected while the previous valid channel remained intact

A proposed repeated 10-cycle soak was intentionally waived after the acceptance matrix already covered the meaningful state, authorization, hotplug, identity, and regulatory failure modes.

---

## Phase 6 — Non-Root Bounded Passive Capture Baseline

Status: **Stabilized / validated checkpoint**

Implemented and validated:

- `wireshark-cli`, `dumpcap`, and `tshark` capability discovery
- normal-user capture through the `wireshark` group and package-managed `dumpcap` capabilities
- no root `tshark` / `dumpcap` execution
- capture permission state exposed through JSON
- bounded PCAPNG capture on the selected physical lab adapter
- capture requires monitor mode
- protected/default-route wireless interfaces are refused
- physical adapter re-resolution immediately before capture
- duration and file-size bounds
- private XDG capture directory
- capture inventory JSON
- TRAFFIC capture readiness + bounded capture control
- IEEE 802.11 + radiotap output validated with real frames
- primary default route remained on `wlan0` throughout capture and restore
- capture behavior survived reboot and re-enumeration from `wlan17` to `wlan2`
- capture files validated from very low traffic through normal traffic without corruption

Known-good functional rollback checkpoint:

```text
commit: ac1af9f4c970d02d906a5625619a75f72a1faeec
branch: checkpoint/phase6-capture-ui-validated-2026-08-26
```

The baseline capture primitive is now frozen. Further capture analysis belongs to Phase 7 rather than continued modification of the validated primitive.

---

# Expansion Phases

## Phase 7 — CAPTURES Workspace

Status: **Next**

Goal:

> Convert saved PCAPNG files into a deterministic analysis workspace and remove protocol visualization dependence on repeated live capture.

Planned instruments / backend work:

- CAPTURES primary tab
- capture-session list
- richer capture inventory JSON
- latest-capture JSON
- capture timestamp
- capture-time runtime interface
- channel/frequency metadata where available
- packet count
- duration
- file size
- encapsulation
- SHA256/hash metadata
- offline `tshark -r` frame/protocol breakdown
- Wireshark GUI availability detection
- `Open in Wireshark`
- `Reveal File`
- safe viewer-unavailable state
- replace periodic live `tshark` protocol sampling with saved-PCAP analysis

First-iteration non-goals:

- file deletion
- rename/tagging
- background capture daemon
- attack workflows

Acceptance requirements:

- saved capture analysis performs no new live capture
- analysis/viewer actions do not mutate radio/network state
- CONTROL and TRAFFIC regressions pass
- `wlan0` remains protected
- phase receives a new checkpoint before Phase 8 begins

---

## Phase 8 — NETWORK Device Manager and LAB Path

Status: **Planned**

Goal:

> Make the complete workstation network topology visible while explicitly distinguishing the protected production path from lab interfaces.

This phase introduces the interface-role model:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

Expected workstation examples:

```text
wlan0     PRIMARY
wlan2     LAB
eno1      AUXILIARY
virbr0    VIRTUAL
docker0   VIRTUAL
tun*/wg*  TUNNEL
```

Planned instruments:

- physical + virtual network-device inventory
- interface kind/type
- wireless MAN/MON state
- link state
- NetworkManager state
- driver/PHY where applicable
- MAC / MTU
- IPv4 / IPv6
- subnet/prefix
- gateway
- DNS context
- routes + metrics
- default-route ownership
- protected status
- bridge/master membership
- tunnel/VPN context
- Docker/libvirt relationships where safely discoverable
- RX/TX counters
- interface role

Dedicated LAB PATH instrument:

```text
source interface
source address
subnet
gateway
default-route ownership
primary internet interface
protection/isolation state
```

Initial controlled actions remain narrow and reuse existing guards. PRIMARY cannot become a bypass around CONTROL safety.

Phase 8 begins only after Phase 7 is checkpointed.

---

## Phase 9 — SURVEY Passive Wireless Environment

Status: **Planned**

Goal:

> Provide passive wireless situational awareness from monitor-mode observations.

Initial scope: **current-channel passive survey only**.

Planned instruments where captured metadata supports them:

- BSSID
- SSID / hidden state
- observed channel
- frame count
- first seen / last seen
- beacon count
- probe request / response counts
- management/data/control frame mix
- advertised security information
- OUI/vendor summary
- RSSI/signal information when radiotap data is reliable
- passive current-channel activity summary

Explicit first-iteration non-goals:

- channel hopping
- deauthentication
- frame injection
- disruptive active scanning
- association attacks

Phase 9 begins only after the NETWORK role/protection model is stable and checkpointed.

---

## Phase 10 — LAB Controlled Pentesting Workspace

Status: **Planned**

Goal:

> Coordinate lab-security workflows using an already-validated LAB interface, protected PRIMARY path, and explicit target/scope context.

Top-level context:

```text
Lab interface
Lab mode
Lab subnet
Primary interface [PROTECTED]
Scope state
```

Planned modules:

### Discovery

- neighbour/ARP state
- gateway
- known lab hosts
- subnet context
- reachable-host observations
- DNS context

### Services

- selected host
- observed/discovered services
- saved observations
- later optional integration with external discovery/scanning tools

### Wireless

- selected BSSID/AP
- channel
- observed security metadata
- capture references
- survey references

### Session

- notes
- commands/actions executed through WiFiLab
- timestamps
- capture references
- target/scope context

Design rule:

> WiFiLab orchestrates and constrains external lab tools; it does not reimplement every security utility.

Potential integrations such as `nmap`, Wireshark, tshark, and separately reviewed aircrack-ng workflows require their own backend contracts and safety validation.

Deferred advanced wireless operations remain separate:

- channel hopping
- handshake-oriented workflows
- frame injection
- deauthentication
- other active wireless attack operations

The existence of the LAB tab does not automatically enable these capabilities.

---

## SYSTEM / DOCTOR Utility

Status: **Incremental utility, not a primary phase tab**

Keep diagnostics available from the existing health/doctor surface.

Planned additions as needed by phases:

- backend state
- selected physical identity
- polkit/helper availability
- capture permission
- dumpcap/tshark/viewer availability
- regulatory state
- protected/default-route guard
- dependency checks
- backend errors
- data/capture paths

SYSTEM/DOCTOR remains diagnostics/capability reporting, not an alternate mutation path.

---

## Phase 11 — Post-Expansion Hardening, Packaging, and Portability

Status: **Deferred**

Do not work on this phase while workstation feature expansion is active.

Possible later scope:

- package/install/uninstall model
- shell completion
- generic capability diagnostics
- dependency documentation
- broader Linux host support
- compositor/theme portability
- network-management abstraction
- distro packaging

These concerns must not distract from the current workstation lab build.

---

# Release-Blocking Invariants for Every Expansion Phase

Every new feature must preserve all of the following:

1. `wlan0` / default-route wireless connectivity remains protected.
2. The physical lab adapter remains authoritative despite changing runtime `wlanX` / `phyX` names.
3. No global NetworkManager shutdown or disruption.
4. No `airmon-ng check kill` style workflow.
5. No regulatory bypass.
6. Quickshell never runs as root.
7. Capture never gains a root/pkexec path merely for convenience.
8. New-feature failure cannot mutate unrelated network state.
9. CONTROL and TRAFFIC remain regression-tested stabilized surfaces.
10. Each accepted expansion phase receives a rollback checkpoint before the next phase starts.
