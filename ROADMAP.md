# WiFiLab Roadmap

WiFiLab is being developed as a safe Linux wireless-adapter controller for Arch Linux, with a CLI/core backend and a Quickshell floating-panel frontend.

## Phase 0 — Hardware Validation

Status: **In progress**

Goals:
- Identify all wireless adapters dynamically.
- Map interface ↔ PHY ↔ driver ↔ USB/PCI device.
- Confirm monitor-mode capability on the lab adapter.
- Confirm legal regulatory-domain handling.
- Validate managed → monitor → managed transitions.
- Validate passive 802.11 frame reception.
- Confirm NetworkManager restore behavior.
- Record rollback steps.

Current lab adapter:
- USB ID: `2357:0138`
- Vendor: TP-Link
- Chipset family: Realtek RTL8822BU
- Kernel driver: `rtw88_8822bu`
- Current interface observed: `wlan4`
- Current PHY observed: `phy4`
- Monitor mode advertised: yes

Important: interface names are runtime values and must never be hardcoded.

## Phase 1 — Architecture

- Define adapter model and state machine.
- Define privilege boundary.
- Define stable backend output for CLI and Quickshell.
- Define error and rollback semantics.

## Phase 2 — Read-Only Discovery

- Enumerate wireless interfaces.
- Read PHY capabilities.
- Read drivers and bus identity.
- Read NetworkManager ownership and connection state.
- Read regulatory state.
- Produce machine-readable output.

## Phase 3 — Safe Mode Controller

- Managed → monitor transition.
- Monitor → managed restore.
- NetworkManager coordination.
- Connected-interface safety guard.
- Channel selection with regulatory validation.
- Failure rollback.

## Phase 4 — CLI

Command: `wifilab`

Planned capabilities:
- adapter list
- adapter info
- mode status
- monitor enable/disable
- channel selection
- diagnostics
- restore

## Phase 5 — Quickshell Integration

- Stable backend IPC/command contract.
- Floating panel lifecycle.
- Adapter selector.
- Live state display.
- Safe action controls.
- Error/result notifications.

## Phase 6 — Quickshell Floating Panel

Primary desktop UI for niri + Dank Material Shell.

Planned controls:
- adapter selector
- driver / PHY / bus identity
- current mode
- connected/system-interface warning
- managed / monitor toggle
- channel selector
- regulatory status
- diagnostic actions
- safe restore

## Phase 7 — Capture / Lab Integrations

Only after core state transitions are stable:
- tcpdump / tshark integration
- Wireshark launch helpers
- optional aircrack-ng integration
- capture-file management
- channel hopping

## Phase 8 — Packaging and Documentation

- install script or Arch package
- shell completion
- user documentation
- troubleshooting guide
- architecture documentation
- validation checklist
