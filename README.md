# WiFiLab

WiFiLab is a Linux wireless-lab and adapter-management utility being developed on an Archcraft workstation for safe radio control, passive capture, network inspection, and progressively integrated lab/pentesting workflows.

The project is intentionally built as an engineering system rather than a collection of shell one-liners. Adapter identity is resolved dynamically, privileged mutations are narrowly scoped, the primary network path is protected, captures remain non-root, and every accepted feature is tested and stabilized before the next one is allowed to change the baseline.

> **Current focus:** workstation-first expansion for wireless lab work and authorized pentesting. Portability and broad distro packaging are intentionally deferred until the workstation feature set is mature.

## Current Status

The validated baseline currently includes:

- dynamic wireless adapter, PHY, driver, bus, VID:PID, and sysfs identity discovery
- persistent physical lab-adapter selection that survives USB re-enumeration and reboot
- managed / monitor / restore lifecycle
- regulatory-aware channel control
- NetworkManager coordination scoped to the selected adapter
- IPv4/IPv6 default-route protection
- protected system Wi-Fi isolation
- root-owned, allowlisted radio helper behind polkit for state mutation
- Quickshell floating UI under niri with CONTROL and TRAFFIC tabs
- live RX/TX byte and packet telemetry from sysfs
- non-root `dumpcap` capture using normal Wireshark capture permissions
- bounded PCAPNG capture with duration and file-size limits
- real IEEE 802.11 + radiotap capture validation
- capture inventory exposed through JSON
- TRAFFIC-tab capture readiness and bounded-capture control
- deterministic restore to managed mode after lab use

The latest validated functional checkpoint is:

```text
commit: ac1af9f4c970d02d906a5625619a75f72a1faeec
branch: checkpoint/phase6-capture-ui-validated-2026-08-26
```

That checkpoint is intentionally kept separate from later documentation and expansion work so there is always a known-good rollback point.

See [`docs/ROLLBACK_CHECKPOINTS.md`](docs/ROLLBACK_CHECKPOINTS.md).

## Development Host

WiFiLab is currently validated on:

- Archcraft Linux
- Wayland + niri
- Dank Material Shell themed desktop
- NetworkManager
- Quickshell 0.3.1
- Linux wireless stack via cfg80211/mac80211/nl80211
- `iw`, `iproute2`, `udev`, `nmcli`
- Wireshark CLI tools (`dumpcap`, `tshark`, `capinfos`)

Current wireless hardware:

| Role | Adapter | Bus | Driver | Purpose |
|---|---|---|---|---|
| Primary system Wi-Fi | MediaTek MT7922 | PCIe | `mt7921e` | normal workstation connectivity |
| Lab wireless adapter | TP-Link `2357:0138` / RTL8822BU family | USB | `rtw88_8822bu` | managed/monitor lab work and passive capture |

Runtime interface names are **not** treated as identity. The same TP-Link adapter has appeared under multiple `wlanX` / `phyX` names during testing, including `wlan13`, `wlan15`, `wlan17`, and `wlan2`.

WiFiLab therefore resolves the selected physical device from persistent bus/device/driver/path metadata at operation time.

## Architecture

```text
                         WiFiLab
                            │
              ┌─────────────┴─────────────┐
              │                           │
        Quickshell UI                  CLI / JSON
              │                        `wifilab`
              └─────────────┬─────────────┘
                            │
                     WiFiLab backend
                            │
          ┌─────────────────┼──────────────────┐
          │                 │                  │
     discovery         state / safety       capture
          │                 │                  │
   sysfs / udev / iw   ip / iw / nmcli     dumpcap
          │                 │                  │
          └─────────────────┼──────────────────┘
                            │
                  Linux networking stack
                            │
                 cfg80211 / mac80211
```

Privileged radio mutations are separated from the UI:

```text
Quickshell / future agent
          │
          │ unprivileged request
          ▼
        pkexec
          ▼
root-owned wifilab-helper
          │
          ├── re-resolve selected physical adapter
          ├── validate wireless target
          ├── reject active/default-route interfaces
          ├── enforce allowlisted operation
          └── perform validated mutation
```

Capture follows a different path:

```text
WiFiLab UI / CLI
      │
      ▼
selected physical lab adapter
      │
      ├── protected?   → refuse
      ├── monitor?     → required
      └── permitted?   → normal-user dumpcap permission
      │
      ▼
  bounded dumpcap
      │
      ▼
   .pcapng file
```

There is deliberately **no sudo/pkexec capture path**.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Safety Model

WiFiLab follows several non-negotiable rules:

1. Never trust `wlanX`, `phyX`, or a MAC address as permanent physical identity.
2. Never mutate a wireless interface carrying an active NetworkManager connection or system default route.
3. Keep the primary system Wi-Fi isolated from lab-adapter operations.
4. Never globally kill or restart NetworkManager just to enter monitor mode.
5. Respect the kernel regulatory domain and legal channel state.
6. Revalidate the selected physical device at operation time.
7. Validate every state transition after execution.
8. Provide a deterministic restore path.
9. Keep the Quickshell UI unprivileged.
10. Keep passive capture non-root and bounded.
11. Treat malformed, stale, unsupported, and protected targets as refusal conditions rather than reasons to weaken safety checks.

## Current UI

The accepted UI currently contains two stabilized tabs:

```text
CONTROL | TRAFFIC
```

### CONTROL

Primary radio-management surface:

- adapter selector
- physical device identity
- runtime interface / PHY
- driver
- managed / monitor controls
- channel selector
- band / frequency
- regulatory state
- NetworkManager state
- protected-interface status
- monitor capability
- restore action
- recent activity / errors

### TRAFFIC

Live telemetry and bounded-capture surface:

- RX/TX rates
- RX/TX packet rates
- live graph
- selected runtime interface
- current radio mode
- capture readiness
- saved-capture count
- bounded capture control

The accepted panel geometry remains `1040 × 720`. Expansion work should add features without casually destabilizing the existing CONTROL and TRAFFIC layouts.

## Current CLI

```bash
wifilab adapters
wifilab list
wifilab info
wifilab --json
wifilab doctor

wifilab select [iface]
wifilab status [--json]

wifilab radio --json
wifilab channels --json
wifilab telemetry --json
wifilab protocols --json

wifilab capture status --json
wifilab capture run [duration_seconds] [max_kib]
wifilab captures --json

wifilab monitor [iface]
wifilab managed [iface]
wifilab restore [iface]
wifilab channel [iface] <channel>
```

Typical selected-adapter workflow:

```bash
wifilab select
wifilab status
wifilab monitor
wifilab channel 11
wifilab capture status --json
wifilab capture run 10 10240
wifilab captures --json
wifilab restore
```

Capture limits currently enforce:

- duration: 1–300 seconds
- size bound: 256–102400 KiB
- monitor mode required
- protected/default-route interfaces refused
- no privilege escalation from the capture path

## Validated Capture Baseline

A representative successful capture validation produced:

```text
mode            : monitor
channel         : 11 / 2462 MHz
encapsulation   : IEEE 802.11 + radiotap
capture process : dumpcap
user            : normal desktop user
primary route   : remained on wlan0
```

The resulting files have been validated with `capinfos` and `tshark -r`, including real 802.11 frames.

The lab adapter was subsequently restored to managed mode while the primary system default route remained unchanged.

## Build and Stabilization Method

From the current checkpoint onward, WiFiLab uses a strict staged development method:

```text
STABLE MAIN
    │
    ▼
one bounded feature
    │
    ▼
backend contract first
    │
    ▼
backend implementation
    │
    ▼
CLI / JSON validation
    │
    ▼
real hardware validation
    │
    ▼
Quickshell integration
    │
    ▼
UI + regression validation
    │
    ▼
stabilization
    │
    ▼
document + checkpoint
    │
    ▼
next feature
```

A feature is not accepted merely because it works once. Before advancing, it must demonstrate:

- correct backend behavior
- safe refusal/failure behavior
- real hardware validation
- preserved primary `wlan0` connectivity
- correct UI behavior
- no CONTROL regression
- no TRAFFIC regression
- no unnecessary background capture/process churn
- documented final state
- documented rollback point

See [`docs/BUILD_AND_STABILIZATION_METHOD.md`](docs/BUILD_AND_STABILIZATION_METHOD.md).

## Workstation Expansion Roadmap

The workstation build is planned to evolve into:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

Tabs are added **one at a time**. A later tab is not started until the previous one is tested, stabilized, documented, and checkpointed.

### Phase 7 — CAPTURES

Next implementation target.

Purpose: convert the existing PCAP primitive into a deterministic capture-analysis workspace.

Planned instruments:

- saved capture session list
- timestamp
- runtime interface used at capture time
- channel/frequency where available
- packet count
- duration
- file size
- encapsulation
- hashes
- offline protocol/frame mix using `tshark -r`
- latest-capture JSON
- `Open in Wireshark`
- reveal capture file/directory
- explicit viewer-unavailable state

The long-term protocol view will be derived from saved captures instead of repeatedly starting short live `tshark` sessions from a UI timer.

### Phase 8 — NETWORK

Workstation networking topology and lab-path manager.

Planned interface roles:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

Planned instruments:

- physical and virtual network devices
- managed/monitor mode where applicable
- link state
- NetworkManager state
- IPv4 / IPv6
- subnet
- gateway
- DNS context
- MTU
- MAC / driver
- routes and metrics
- default-route ownership
- bridge / tunnel relationships
- protected state
- explicit LAB PATH view showing which interface/subnet/gateway a lab workflow will use

This phase becomes the safety foundation for later pentesting orchestration.

### Phase 9 — SURVEY

Passive wireless environment view, initially **current-channel only**.

Planned instruments:

- BSSID / SSID
- hidden SSID state
- current channel
- first / last seen
- frame count
- beacon count
- probe requests / responses
- management/data/control frame mix
- advertised security information
- vendor/OUI
- RSSI/noise where radiotap data is reliable
- channel activity

Channel hopping, injection, deauthentication, and other active wireless operations are not part of the initial SURVEY phase.

### Phase 10 — LAB

Controlled workstation pentesting workspace built on top of the stabilized NETWORK role/scope model.

Planned areas:

```text
DISCOVERY
├── neighbours / ARP
├── gateway
├── hosts
├── subnet context
└── DNS context

SERVICES
├── selected host
├── observed services
└── later external-tool integrations

WIRELESS
├── selected BSSID
├── observed security
├── survey references
└── capture references

SESSION
├── notes
├── actions
├── timestamps
├── captures
└── explicit scope
```

WiFiLab should orchestrate lab context and safety rather than reimplement every external security tool.

Advanced wireless attack workflows remain separate future design phases and require their own safety and validation contracts.

### Phase 11 — Post-expansion hardening / packaging / portability

Deferred until the workstation feature set is mature.

See [`ROADMAP.md`](ROADMAP.md) and [`docs/WORKSTATION_EXPANSION_PLAN.md`](docs/WORKSTATION_EXPANSION_PLAN.md).

## Repository Layout

High-level structure:

```text
wifilab/
├── README.md
├── ROADMAP.md
├── bin/          # CLI entry points
├── lib/          # unprivileged backend modules
├── libexec/      # privileged helper implementation
├── polkit/       # authorization policy
├── ui/           # Quickshell frontend
├── integration/  # desktop/system integration
├── packaging/    # packaging work
├── scripts/      # development/support scripts
└── docs/         # architecture, hardware, validation, rollback, plans
```

## Engineering Documentation

Important project documents include:

- [`ROADMAP.md`](ROADMAP.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/HARDWARE_BASELINE.md`](docs/HARDWARE_BASELINE.md)
- [`docs/ROLLBACK_CHECKPOINTS.md`](docs/ROLLBACK_CHECKPOINTS.md)
- [`docs/BUILD_AND_STABILIZATION_METHOD.md`](docs/BUILD_AND_STABILIZATION_METHOD.md)
- [`docs/WORKSTATION_EXPANSION_PLAN.md`](docs/WORKSTATION_EXPANSION_PLAN.md)

## Responsible Use

WiFiLab is intended for wireless experimentation, diagnostics, learning, adapter management, and security testing on equipment and networks the operator owns or is explicitly authorized to test.

The project deliberately separates passive observation, network-management functions, and future active lab/pentesting capabilities so expansion does not weaken the existing connectivity and privilege safety model.
