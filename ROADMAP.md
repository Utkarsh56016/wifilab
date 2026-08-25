# WiFiLab Roadmap

WiFiLab is a safe Linux wireless-adapter controller with a CLI/core backend, a narrow privileged mutation boundary, and a Quickshell frontend. Arch Linux + niri + NetworkManager remains the validated development host, while the product direction is portable support for declared Linux host profiles rather than hardcoded workstation assumptions.

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

Design conclusion: interface names, PHY names and MAC addresses are runtime properties, not stable physical identity keys.

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

## Phase 3 — Persistent Selection and CLI Hardening

Status: **Complete**

Implemented and validated:
- persistent physical adapter identity based on bus/device/driver/path metadata
- argument-free control of the selected lab adapter
- runtime re-resolution after USB re-enumeration
- stale `wlanX` hints treated as non-authoritative
- structured JSON endpoints for UI/agent consumers
- clear non-zero error paths for malformed and unsupported operations

Validated across multiple runtime re-enumerations and reboot, including runtime names such as `wlan13`, `wlan15`, `wlan17`, and `wlan2`.

## Phase 4 — Quickshell Integration

Status: **Complete**

Implemented and validated:
- Quickshell 0.3.1 integration under Wayland/niri
- centered floating niri window rule
- DMS-aligned translucent/glass styling
- CONTROL and TRAFFIC views
- adapter selector with protected-system-device state
- selected adapter state reconstruction from backend JSON
- privileged mutation boundary through `pkexec` and root-owned helper
- authorization cancellation with zero radio mutation
- activity/error feedback
- close-without-restore state persistence

## Phase 5 — Floating Panel Reliability and Telemetry

Status: **Complete**

Implemented and validated:
- live RX/TX byte and packet telemetry from sysfs
- graceful telemetry degradation when selected hardware is absent
- regulatory-aware channel controls
- automatic UI recovery after hot unplug/replug
- physical identity retained while stale runtime netdev state is discarded
- active monitor-mode unplug/replug recovery
- protected `wlan0` connectivity and default-route isolation throughout tests
- malformed privileged requests rejected before mutation
- disabled channel request rejected by kernel while prior valid channel remains intact

A proposed repeated 10-cycle soak was intentionally waived after the acceptance matrix had already covered the meaningful state, authorization, hotplug, identity, and regulatory failure modes.

## Phase 6 — Passive Capture and Lab Integrations

Status: **In progress — bounded capture baseline validated**

Implemented and validated:
- `wireshark-cli` / `dumpcap` / `tshark` capability discovery
- normal-user capture through the host `wireshark` group and package-managed `dumpcap` capabilities
- no root `tshark` / `dumpcap` execution
- capture permission state exposed through JSON
- bounded PCAPNG capture on the selected physical lab adapter
- capture requires monitor mode
- protected/default-route wireless interfaces are refused
- runtime physical-adapter re-resolution before capture
- capture duration and file-size bounds
- XDG capture data directory
- capture inventory JSON
- TRAFFIC UI capture readiness and bounded-capture control
- IEEE 802.11 + radiotap output validated with real captured frames
- capture/restore workflow validated while the system default route remained on `wlan0`
- capture functionality survived reboot and adapter re-enumeration from `wlan17` to `wlan2`

Known-good rollback checkpoint:

```text
commit: ac1af9f4c970d02d906a5625619a75f72a1faeec
branch: checkpoint/phase6-capture-ui-validated-2026-08-26
```

See `docs/ROLLBACK_CHECKPOINTS.md`.

Next implementation scope:
- CAPTURES tab
- file metadata from saved PCAPNG
- latest-capture JSON
- offline protocol mix using `tshark -r`
- optional Wireshark GUI launch helper
- viewer-unavailable state when no GUI viewer is installed
- explicit capture/session lifecycle metadata
- remove periodic live `tshark` sampling as the long-term protocol-display path

Deferred until separately designed and validated:
- channel hopping
- aircrack-ng workflows
- frame injection

WiFiLab must never acquire broader privilege merely to make the UI graph, protocol panel, or capture viewer work.

## Phase 7 — Product Tabs and Portable Host Capability Model

Status: **Planned**

Primary packaged UI direction:

```text
CONTROL | TRAFFIC | CAPTURES | SURVEY | SYSTEM
```

Planned work:
- CAPTURES tab for saved PCAP analysis and viewer integration
- SURVEY tab for passive current-channel wireless observations
- SYSTEM tab for hardware, safety, dependency, capability, and diagnostics state
- one machine-readable host capability manifest
- optional DMS theming with a built-in fallback palette
- optional compositor integration instead of mandatory niri coupling
- network-management provider abstraction instead of hardcoded NetworkManager assumptions
- capture backend abstraction around dumpcap/tshark
- clear feature degradation when optional tools are absent

See `docs/UI_TAB_AND_PORTABILITY_PLAN.md`.

## Phase 8 — Packaging and Documentation

Status: **Planned**

Recommended order:
- Arch package first on the validated development host
- install / uninstall path
- XDG-compliant user data/config paths
- shell completion
- privilege-model documentation
- capture-permission documentation
- rollback documentation
- dependency/capability diagnostics
- generic native installer after Arch behavior is stable
- Debian-family and RPM-family packaging after backend abstraction is complete
- final architecture and operational runbooks

Portable packaging must not be achieved by running the whole application as root or by weakening capture/radio safety checks.
