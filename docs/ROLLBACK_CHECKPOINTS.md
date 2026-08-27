# WiFiLab Rollback Checkpoints

This document records known-good engineering checkpoints for regression recovery while WiFiLab continues to evolve.

A checkpoint is a code/configuration recovery point, not a substitute for inspecting the workstation's live network state before switching commits.

---

## Phase 7 CAPTURES Accepted Baseline

Status: **Validated rollback checkpoint**

Date: **2026-08-27**

Canonical functional commit:

```text
17c79c134c1b66f56cc9821191e7c1fdbb533709
fix: remove anchors from protocol flow item
```

Pinned branch:

```text
checkpoint/phase7-captures-validated-2026-08-27
```

### Validated state

This checkpoint includes the accepted Phase 7 behavior:

- Phase 6 bounded non-root capture primitive remains intact
- only `capture run` initiates live packet capture
- successful captures produce `.pcapng` plus atomic JSON manifest sidecars
- manifest records capture-time interface/PHY/driver/channel/frequency/regdomain, bounds, bytes, and SHA-256
- successful PCAP is preserved if manifest generation fails
- rich inventory remains backward-compatible with Phase 6 capture fields
- legacy captures without manifests remain valid and are classified as `legacy`
- invalid sidecars are classified rather than crashing the CLI
- invalid capture filenames are ignored by inventory
- empty inventory/latest states are deterministic
- strict capture-ID validation and capture-directory confinement are enforced
- traversal, missing capture, and symlink paths are refused
- `wifilab capture latest --json` works
- `wifilab capture inspect` uses on-demand `capinfos`
- inspection exposes file type, radiotap encapsulation, packet count, size, duration, and first/last frame timestamps
- SHA-256 integrity is reported as verified/mismatch/untracked as appropriate
- `wifilab capture protocols` uses saved files through `tshark -r`
- compatibility `wifilab protocols --json` reads the latest saved capture offline
- no `tshark -i` live protocol sampling remains in backend code
- viewer status, safe open, and reveal contracts are validated
- absent GUI Wireshark returns `viewer_unavailable` cleanly
- Reveal works through the normal desktop opener
- CAPTURES Quickshell tab lists, selects, inspects, and analyzes saved captures
- CAPTURES protocol labels are offline only
- CONTROL and TRAFFIC remain visually/functionally intact
- UI remains fixed at `1040 × 720`
- no persistent `tshark`, `dumpcap`, or `capinfos` process remains after analysis
- LAB adapter remained in the intended monitor/unmanaged state during final acceptance
- PRIMARY default route remained on `wlan0`

### Final acceptance evidence

Final 2026-08-27 acceptance included:

```text
LAB interface          : wlan4
LAB PHY                : phy4
LAB driver             : rtw88_8822bu
LAB mode               : monitor
NetworkManager         : unmanaged
regdomain              : IN
PRIMARY default route  : wlan0
capture ready          : true
saved capture count    : 6
latest capture         : capture-20260827T101023Z-1934560.pcapng
latest bytes           : 8024
latest packets         : 18
latest duration        : 9.932723659 s
encapsulation          : ieee-802-11-radiotap
integrity              : verified
protocol source        : saved_capture
protocol frames        : 18 x 802.11
live tshark -i         : absent
analysis processes     : none remaining
working tree           : clean
```

### Known non-blocking item

Quickshell declares:

```text
io.github.utkarsh56016.wifilab
```

but there is not yet a matching installed `.desktop` entry. Qt/XDG Desktop Portal therefore logs a registration warning in foreground mode. This was verified as desktop-integration metadata only and had no effect on capture, radio, routing, or UI operation. Fixing it belongs to packaging/integration hardening rather than Phase 7 rollback logic.

### Rollback use

Inspect live state first:

```bash
git status --short
git rev-parse --short HEAD
wifilab status --json
ip route show default
```

Compare later development against Phase 7:

```bash
git diff checkpoint/phase7-captures-validated-2026-08-27..main
```

Inspect the checkpoint without moving a working branch permanently:

```bash
git switch --detach checkpoint/phase7-captures-validated-2026-08-27
```

Return to accepted main:

```bash
git switch main
```

Do not hard-reset a dirty tree. Preserve or commit local work before moving branches.

---

## Phase 6 Capture + UI Baseline

Status: **Validated rollback checkpoint**

Date: **2026-08-26**

Canonical commit:

```text
ac1af9f4c970d02d906a5625619a75f72a1faeec
feat: add bounded capture controls to traffic UI
```

Pinned branch:

```text
checkpoint/phase6-capture-ui-validated-2026-08-26
```

### Validated state

The Phase 6 checkpoint preserves the original stable bounded-capture baseline:

- persistent physical adapter selection across re-enumeration/reboot
- dynamic RTL8822BU LAB adapter resolution
- managed -> monitor -> managed lifecycle
- regulatory-aware channel control
- protected/default-route PRIMARY Wi-Fi isolation
- normal-user `dumpcap` through host Wireshark permissions
- unprivileged Quickshell
- monitor-mode-only bounded PCAPNG capture
- duration and size bounds
- private XDG capture storage
- TRAFFIC capture readiness and control
- IEEE 802.11 + radiotap validation
- deterministic restore and preserved system default route

Validated examples included:

```text
621940 bytes / 2875 packets / ~4.95 s
38488 bytes / 228 packets / ~10.17 s
820 bytes / 4 packets / ~3.49 s
```

The small capture was validated as a real PCAPNG rather than corruption.

### System-level capture-authorization rollback

Wireshark group authorization is independent of Git checkpoints. If that authorization ever needs to be reverted deliberately:

```bash
sudo gpasswd -d "$USER" wireshark
```

A fresh login is required for supplementary-group changes. Do not manually broaden `/usr/bin/dumpcap` permissions or capabilities as a rollback shortcut.
