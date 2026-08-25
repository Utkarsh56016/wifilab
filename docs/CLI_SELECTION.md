# WiFiLab Adapter Selection

WiFiLab does not persist transient interface names such as `wlan6` or PHY names such as `phy6`.

The selection layer stores a physical identity record under:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/wifilab/selected-adapter
```

The stored fields are:

- bus type
- vendor ID
- model/product ID
- kernel driver
- device path

At runtime, WiFiLab re-enumerates current wireless interfaces and resolves the selected physical device back to its current interface name.

## Commands

```bash
wifilab adapters
wifilab select
wifilab select <iface>
wifilab status
wifilab monitor
wifilab restore
wifilab channel <channel>
```

Explicit interface arguments remain supported for diagnostics and recovery:

```bash
wifilab monitor wlan6
wifilab restore wlan6
wifilab channel wlan6 11
```

## Automatic selection

`wifilab select` without an interface auto-selects only when exactly one idle USB wireless adapter is available. If there are zero or multiple candidates, WiFiLab refuses to guess and requires an explicit interface.

## Safety

Selection does not bypass state-controller safety checks. The selected adapter is resolved first, then the normal active-system-interface guard, capability checks, NetworkManager coordination, transition validation, and rollback logic are applied.
