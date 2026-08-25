# WiFiLab

WiFiLab is a Linux wireless-adapter control utility focused on safe adapter discovery, mode management, diagnostics, and a native Quickshell floating-panel UI for Arch-based systems.

The project is being built as a small systems utility rather than a collection of shell one-liners: interface discovery is dynamic, state changes are explicit, rollback paths are first-class, and the desktop UI never owns privileged networking logic.

## Project Goals

- Discover wireless adapters, PHYs, drivers, USB/PCI identity, and current mode dynamically.
- Clearly distinguish the system connectivity adapter from dedicated lab adapters.
- Safely switch supported adapters between modes such as `managed` and `monitor`.
- Coordinate with NetworkManager instead of fighting it.
- Expose regulatory, driver, channel, and link diagnostics.
- Always provide a deterministic restore path after state-changing operations.
- Provide both a CLI and a themed Quickshell floating panel.
- Later integrate passive capture and wireless-lab tooling without turning the project into an opaque pentesting script.

## Architecture

```text
                        WiFiLab
                           |
               +-----------+-----------+
               |                       |
          Quickshell UI                CLI
        floating control panel       `wifilab`
               |                       |
               +-----------+-----------+
                           |
                    WiFiLab backend
                           |
            +--------------+--------------+
            |              |              |
        discovery      state/safety   diagnostics
            |              |              |
        sysfs/iw       ip/iw/nmcli     iw/udev/journal
            |              |              |
            +--------------+--------------+
                           |
                    Linux wireless stack
                           |
                    cfg80211/mac80211
                           |
                  kernel Wi-Fi drivers
```

### Design rule

The Quickshell layer is presentation only. Adapter discovery, validation, privilege-sensitive actions, rollback, and state transitions live in the backend so WiFiLab remains usable from a TTY or SSH session even if the desktop shell is unavailable.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the evolving architecture specification.

## Current Hardware Validation Target

Development is currently being validated on an Archcraft workstation with two wireless radios:

| Role | Adapter | Bus | Driver | Current role |
|---|---|---|---|---|
| System Wi-Fi | MediaTek MT7922 | PCIe | `mt7921e` | Normal connectivity |
| Lab adapter | TP-Link `2357:0138` / Realtek RTL8822BU family | USB | `rtw88_8822bu` | Wireless-lab interface |

The TP-Link PHY currently advertises:

- `managed`
- `AP`
- `AP/VLAN`
- `monitor`
- 2.4 GHz support
- 5 GHz support

Its interface name is intentionally **not** treated as stable. USB re-enumeration can change names such as `wlan2` or `wlan4`, so WiFiLab will identify devices using live kernel/sysfs/udev information rather than hardcoded interface names.

Detailed evidence is tracked in [`docs/HARDWARE_BASELINE.md`](docs/HARDWARE_BASELINE.md).

## Safety Model

WiFiLab is being designed around a few non-negotiable rules:

1. Never assume an interface name identifies a specific adapter.
2. Detect whether an adapter is currently carrying system connectivity before mutating it.
3. Avoid touching the primary Wi-Fi adapter when a dedicated lab adapter is available.
4. Coordinate with NetworkManager before changing interface type.
5. Respect the kernel regulatory domain; do not use the tool to bypass regional RF restrictions.
6. Validate each state transition after applying it.
7. Provide and test a rollback path for every mutating operation.
8. Keep privileged operations narrow and auditable.

## Planned User Experience

The final desktop workflow is intended to feel native to a customized Arch desktop rather than like a generic terminal menu.

```text
+------------------------------------------------+
| WiFiLab                                        |
+------------------------------------------------+
| Adapter                                        |
| TP-Link RTL8822BU                              |
| USB 2357:0138  |  rtw88_8822bu  |  phy4       |
|                                                |
| State                                          |
| Mode: managed          NetworkManager: managed |
| Channel: --            Regulatory: IN          |
|                                                |
| [ Managed ]   [ Monitor ]   [ Restore ]        |
|                                                |
| Channel / diagnostics / capture controls       |
+------------------------------------------------+
```

The Quickshell panel will sit on top of the same backend exposed by the `wifilab` CLI.

## Development Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Hardware and driver validation | **In progress** |
| 1 | Backend architecture and command contract | Planned |
| 2 | Read-only adapter discovery | Planned |
| 3 | Safe mode/state controller | Planned |
| 4 | CLI | Planned |
| 5 | Quickshell/backend integration | Planned |
| 6 | Floating Quickshell panel | Planned |
| 7 | Diagnostics and capture integrations | Planned |
| 8 | Packaging, validation, and documentation | Planned |

See [`ROADMAP.md`](ROADMAP.md) for the detailed development sequence.

## Phase 0: Current Validation

Completed:

- TP-Link USB device detected as `2357:0138`.
- Native kernel driver `rtw88_8822bu` binds successfully.
- Dedicated PHY and wireless interface are created.
- `monitor` mode is advertised by the PHY.
- 2.4 GHz and 5 GHz channel capabilities are visible.
- Primary MediaTek Wi-Fi remains isolated from the lab adapter.
- `wireless-regdb` is installed.

Remaining before backend implementation:

- Validate the correct regulatory domain.
- Perform a controlled `managed -> monitor` transition.
- Confirm passive 802.11 frame reception.
- Restore `monitor -> managed`.
- Restore NetworkManager ownership.
- Confirm primary system connectivity remains unaffected.
- Record any repeatable USB/driver instability.

The active validation checklist is tracked in GitHub Issue #1.

## Repository Layout

```text
wifilab/
├── README.md
├── ROADMAP.md
└── docs/
    ├── ARCHITECTURE.md
    └── HARDWARE_BASELINE.md
```

Source directories will be added only after the Phase 0 state transitions are manually validated. This keeps the implementation based on observed behavior rather than assumptions.

## Platform Focus

Initial target environment:

- Arch Linux / Archcraft
- systemd
- NetworkManager
- `iw` / nl80211
- cfg80211 / mac80211 drivers
- Wayland
- niri
- Quickshell / Dank Material Shell-style desktop integration

The backend should remain sufficiently generic that other modern Linux distributions can be supported later without coupling core logic to the UI.

## Project Status

WiFiLab is currently an early engineering project in **Phase 0: hardware validation**. No production mode-switching implementation has been committed yet.

The immediate objective is to prove the complete adapter lifecycle manually:

```text
managed
   |
NetworkManager release
   |
monitor
   |
passive capture validation
   |
managed
   |
NetworkManager restore
```

Only after that path is reproducible will it be encoded into the backend.

## Responsible Use

WiFiLab is intended for wireless experimentation, diagnostics, learning, and security testing on networks and equipment the operator owns or is explicitly authorized to test.
