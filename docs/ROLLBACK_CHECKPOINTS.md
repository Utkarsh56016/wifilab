# WiFiLab Rollback Checkpoints

This document records known-good engineering checkpoints that can be used to recover from regressions while WiFiLab continues to evolve.

## Phase 6 Capture + UI Baseline

Status: **Validated rollback checkpoint**

Date: **2026-08-26**

Canonical commit:

```text
ac1af9f4c970d02d906a5625619a75f72a1faeec
feat: add bounded capture controls to traffic UI
```

Pinned Git branch:

```text
checkpoint/phase6-capture-ui-validated-2026-08-26
```

### Validated state

The checkpoint includes the following known-good behavior:

- persistent physical adapter selection survives USB re-enumeration and reboot
- TP-Link RTL8822BU lab adapter resolves dynamically instead of relying on a fixed `wlanX` or `phyX`
- managed -> monitor -> managed lifecycle remains functional
- channel control is regulatory-aware and validated through the kernel
- protected/default-route system Wi-Fi is not mutated
- `dumpcap` capture runs as the normal desktop user through the host Wireshark permission model
- Quickshell never runs packet capture as root
- bounded PCAPNG capture is available only for the selected non-protected lab adapter in monitor mode
- capture duration and file size are bounded
- capture files are private user-owned files under the XDG data path
- TRAFFIC UI exposes capture readiness and bounded capture control
- capture output was validated as IEEE 802.11 + radiotap PCAPNG
- final restore returns the lab adapter to managed mode
- primary default route remains on the system Wi-Fi interface

### Observed validation examples

Runtime interface re-enumeration observed across the project includes multiple names such as `wlan17` and `wlan2`. The checkpoint intentionally treats those names as runtime state, not physical identity.

Validated captures included:

```text
621940 bytes / 2875 packets / ~4.95 s
38488 bytes / 228 packets / ~10.17 s
820 bytes / 4 packets / ~3.49 s
```

The small capture was confirmed to be a valid PCAPNG, not corruption.

### Rollback use

This checkpoint is for code/configuration regression recovery. It does not replace normal inspection of the workstation's live network state before switching commits.

Inspect first:

```bash
git status --short
git rev-parse --short HEAD
wifilab status --json
ip route show default
```

To compare current development against the checkpoint:

```bash
git diff checkpoint/phase6-capture-ui-validated-2026-08-26..main
```

To temporarily inspect the checkpoint without moving the working branch:

```bash
git switch --detach checkpoint/phase6-capture-ui-validated-2026-08-26
```

Return to development with:

```bash
git switch main
```

Do not hard-reset a dirty working tree. Preserve or commit local work before any branch movement.

### System-level rollback for capture authorization

Wireshark capture authorization is separate from the Git checkpoint. If capture-group authorization itself ever needs to be reverted:

```bash
sudo gpasswd -d "$USER" wireshark
```

A fresh login session is required for supplementary-group changes to take effect.

Do not manually broaden `/usr/bin/dumpcap` permissions or file capabilities as a rollback mechanism.
