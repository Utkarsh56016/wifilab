# WiFiLab Roadmap

WiFiLab is developed as a workstation-first wireless-lab, adapter-management, passive-capture, and authorized pentesting-support console for the validated Archcraft system.

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
| 7 | CAPTURES workspace | **Accepted / checkpointed** |
| 8 | NETWORK device manager + interface roles / LAB path | **Next** |
| 9 | SURVEY passive wireless environment | Planned |
| 10 | LAB controlled pentesting workspace | Planned |
| 11 | Post-expansion hardening / packaging / portability | Deferred |

Target navigation:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

SYSTEM/DOCTOR remains a utility surface rather than a permanent primary tab.

---

## Phase 0 — Hardware Validation

Status: **Complete**

Validated dynamic adapter/PHY/driver mapping, RTL8822BU monitor capability, legal `IN` regulatory state, managed/monitor lifecycle, passive 802.11 reception, NetworkManager restore, and primary-system Wi-Fi isolation.

## Phase 1 — Read-Only Discovery

Status: **Complete**

Validated sysfs wireless discovery, role inference, human and JSON output, driver/bus/VID:PID identity, monitor capability, NetworkManager state, and symlink-safe launcher behavior.

Design conclusion:

> Runtime `wlanX`, `phyX`, and MAC values are not persistent physical identity.

## Phase 2 — Safe State Controller

Status: **Complete**

Validated monitor/managed/restore/channel operations, active/default-route refusal, per-interface NetworkManager coordination, post-transition validation, rollback, and regulatory enforcement through the kernel.

## Phase 3 — Persistent Selection and CLI Hardening

Status: **Complete**

Validated persistent physical selection based on bus/device/driver/path metadata, runtime re-resolution after USB re-enumeration, stale-name rejection, and structured JSON error paths.

## Phase 4 — Quickshell Integration

Status: **Complete**

Validated Quickshell under Wayland/niri, DMS-aligned UI, adapter selection/protection state, polkit-backed guarded mutations, authorization cancellation, and state persistence.

## Phase 5 — UI Reliability and Telemetry

Status: **Complete**

Validated sysfs RX/TX telemetry, hotplug recovery, regulatory-aware channel UI, stale netdev recovery, protected `wlan0`, and malformed privileged-request refusal.

## Phase 6 — Non-Root Bounded Passive Capture

Status: **Stabilized / checkpointed**

Validated normal-user `dumpcap`, monitor-mode-only bounded PCAPNG capture, protected/default-route refusal, private capture storage, TRAFFIC capture controls, radiotap output, reboot/re-enumeration survival, and preserved `wlan0` default route.

Checkpoint:

```text
ac1af9f4c970d02d906a5625619a75f72a1faeec
checkpoint/phase6-capture-ui-validated-2026-08-26
```

---

# Expansion Phases

## Phase 7 — CAPTURES Workspace

Status: **Accepted / checkpointed**

Goal achieved:

> Convert saved PCAPNG files into a deterministic analysis workspace and eliminate protocol visualization dependence on repeated live capture.

Implemented and validated:

- `CONTROL | TRAFFIC | CAPTURES` navigation within the frozen `1040 × 720` shell
- per-capture JSON manifest sidecars
- capture-time interface/PHY/driver/channel/frequency/regdomain metadata
- SHA-256 capture integrity metadata
- richer backward-compatible capture inventory
- `wifilab capture latest --json`
- legacy Phase 6 capture compatibility without migration/rewrite
- strict capture-ID grammar and directory confinement
- traversal, missing-file, invalid-ID, and symlink refusal
- `wifilab capture protocols <id|latest> --json`
- compatibility `wifilab protocols --json` now reading the latest saved capture
- complete removal of live `tshark -i` protocol sampling
- offline analysis through `tshark -r`
- on-demand `capinfos` inspection for type, encapsulation, packet count, bytes, duration, and timestamps
- manifest SHA verification with `verified`, `mismatch`, and `untracked` states
- GUI viewer capability detection
- validated `capture reveal` through the normal desktop opener
- safe `viewer_unavailable` behavior when GUI Wireshark is absent
- CAPTURES library, inspector, integrity state, offline protocol labels, Reveal action, and disabled viewer action when unavailable
- no persistent `tshark`, `dumpcap`, or `capinfos` process churn
- CONTROL and TRAFFIC visual/functional regression pass
- primary default route remained on `wlan0`

Final acceptance evidence on 2026-08-27:

```text
LAB interface         wlan4 / phy4
LAB driver            rtw88_8822bu
LAB mode              monitor
NetworkManager        unmanaged
regdomain             IN
PRIMARY default route wlan0
capture ready         true
saved captures        6
latest capture        18 packets / 8024 bytes / 9.932723659 s
encapsulation         ieee-802-11-radiotap
integrity             verified
protocol source       saved_capture
live tshark -i        none
leftover analysis     none
```

Functional checkpoint:

```text
17c79c134c1b66f56cc9821191e7c1fdbb533709
checkpoint/phase7-captures-validated-2026-08-27
```

Accepted non-goals remain:

- capture deletion
- rename/tagging
- long-running background capture daemon
- attack workflows

Known deferred integration item:

- install a matching `io.github.utkarsh56016.wifilab.desktop` entry so the QML AppId can register cleanly with XDG Desktop Portal; current warning is non-blocking and has no capture/network impact.

---

## Phase 8 — NETWORK Device Manager and LAB Path

Status: **Next**

Goal:

> Make the full workstation network topology visible while explicitly distinguishing the protected production path from lab interfaces.

Interface-role model:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

Initial backend work should remain read-only first.

Planned instruments:

- physical and virtual interface inventory
- interface kind/type
- link state
- NetworkManager state
- wireless MAN/MON state where applicable
- driver/PHY where applicable
- MAC and MTU
- IPv4/IPv6 addresses and prefixes
- gateway and DNS context
- routes and metrics
- default-route ownership
- protected state
- bridge/master membership
- tunnel/VPN context
- Docker/libvirt relationships where safely discoverable
- RX/TX counters
- explicit interface role

Dedicated LAB PATH view:

```text
source interface
source address
subnet
gateway
default-route ownership
primary internet interface
protection / isolation state
```

Phase 8 safety rules:

- PRIMARY remains heavily protected.
- NETWORK cannot bypass CONTROL safety.
- Start with read-only topology before adding any controlled actions.
- Reuse existing physical identity and default-route guards instead of duplicating them.
- Do not couple Docker/libvirt state changes into initial discovery.

Phase 8 begins from the Phase 7 checkpoint.

---

## Phase 9 — SURVEY Passive Wireless Environment

Status: **Planned**

Initial scope is current-channel passive survey only: BSSID/SSID, frame counts, timestamps, beacon/probe summaries, frame-type mix, security advertisement, vendor/OUI, and signal metadata where radiotap supports it reliably.

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
10. CONTROL and TRAFFIC remain regression-tested surfaces.
11. Each accepted phase receives a rollback checkpoint before the next phase starts.
