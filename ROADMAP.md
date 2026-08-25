# WiFiLab Roadmap

WiFiLab is being developed as a safe Linux wireless-adapter controller for Arch Linux, with a CLI/core backend and a Quickshell floating-panel frontend.

## Phase 0 — Hardware Validation

Status: **Complete**

Validated:
- dynamic adapter/PHY/driver mapping
- RTL8822BU monitor capability
- legal `IN` regulatory domain
- managed → monitor → managed lifecycle
- passive 802.11 reception
- NetworkManager restore
- system Wi-Fi isolation

## Phase 1 — Read-Only Discovery

Status: **Complete**

Implemented:
- sysfs wireless enumeration
- PHY, driver, bus, VID:PID, human-readable device identity
- NetworkManager state and connection detection
- monitor capability and regulatory reporting
- human-readable CLI output
- machine-readable JSON
- system-vs-lab role inference
- symlink-safe launcher resolution

Important design conclusion: interface names, PHY names, and MAC addresses are runtime properties, not stable physical identity keys.

## Phase 2 — Safe State Controller

Status: **Validation in progress**

Implemented:
- `wifilab monitor <iface>`
- `wifilab managed <iface>`
- `wifilab restore <iface>`
- `wifilab channel <iface> <channel>`
- active-system-interface refusal
- live-wireless-interface validation
- monitor-capability validation
- per-interface NetworkManager release/restore
- post-transition validation
- rollback helper
- deterministic development-only rollback fault injection

Validated:
- active system Wi-Fi mutation refusal
- idle lab adapter managed → monitor
- target-only NetworkManager release
- primary connectivity preserved
- monitor → managed restore
- NetworkManager ownership restored
- regulatory domain preserved

Remaining:
- deterministic rollback fault-injection test
- channel-command validation

## Phase 3 — CLI Hardening

Planned:
- stable adapter selectors beyond raw runtime interface names
- clearer error/status codes
- structured operation output for desktop integration
- help/completion improvements

## Phase 4 — Quickshell Integration

- stable backend JSON/IPC contract
- adapter selection and state refresh
- privileged-action boundary
- error/result reporting

## Phase 5 — Quickshell Floating Panel

Planned controls:
- adapter selector
- driver / PHY / bus identity
- current mode
- connected/system-interface warning
- managed / monitor / restore controls
- channel selector
- regulatory status
- diagnostics

## Phase 6 — Capture / Lab Integrations

Only after core state transitions are stable:
- tcpdump / tshark integration
- Wireshark launch helpers
- optional aircrack-ng integration
- capture-file management
- channel hopping

## Phase 7 — Packaging and Documentation

- install/uninstall path
- Arch packaging direction
- shell completion
- troubleshooting and validation docs
- rollback documentation
