# WiFiLab

WiFiLab is a Linux wireless-adapter control utility focused on safe adapter discovery, mode management, diagnostics, and a native Quickshell floating-panel UI for Arch-based systems.

The project is being built as a systems utility rather than a collection of shell one-liners: interface discovery is dynamic, state changes are explicit, rollback paths are first-class, and the desktop UI never owns privileged networking logic.

## Goals

- Discover wireless adapters, PHYs, drivers, USB/PCI identity, and current mode dynamically.
- Distinguish the adapter carrying system connectivity from idle or dedicated lab adapters.
- Safely switch supported adapters between `managed` and `monitor` modes.
- Coordinate with NetworkManager instead of globally disabling it.
- Expose regulatory, driver, channel, and link diagnostics.
- Provide deterministic rollback for every mutating action.
- Provide both a CLI and a themed Quickshell floating panel.
- Keep the backend useful from a TTY or SSH session even when the desktop shell is unavailable.

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

The Quickshell layer is presentation only. Adapter discovery, validation, privilege-sensitive actions, rollback, and state transitions belong in the backend.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Current Hardware Baseline

Development is currently validated on an Archcraft workstation with two wireless radios:

| Role | Adapter | Bus | Driver |
|---|---|---|---|
| System Wi-Fi | MediaTek MT7922 (`14c3:0616`) | PCIe | `mt7921e` |
| Lab adapter | TP-Link `2357:0138` / RTL8822BU family | USB | `rtw88_8822bu` |

Important observed behavior: interface and PHY names are not stable across re-enumeration. The same hardware has appeared under different `wlanX` and `phyX` numbers, so WiFiLab never treats interface names as physical identity.

Detailed evidence is tracked in [`docs/HARDWARE_BASELINE.md`](docs/HARDWARE_BASELINE.md).

## Phase 0 Validation Result

The manual hardware workflow is complete and validated:

```text
managed
   |
NetworkManager releases lab adapter
   |
monitor
   |
channel selection
   |
passive radiotap capture
   |
managed
   |
NetworkManager restore
```

Validated facts:

- Native `rtw88_8822bu` driver works; no out-of-tree driver is required.
- India regulatory domain (`IN`) is configured persistently through `/etc/conf.d/wireless-regdom`.
- The TP-Link adapter transitions cleanly to monitor mode.
- Passive raw 802.11 reception works through radiotap / `IEEE802_11_RADIO`.
- Test capture completed with 30 packets captured and 0 kernel drops.
- The adapter restores cleanly to managed mode.
- NetworkManager ownership restores correctly.
- The primary MediaTek Wi-Fi remains connected throughout the lab-adapter transition.

GitHub Issue #1 tracks the completed Phase 0 evidence.

## Phase 1: Read-only Discovery Backend

The first implementation is now present. Phase 1 is deliberately read-only: it inspects adapters but does not change any interface state.

Current discovery sources:

- `/sys/class/net/*/wireless` for wireless netdev enumeration
- `/sys/class/net/<iface>/device` for physical-device topology
- `/sys/class/net/<iface>/phy80211` for PHY resolution
- `/sys/class/net/<iface>/device/driver` for kernel driver identity
- `udevadm` for bus/vendor/model/path metadata
- `iw` for interface type, PHY capabilities, and regulatory domain
- `nmcli` for NetworkManager state and active connection
- `lspci` / `lsusb` for human-readable hardware identity

### CLI

From the repository root:

```bash
bash bin/wifilab list
bash bin/wifilab --json
bash bin/wifilab doctor
```

Planned installed command:

```bash
wifilab list
wifilab --json
wifilab doctor
```

Example human-readable intent:

```text
wlan0
  Role       : system
  Device     : MEDIATEK Corp. MT7922 ...
  PHY        : phy0
  Driver     : mt7921e
  Bus        : pci
  Mode       : managed
  NM state   : connected
  Connection : EACCESS-M1
  Monitor    : true|false
  Regdomain  : IN

wlan6
  Role       : lab-candidate
  Device     : TP-Link 802.11ac NIC
  PHY        : phy6
  Driver     : rtw88_8822bu
  Bus        : usb
  Device ID  : 2357:0138
  Mode       : managed
  NM state   : disconnected
  Monitor    : true
  Regdomain  : IN
```

The JSON output is the machine-readable contract intended for future Quickshell integration.

## Safety Model

WiFiLab carries these rules forward:

1. Never hardcode `wlanX` or `phyX` as physical identity.
2. Identify adapters dynamically from bus/device/driver/sysfs/udev metadata.
3. Detect whether an adapter is carrying system connectivity before mutating it.
4. Never globally kill NetworkManager for lab-mode transitions.
5. Respect the configured regulatory domain and do not bypass regional RF restrictions.
6. Validate every state transition.
7. Provide an explicit rollback path for every mutating action.
8. Keep privileged operations narrow and auditable.

## Planned Quickshell UI

```text
+------------------------------------------------+
| WiFiLab                                        |
+------------------------------------------------+
| Adapter                                        |
| TP-Link RTL8822BU                              |
| USB 2357:0138 | rtw88_8822bu | current phyX   |
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

The UI will consume the same backend contract as the CLI rather than invoking `iw`, `nmcli`, or sysfs logic directly.

## Repository Layout

```text
wifilab/
├── README.md
├── ROADMAP.md
├── bin/
│   └── wifilab
├── lib/
│   └── wifilab/
│       └── discover.sh
└── docs/
    ├── ARCHITECTURE.md
    └── HARDWARE_BASELINE.md
```

## Development Status

| Phase | Scope | Status |
|---|---|---|
| 0 | Hardware / driver / monitor validation | **Complete** |
| 1 | Dynamic read-only adapter discovery | **In progress** |
| 2 | Safe state controller | Planned |
| 3 | CLI mode-management workflow | Planned |
| 4 | Quickshell/backend contract | Planned |
| 5 | Floating Quickshell panel | Planned |
| 6 | Diagnostics and capture integrations | Planned |
| 7 | Packaging and installation | Planned |
| 8 | Final validation and documentation | Planned |

See [`ROADMAP.md`](ROADMAP.md) and GitHub Issue #2 for the active Phase 1 work.

## Platform Focus

Initial target environment:

- Arch Linux / Archcraft
- systemd
- NetworkManager
- `iw` / nl80211
- cfg80211 / mac80211
- Wayland
- niri
- Quickshell / Dank Material Shell-style desktop integration

The backend is intentionally shell-first and uses standard Linux interfaces so it can remain portable beyond the initial workstation.

## Responsible Use

WiFiLab is intended for wireless experimentation, diagnostics, learning, and security testing on networks and equipment the operator owns or is explicitly authorized to test.
