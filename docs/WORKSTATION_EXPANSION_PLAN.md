# WiFiLab Workstation Expansion Plan

## Scope

This plan is for the current Archcraft workstation build.

Portability and cross-distribution packaging are intentionally deferred. The immediate goal is to expand WiFiLab into a stable wireless-lab, pentesting-support, adapter-management, capture-analysis, and network-context utility on the validated workstation.

## Stable Baseline

Already stabilized:

```text
CONTROL
TRAFFIC
```

Known-good functional checkpoint:

```text
commit: ac1af9f4c970d02d906a5625619a75f72a1faeec
branch: checkpoint/phase6-capture-ui-validated-2026-08-26
```

Current validated capabilities include:

- persistent physical adapter identity
- protected primary Wi-Fi/default-route guard
- managed/monitor lifecycle
- legal channel control
- NetworkManager coordination
- non-root bounded dumpcap capture
- PCAPNG output with radiotap
- capture UI control
- reboot/re-enumeration recovery
- restore to managed mode without disturbing the primary network path

## Final Workstation Navigation Target

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

SYSTEM/DOCTOR remains a utility drawer/panel rather than a permanent primary tab unless its scope later justifies promotion.

---

## CONTROL — Radio and Adapter Command Center

Status: **Stable**

Purpose:

> Control the selected physical wireless lab adapter safely.

Primary instruments:

- adapter selector
- device/vendor identity
- driver
- runtime interface/PHY
- MAN/MON state
- NetworkManager state
- link state
- band/channel/frequency
- regulatory state
- monitor capability
- protected/default-route guard
- Restore
- activity/error history

Policy:

- Do not turn CONTROL into a general pentesting-tool launcher.
- New feature-specific controls belong in their own tabs.

---

## TRAFFIC — Live Adapter Telemetry

Status: **Stable baseline; protocol path to be simplified later**

Purpose:

> Show what the selected lab adapter is doing right now.

Primary instruments:

- RX bytes/sec
- TX bytes/sec
- RX packets/sec
- TX packets/sec
- live traffic graph
- current interface/PHY
- current mode/channel/frequency
- capture ready/busy/blocked state
- bounded capture action
- saved-capture count
- drop/error counters where reliable data exists

Planned cleanup:

- stop using periodic live `tshark` capture as the long-term protocol-display mechanism
- derive protocol/frame summaries from saved PCAPNG instead

---

## CAPTURES — PCAP Workspace

Expansion priority: **1 — next feature**

Purpose:

> Turn saved bounded captures into a deterministic analysis workspace.

Planned view:

```text
CAPTURE SESSIONS
--------------------------------------------------------
Time        Interface   Ch   Packets   Size    Duration
02:56:55    wlan2       11   228       38KB    10.17s
02:56:37    wlan2       11   4         820B     3.49s
...

Selected capture
--------------------------------------------------------
Metadata                  Frame / protocol summary
Packets                   Data
Duration                  Beacon
Size                      Probe Request
Interface                 Probe Response
Channel                   IPv4 / IPv6 / ARP / etc.
Encapsulation
Hash

[ Open Wireshark ] [ Details ] [ Reveal File ]
```

Backend/instruments:

- richer saved-capture inventory JSON
- latest-capture JSON
- timestamp
- interface used at capture time
- channel/frequency metadata where available
- packet count
- duration
- size
- encapsulation
- SHA256/hash metadata
- offline `tshark -r` frame/protocol breakdown
- optional Wireshark GUI availability
- safe open/reveal action

Explicit non-goals for first iteration:

- capture deletion
- rename/tagging
- long-running background capture daemon
- attack workflows

Acceptance gate:

- all metadata comes from the selected file, not a new live capture
- TRAFFIC no longer needs periodic live tshark sampling for protocol visualization
- opening/analyzing a saved file does not mutate radio or networking state

---

## NETWORK — Workstation Networking Device Manager

Expansion priority: **2**

Purpose:

> Show and manage the workstation network topology while making the lab path and protected production path explicit.

This phase introduces a backend interface-role model:

```text
PRIMARY
LAB
AUXILIARY
VIRTUAL
TUNNEL
```

Expected workstation examples:

```text
wlan0     PRIMARY
wlan2     LAB
eno1      AUXILIARY
virbr0    VIRTUAL
docker0   VIRTUAL
tun*/wg*  TUNNEL
```

Planned view:

```text
NETWORK DEVICES
----------------------------------------------------------
wlan0    Wi-Fi      MAN     CONNECTED      PRIMARY
wlan2    Wi-Fi      MAN     DISCONNECTED   LAB
eno1     Ethernet   --      DOWN           AUXILIARY
virbr0   Bridge     --      UP             VIRTUAL
docker0  Bridge     --      UP             VIRTUAL

Selected interface
----------------------------------------------------------
IDENTITY             NETWORK STATE
iface / phy          mode
kind                 link state
driver               NM state
MAC                  MTU

ADDRESSING           ROUTING
IPv4                 default-route owner
IPv6                 routes
gateway              metric
DNS                  protected state

LAB PATH
source interface
source address
subnet
gateway
default route yes/no
primary internet interface
isolation/protection state
```

Planned instruments:

- physical and virtual interface inventory
- interface type/kind
- driver/PHY for wireless devices
- MAN/MON state where applicable
- link state
- NetworkManager state
- IPv4/IPv6
- subnet/prefix
- gateway
- DNS context
- MTU
- MAC
- RX/TX counters
- default-route ownership
- route metric
- role
- protected state
- bridge/master membership
- tunnel/VPN context
- Docker/libvirt relationships where discoverable without invasive coupling

First controlled actions:

- assign/set LAB role for the selected physical wireless lab adapter
- inspect PRIMARY path
- MAN/MON/Restore through existing backend guards
- optional per-interface disconnect/release only after separate validation

Safety rule:

> NETWORK may expose the whole topology, but PRIMARY remains heavily protected and cannot become a convenient bypass around CONTROL safety.

---

## SURVEY — Passive Wireless Environment

Expansion priority: **3**

Purpose:

> Build passive situational awareness from monitor-mode observations.

Initial scope is **current-channel passive survey only**.

Planned view:

```text
PASSIVE SURVEY                       CH 11 / 2462 MHz
----------------------------------------------------------
BSSID               SSID       Frames    Last seen
xx:xx:xx:xx:xx:xx   LAB-AP     154       now
...

FRAME TYPES                     CHANNEL ACTIVITY
Beacon                          packet rate
Probe Request                   observed devices
Probe Response                  signal summary where valid
Data
Control
```

Planned instruments where the capture data supports them:

- BSSID
- SSID/hidden SSID state
- current channel
- frame count
- first seen
- last seen
- beacon count
- probe requests/responses
- data/control/management frame mix
- advertised security information
- OUI/vendor summary
- RSSI/signal values when reliable radiotap metadata is present
- passive channel activity summary

Explicit non-goals for first iteration:

- channel hopping
- deauthentication
- injection
- association attacks
- active scanning that disrupts the selected monitor workflow

---

## LAB — Controlled Pentesting Workspace

Expansion priority: **4**

Purpose:

> Coordinate lab-security workflows only after WiFiLab knows the selected LAB interface, protected PRIMARY path, and validated target/scope context.

Planned top context:

```text
LAB WORKSPACE
----------------------------------------------------------
Lab interface       wlan2
Mode                managed/monitor
Lab subnet          ...
Primary interface   wlan0 [PROTECTED]
Scope state         validated / incomplete
```

Planned modules:

### Discovery

- neighbour/ARP table
- gateway
- known lab hosts
- local subnet context
- reachable-host observations
- DNS context

### Services

- selected host
- observed/discovered services
- saved observations
- later optional integration with external discovery/scanning tools

### Wireless

- selected BSSID/AP
- channel
- observed security metadata
- capture references
- survey references

### Session

- notes
- commands/actions executed through WiFiLab
- timestamps
- capture references
- target/scope context

Design rule:

WiFiLab should orchestrate and constrain external lab tools rather than reimplementing every security utility.

Future integrations may include tools such as `tshark`, `nmap`, Wireshark, and separately reviewed aircrack-ng workflows, but only through validated backend contracts and LAB-role/scope checks.

Deferred advanced wireless operations:

- channel hopping
- handshake-oriented workflows
- frame injection
- deauthentication
- other active wireless attack operations

These require their own design and safety phase and are not implied by creation of the LAB tab.

---

## SYSTEM / DOCTOR Utility Drawer

Status: **Existing capability, to expand incrementally**

Keep this out of the primary navigation for now.

Planned information:

- backend status
- selected physical identity
- helper/polkit availability
- capture permission
- `dumpcap`/`tshark`/viewer availability
- regulatory state
- protected/default-route guard status
- dependency checks
- backend errors
- data/capture paths

This is diagnostics and capability state, not a mutation workspace.

---

## Expansion Order

```text
CURRENT STABLE STATE
CONTROL + TRAFFIC + bounded capture
        |
        v
Phase 7  CAPTURES
        |
        v
stabilize + checkpoint
        |
        v
Phase 8  NETWORK + interface roles/LAB path
        |
        v
stabilize + checkpoint
        |
        v
Phase 9  SURVEY
        |
        v
stabilize + checkpoint
        |
        v
Phase 10 LAB
        |
        v
stabilize + checkpoint
```

No feature from a later phase is pulled forward unless it is required as a dependency and is explicitly added to the current phase scope before implementation begins.

## UI Expansion Policy

The window remains 1040×720 during this workstation expansion unless a dedicated shell change is required and separately validated.

The header navigation will expand incrementally to support:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

The active instrument area remains one tab at a time. Existing CONTROL and TRAFFIC layouts are treated as stabilized surfaces and should only receive localized changes required by validated dependencies.

## Definition of Done for Every New Tab

A tab is considered stable only when:

- its backend contract is validated independently of the UI
- its primary success path works on the real workstation
- meaningful refusal/error paths behave safely
- primary `wlan0` connectivity remains protected
- runtime lab adapter re-resolution remains correct
- UI state agrees with backend JSON
- CONTROL and TRAFFIC regression checks pass
- no unexpected background process churn is introduced
- final documentation is updated
- a rollback checkpoint branch is created

See `docs/BUILD_AND_STABILIZATION_METHOD.md` for the required engineering cycle.
