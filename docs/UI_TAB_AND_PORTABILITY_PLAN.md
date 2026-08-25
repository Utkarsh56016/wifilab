# WiFiLab UI Tab and Portability Plan

## Product direction

WiFiLab is evolving from a workstation-specific wireless control panel into a portable Linux wireless-lab application with a Quickshell frontend and a backend that remains usable independently from the UI.

The packaging target should not be described as "any Linux" until the backend no longer assumes one network-management stack. The correct direction is:

> Any supported Linux host that satisfies WiFiLab's declared backend, privilege, wireless, and Quickshell compatibility requirements.

The package should probe capabilities at runtime and degrade safely instead of assuming Arch Linux, niri, NetworkManager, or Wireshark are present.

## Proposed primary navigation

Keep the primary navigation small. Five top-level tabs are enough for the packaged application:

```text
CONTROL | TRAFFIC | CAPTURES | SURVEY | SYSTEM
```

Optional future audit modules should not expand the main navigation until their safety model and backend contracts are complete.

---

## 1. CONTROL

Purpose: authoritative adapter selection and radio-state control.

Keep the current functionality here:

- physical adapter selector
- selected device identity
- protected system-adapter state
- driver / PHY / runtime interface
- managed / monitor mode
- current channel and band
- regulatory state
- NetworkManager ownership
- restore action
- guarded privileged mutations
- recent action result

Future additions:

- adapter capability summary
- current capture readiness indicator
- explicit reason when a control is unavailable
- safe per-adapter aliases such as `Lab Adapter 1`

CONTROL remains the only normal place where radio mutation is initiated.

---

## 2. TRAFFIC

Purpose: live, low-cost telemetry for the selected adapter.

Current baseline:

- RX/TX byte rate
- RX/TX packet rate
- live graph
- selected interface/mode context
- bounded capture quick action

Direction:

- keep the live graph based on sysfs counters
- remove periodic live `tshark` spawning as the long-term protocol source
- show protocol mix from the latest saved bounded capture instead
- show capture activity / last capture result
- show drops and capture health where useful

TRAFFIC should remain lightweight enough to leave open continuously.

---

## 3. CAPTURES

Purpose: saved PCAP session management and offline analysis entry point.

This should be the next major tab.

Initial scope:

- list WiFiLab-created `.pcapng` files
- timestamp
- interface recorded in the file
- capture duration
- packet count
- file size
- encapsulation
- latest-capture marker
- protocol summary derived using `tshark -r`
- open selected capture in Wireshark when a compatible GUI viewer is installed
- reveal/open capture directory
- clear viewer-unavailable state when Wireshark GUI is absent

Later scope:

- rename/label a capture
- operator notes
- SHA256 display for evidence handling
- export/copy path
- explicit delete with confirmation
- storage retention policy

Safety:

- analysis is file-based and unprivileged
- CAPTURES does not mutate radio state
- opening a file never starts a new capture
- deletion must never be implicit

---

## 4. SURVEY

Purpose: passive view of the local wireless environment.

Phase A should work only from frames already observed on the current tuned channel.

Possible fields:

- observed BSSID
- SSID when broadcast in management frames
- channel/frequency
- signal/RSSI when radiotap data provides it
- beacon/probe counts
- security capabilities inferred from beacon/probe-response information
- vendor OUI display where available
- first-seen / last-seen timestamps within a capture

Important limitation:

Without channel hopping, SURVEY describes only the channel currently monitored. The UI must state this clearly and never imply a complete spectrum scan.

Future controlled extension:

- user-requested passive multi-channel survey session
- bounded channel dwell schedule
- regulatory-aware channel list
- explicit start/stop lifecycle

Channel hopping remains deferred until its safety and connectivity model is designed and validated.

---

## 5. SYSTEM

Purpose: portability, diagnostics, dependency health, and safety transparency.

Suggested sections inside one tab rather than creating many extra top-level tabs.

### Hardware

- wireless devices
- bus identity
- driver
- supported interface modes
- supported bands
- current PHY mapping
- monitor support

### Safety

- protected interfaces
- IPv4/IPv6 default-route owner
- current selected physical identity
- privilege helper status
- capture permission state
- regulatory domain

### Dependencies

- `iw`
- `ip`
- `udevadm`
- network-management backend
- `pkexec` / polkit
- `dumpcap`
- `tshark`
- Wireshark GUI viewer
- Quickshell version/capabilities

### Diagnostics

- WiFiLab doctor output
- recent backend errors
- current backend mode
- selected adapter resolution trace
- package/version information

### Integrations

- Wireshark viewer
- optional future Aircrack-ng tooling
- optional future export/report tooling

SYSTEM should explain why a feature is unavailable instead of simply hiding it.

---

## Optional future AUDIT module

Do not add this to the default tab bar yet.

If WiFiLab later gains authorized assessment workflows, use a separate backend module with its own explicit safety contract. Possible future areas include:

- capture inspection for authentication handshakes already present in saved files
- authorized lab workflow status
- optional external-tool integration

No injection, deauthentication, automated offensive workflow, or channel-hopping feature should bypass the normal physical-adapter selection and safety boundary.

---

# Portable Linux architecture

## Current portability blockers

The present implementation still assumes several workstation-specific components:

- NetworkManager / `nmcli`
- polkit / `pkexec`
- Linux `iw` / nl80211 wireless stack
- udev/sysfs
- Quickshell frontend
- optional niri-specific window integration
- Arch-specific installation expectations

Therefore packaging should advertise supported host profiles rather than claiming universal Linux support immediately.

## Required abstraction boundaries

### 1. Network management adapter

Create a backend contract such as:

```text
network_backend
├── state(iface)
├── active_connection(iface)
├── release(iface)
└── restore(iface)
```

Initial provider:

```text
NetworkManager / nmcli
```

Possible later providers:

```text
iwd
systemd-networkd
```

Radio safety rules stay above the provider implementation.

### 2. Privilege adapter

Keep mutations behind an allowlisted helper.

Preferred host contract:

```text
polkit + pkexec
```

If a supported distribution uses a different integration path, it must preserve the same narrow allowlist and caller validation. Never solve portability by running the whole application as root.

### 3. Capture adapter

```text
capture_backend
├── capability/status
├── bounded start
├── bounded stop/status
├── file metadata
└── offline protocol analysis
```

Initial provider:

```text
dumpcap + tshark
```

The UI consumes this contract and does not depend directly on Wireshark command syntax.

### 4. Desktop integration adapter

Quickshell should be the supported frontend runtime, but compositor-specific behavior must be optional.

```text
Quickshell UI
├── generic Wayland behavior
└── optional compositor integration
    └── niri rules
```

The package must not require Dank Material Shell. DMS theming should be an optional theme source with a built-in fallback palette.

### 5. Dependency/capability manifest

At startup, WiFiLab should generate one machine-readable capability object describing:

- wireless backend available
- network-management provider
- mutation helper available
- capture backend available
- capture permission active
- viewer available
- Quickshell compatible
- compositor integration detected

The UI should render features from this contract instead of assuming packages exist.

---

# Packaging direction

Recommended order:

1. keep the current repository as the canonical source tree
2. define supported host capability contract
3. remove Arch-only assumptions from runtime code
4. make niri/DMS integration optional
5. complete `SYSTEM` diagnostics for compatibility reporting
6. package Arch first because it is the validated development host
7. add generic installer/uninstaller using XDG paths and system polkit locations
8. add Debian-family and RPM-family packaging only after the runtime dependency abstraction is stable

Avoid Flatpak/AppImage as the first portability target. WiFiLab intentionally interacts with host wireless devices, polkit, dumpcap permissions, sysfs, udev, and network management; native host integration is the cleaner initial packaging model.

---

# Recommended implementation order

```text
Current validated checkpoint
        |
        v
CAPTURES tab + offline metadata/protocol analysis
        |
        v
SYSTEM tab + capability manifest
        |
        v
SURVEY tab from saved/current-channel passive data
        |
        v
network-management provider abstraction
        |
        v
portable packaging profiles
        |
        v
optional advanced audit modules
```

This sequence keeps each new UI surface backed by a stable, testable CLI/JSON contract and avoids turning Quickshell into the authoritative networking layer.
