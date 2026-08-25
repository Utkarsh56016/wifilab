# Hardware Validation Baseline

## Host Context

WiFiLab is initially being developed and validated on an Archcraft Linux workstation using NetworkManager and the Linux cfg80211/mac80211 wireless stack.

## Primary System Wi-Fi

Observed built-in adapter:
- Chipset: MediaTek MT7922
- Kernel driver: `mt7921e`
- Observed interface: `wlan1`
- Role: normal system connectivity

This interface should remain untouched during lab-adapter testing unless explicitly selected.

## Lab Wi-Fi Adapter

Observed USB adapter:
- Vendor: TP-Link
- USB ID: `2357:0138`
- Device string: `802.11ac NIC`
- Chipset family: Realtek RTL8822BU
- Kernel driver: `rtw88_8822bu`
- Driver stack: `rtw88_8822bu` → `rtw88_usb` → `rtw88_8822b` → `rtw88_core`
- Observed interface: `wlan4`
- Observed PHY: `phy4`
- Firmware: `30.20.0`

## Advertised Wireless Capabilities

The TP-Link PHY advertises:
- managed mode
- AP mode
- AP/VLAN
- monitor mode
- 2.4 GHz operation
- 5 GHz operation
- software monitor interfaces
- TX frame support
- per-VIF TX power control

## Regulatory State

Current observed state during initial validation:

```text
country 00: DFS-UNSET
```

This is the generic world regulatory domain. The next validation step is to confirm the correct local regulatory configuration before mode/channel behavior is encoded into WiFiLab.

## USB Observation

One transient USB protocol error was observed during re-enumeration:

```text
write register 0xc4 failed with -71
usb write fail, status: -71
```

The device subsequently re-enumerated successfully on the SuperSpeed USB path and loaded firmware correctly.

Classification: observation only. Not currently treated as a persistent adapter or driver failure.

## Remaining Phase 0 Gates

- [x] USB detection
- [x] driver binding
- [x] PHY discovery
- [x] monitor mode advertised
- [x] 2.4 GHz capabilities visible
- [x] 5 GHz capabilities visible
- [x] primary Wi-Fi and lab adapter isolated
- [ ] correct regulatory domain validated
- [ ] managed → monitor transition validated
- [ ] passive 802.11 frame capture validated
- [ ] monitor → managed restore validated
- [ ] NetworkManager ownership restore validated

## Important Engineering Rule

The observed values `wlan1`, `wlan4`, `phy1`, and `phy4` are runtime identifiers, not configuration constants. WiFiLab must discover these relationships dynamically.
