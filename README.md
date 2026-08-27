# WiFiLab

WiFiLab is a workstation-first Linux wireless-lab and adapter-management utility for safe radio control, bounded passive capture, saved-PCAP analysis, network inspection, and progressively integrated authorized lab/pentesting workflows.

The project is developed as an engineering system: physical adapter identity is resolved dynamically, privileged mutations are narrowly scoped, the primary network path is protected, capture remains non-root, and each accepted phase is validated and checkpointed before the next phase begins.

> **Current focus:** Phase 7 (CAPTURES) is accepted and stabilized. Phase 8 (NETWORK) is the next implementation target. Cross-distribution portability and broad packaging remain deferred.

## Current Validated Baseline

The accepted workstation baseline now includes:

- dynamic wireless adapter / PHY / driver / bus / VID:PID / sysfs discovery
- persistent physical lab-adapter selection across USB re-enumeration and reboot
- managed / monitor / restore lifecycle
- regulatory-aware channel control
- NetworkManager coordination scoped to the selected adapter
- IPv4/IPv6 default-route protection and protected system Wi-Fi isolation
- root-owned allowlisted radio helper behind polkit for state mutation
- Quickshell UI under niri with `CONTROL | TRAFFIC | CAPTURES`
- live RX/TX byte and packet telemetry from sysfs
- non-root bounded `dumpcap` capture through normal Wireshark permissions
- PCAPNG output with IEEE 802.11 + radiotap
- per-capture JSON manifest sidecars with capture-time radio metadata and SHA-256
- richer capture inventory with legacy Phase 6 compatibility
- `capture latest`, `capture inspect`, `capture protocols`, viewer status, open, and reveal contracts
- on-demand PCAP metadata inspection through `capinfos`
- saved-PCAP protocol analysis through `tshark -r` only
- no `tshark -i` live protocol sampling path
- CAPTURES workspace with capture library, integrity state, offline protocol labels, reveal action, and graceful Wireshark-GUI-unavailable state
- fixed accepted UI geometry of `1040 × 720`

Latest validated functional checkpoint:

```text
commit: 17c79c134c1b66f56cc9821191e7c1fdbb533709
branch: checkpoint/phase7-captures-validated-2026-08-27
```

See [`docs/ROLLBACK_CHECKPOINTS.md`](docs/ROLLBACK_CHECKPOINTS.md).

## Development Host

Validated on:

- Archcraft Linux
- Wayland + niri
- Dank Material Shell
- NetworkManager
- Quickshell 0.3.1
- cfg80211/mac80211/nl80211
- `iw`, `iproute2`, `udev`, `nmcli`
- Wireshark CLI tools: `dumpcap`, `tshark`, `capinfos`

Wireless roles:

| Role | Adapter | Bus | Driver | Purpose |
|---|---|---|---|---|
| Primary system Wi-Fi | MediaTek MT7922 | PCIe | `mt7921e` | workstation connectivity |
| Lab wireless adapter | TP-Link `2357:0138` / RTL8822BU family | USB | `rtw88_8822bu` | managed/monitor lab work and passive capture |

Runtime `wlanX` / `phyX` names are never treated as persistent identity.

## Architecture

```text
Quickshell UI / CLI
        |
        v
WiFiLab backend
   |           |
   |           +--> saved capture analysis
   |                 |- inventory / latest
   |                 |- capinfos inspection
   |                 |- tshark -r protocols
   |                 `- viewer/reveal
   |
   +--> radio state / safety
             |
             +--> pkexec -> root-owned helper -> validated mutation

Capture path:
selected physical LAB adapter
        |
        +--> protected/default-route? refuse
        +--> monitor mode required
        +--> normal-user dumpcap permission required
        v
bounded dumpcap
        v
capture-*.pcapng + capture-*.json
```

There is deliberately no `sudo/pkexec` packet-capture path.

## Safety Invariants

1. Never trust runtime interface, PHY, or MAC names as permanent physical identity.
2. Never mutate an interface carrying an active NetworkManager connection or default route.
3. Keep PRIMARY system Wi-Fi isolated from LAB operations.
4. Never globally kill/restart NetworkManager to enter monitor mode.
5. Respect kernel/cfg80211 regulatory state.
6. Re-resolve the selected physical adapter at operation time.
7. Keep Quickshell unprivileged.
8. Keep passive capture non-root and bounded.
9. Only `capture run` may initiate packet capture.
10. Saved-capture analysis must use file readers (`capinfos`, `tshark -r`) and must not open a live interface.
11. Reject malformed IDs, traversal, absent captures, and symlinked capture paths.
12. Preserve CONTROL and TRAFFIC as stabilized surfaces while later tabs are added.

## Current UI

```text
CONTROL | TRAFFIC | CAPTURES
```

### CONTROL

Radio and physical-adapter command center: selection, identity, MAN/MON, channel/frequency/regdomain, NetworkManager state, protection state, restore, and guarded mutations.

### TRAFFIC

Live sysfs telemetry plus bounded capture: RX/TX rates, packet rates, graph, capture readiness, saved count, and non-root bounded capture action. Protocol display now consumes the latest saved capture rather than starting live `tshark` sampling.

### CAPTURES

Saved-PCAP workspace:

- capture library ordered newest-first
- Phase 7 manifest metadata plus Phase 6 legacy compatibility
- packet count, size, duration, timestamps, file type and encapsulation
- current SHA-256 and manifest integrity verification
- offline protocol breakdown from `tshark -r`
- reveal capture directory
- viewer capability state
- `Open in Wireshark` only when GUI Wireshark is actually available

The current workstation has Wireshark CLI tools but not the GUI binary, so the UI correctly presents `WIRESHARK N/A` while `REVEAL` remains available.

A known non-blocking desktop integration warning remains: the QML AppId `io.github.utkarsh56016.wifilab` has no installed matching `.desktop` entry yet. That is deferred to packaging/integration hardening and does not affect capture or networking behavior.

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

wifilab capture status --json
wifilab capture run [duration_seconds] [max_kib]
wifilab captures --json
wifilab capture latest --json
wifilab capture inspect <id|latest> --json
wifilab capture protocols <id|latest> --json
wifilab protocols --json
wifilab capture viewer status --json
wifilab capture open <id|latest>
wifilab capture reveal <id|latest>

wifilab monitor [iface]
wifilab managed [iface]
wifilab restore [iface]
wifilab channel [iface] <channel>
```

`wifilab protocols --json` is retained as a compatibility alias for offline latest-capture analysis.

## Phase 7 Acceptance Evidence

Final acceptance on 2026-08-27 validated:

```text
LAB runtime      : wlan4 / phy4
LAB driver       : rtw88_8822bu
LAB mode         : monitor
NetworkManager   : unmanaged
regdomain        : IN
PRIMARY route    : wlan0
capture ready    : true
capture inventory: 6 saved captures
latest PCAP      : 18 packets / 8024 bytes / ~9.933 s
encapsulation    : ieee-802-11-radiotap
integrity        : verified
protocol source  : saved_capture
live tshark -i   : absent from code
leftover analysis processes: none
```

Legacy Phase 6 PCAPs remain readable without sidecar migration. Invalid IDs, missing captures, traversal attempts, and symlinks are refused without modifying files or network state.

## Development Method

```text
stable main
  -> one bounded feature
  -> backend contract
  -> implementation
  -> CLI/JSON validation
  -> real hardware validation
  -> QML integration
  -> regression
  -> stabilization
  -> documentation
  -> checkpoint
  -> next phase
```

See [`docs/BUILD_AND_STABILIZATION_METHOD.md`](docs/BUILD_AND_STABILIZATION_METHOD.md).

## Workstation Expansion

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

- Phase 7 — CAPTURES: **Accepted / checkpointed**
- Phase 8 — NETWORK: **Next**
- Phase 9 — SURVEY: Planned
- Phase 10 — LAB: Planned
- Phase 11 — hardening / packaging / portability: Deferred

Phase 8 introduces the complete workstation network topology and explicit roles:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

with a dedicated LAB PATH view showing source interface/address, subnet, gateway, route ownership, primary internet interface, and isolation/protection state.

See [`ROADMAP.md`](ROADMAP.md) and [`docs/WORKSTATION_EXPANSION_PLAN.md`](docs/WORKSTATION_EXPANSION_PLAN.md).

## Repository Layout

```text
wifilab/
├── README.md
├── ROADMAP.md
├── bin/
├── lib/
├── libexec/
├── polkit/
├── ui/
├── integration/
├── packaging/
├── scripts/
└── docs/
```

## Responsible Use

WiFiLab is intended for diagnostics, learning, adapter management, wireless experimentation, and security testing on systems and networks the operator owns or is explicitly authorized to test. Later active security workflows remain separate phases with their own safety and scope contracts.
