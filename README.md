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

The TP-Link PHY currently advertises `managed`, `AP`, `AP/VLAN`, and `monitor` modes, with 2.4 GHz and 5 GHz support.

The implementation does not treat interface names, PHY names, or MAC addresses as stable physical identity. USB re-enumeration has changed runtime names and MAC addresses during validation, so WiFiLab derives identity from live bus/device/driver/sysfs/udev metadata.

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

## Current CLI

```bash
wifilab doctor
wifilab list
wifilab --json
wifilab monitor <iface>
wifilab managed <iface>
wifilab restore <iface>
wifilab channel <iface> <channel>
```

Discovery is read-only. State-changing commands validate the target, refuse the active system Wi-Fi interface, and scope NetworkManager changes to only the selected interface.

## Development Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Hardware and driver validation | **Complete** |
| 1 | Dynamic read-only adapter discovery | **Complete** |
| 2 | Safe mode/state controller | **Validation in progress** |
| 3 | CLI hardening and command UX | Planned |
| 4 | Quickshell/backend integration | Planned |
| 5 | Floating Quickshell panel | Planned |
| 6 | Diagnostics and capture integrations | Planned |
| 7 | Packaging, validation, and documentation | Planned |

See [`ROADMAP.md`](ROADMAP.md) for the detailed development sequence.

## Validated State Lifecycle

The current controller has successfully completed:

```text
idle managed lab adapter
        |
per-interface NetworkManager release
        |
monitor mode
        |
validated monitor state
        |
restore
        |
managed mode + NetworkManager ownership
```

During this lifecycle the primary system Wi-Fi remained connected and the configured regulatory domain remained `IN`.

A development-only fault-injection hook is used to validate the rollback branch deterministically without relying on accidental hardware or driver failures.

## Repository Layout

```text
wifilab/
├── README.md
├── ROADMAP.md
├── bin/
│   └── wifilab
├── lib/
│   └── wifilab/
│       ├── discover.sh
│       └── state.sh
└── docs/
    ├── ARCHITECTURE.md
    └── HARDWARE_BASELINE.md
```

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

## Responsible Use

WiFiLab is intended for wireless experimentation, diagnostics, learning, and security testing on networks and equipment the operator owns or is explicitly authorized to test.
