# WiFiLab Architecture

## Design Goal

WiFiLab must provide safe wireless-adapter management without coupling privileged networking logic to the desktop UI.

## Architecture

```text
Quickshell Floating Panel
        |
        | stable command / IPC contract
        v
WiFiLab CLI / Controller
        |
        +-- discovery
        +-- validation
        +-- state transitions
        +-- rollback
        +-- diagnostics
        |
        v
Linux networking interfaces
        |
        +-- nl80211 / iw
        +-- NetworkManager / nmcli
        +-- iproute2
        +-- sysfs / udev
        +-- cfg80211 / mac80211
```

## Core Principle

The Quickshell layer is presentation only.

It must not contain the authoritative logic for:
- choosing adapters
- deciding whether an interface is safe to modify
- switching interface modes
- coordinating NetworkManager
- selecting legal channels
- rollback after partial failure

The backend must remain usable from a TTY or SSH session even when the graphical shell is unavailable.

## Adapter Identity

WiFiLab must not identify adapters by interface name alone.

Runtime interface names may change after reboot, hotplug, or USB re-enumeration.

The discovery layer should correlate:

```text
network interface
    ↕
wireless PHY
    ↕
kernel driver
    ↕
sysfs device
    ↕
USB/PCI vendor + product identity
```

## State Model

Initial state model:

```text
DISCOVERED
    |
    +--> MANAGED
    |       |
    |       +--> MONITOR
    |                 |
    |                 +--> MANAGED
    |
    +--> ERROR
            |
            +--> RESTORE
```

The controller must always know:
- selected adapter
- current mode
- link state
- NetworkManager ownership
- whether the interface is carrying an active connection
- current PHY/channel
- regulatory state

## Privilege Boundary

Read-only discovery should run without elevated privileges whenever possible.

Operations that modify network state may require privilege, including:
- changing interface type
- changing link state
- changing channel
- some capture operations

Privilege escalation should be narrow and explicit. The Quickshell process itself should not run as root.

## Safety Requirements

1. Never hardcode `wlan4`, `wlan1`, or a PHY number.
2. Detect active connectivity before destructive state changes.
3. Require additional confirmation before modifying an actively connected interface.
4. Do not alter the regulatory domain to bypass regional restrictions.
5. Validate each state transition after execution.
6. Roll back partial transitions when possible.
7. Preserve the user's primary network path unless explicitly selected.
8. Keep diagnostics separate from mutation.

## Quickshell UI Direction

The final UI is a floating panel designed for the active niri + Dank Material Shell desktop.

The panel should expose:
- wireless-adapter selector
- vendor/model identity
- driver
- PHY
- current interface mode
- connection state
- current channel
- regulatory state
- managed/monitor controls
- diagnostics
- restore action

The visual frontend consumes backend state; it does not infer state independently.
