# WiFiLab Roadmap

WiFiLab is a safe Linux wireless-adapter controller for Arch Linux, with a CLI/core backend, a root-owned polkit helper for allowlisted mutations, and a Quickshell floating-panel frontend.

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

Validated across multiple runtime re-enumerations, including `wlan13`, `wlan15`, and `wlan17`.

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

Status: **Next**

Planned scope:
- optional `tshark` / `dumpcap` capability discovery
- non-root passive protocol sampling using existing capture permissions only
- bounded PCAP capture sessions on the selected lab adapter
- capture metadata and file management
- Wireshark launch helper for saved captures
- UI capture state and protocol-mix integration
- explicit capture start/stop lifecycle
- safe failure behavior when capture permissions are unavailable

Deferred until separately designed and validated:
- channel hopping
- aircrack-ng workflows
- frame injection

WiFiLab must never acquire broader privilege merely to make the UI graph or protocol panel work.

## Phase 7 — Packaging and Documentation

Status: **Planned**

- install / uninstall path
- Arch packaging direction
- shell completion
- troubleshooting and validation documentation
- privilege model documentation
- capture permission documentation
- rollback documentation
- final architecture and operational runbooks
