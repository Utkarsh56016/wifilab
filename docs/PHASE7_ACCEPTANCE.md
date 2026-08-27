# WiFiLab Phase 7 Acceptance Record

Date: 2026-08-27

Phase 7 (CAPTURES) is accepted for the validated Archcraft workstation.

## Functional checkpoint

```text
commit: 17c79c134c1b66f56cc9821191e7c1fdbb533709
branch: checkpoint/phase7-captures-validated-2026-08-27
```

## Accepted architecture

```text
LIVE RADIO
   |
   `-> wifilab capture run
          |
          `-> normal-user dumpcap
                 |
                 +-> capture-*.pcapng
                 `-> capture-*.json manifest

SAVED CAPTURE
   |
   +-> inventory/latest
   +-> capinfos inspection
   +-> tshark -r protocol analysis
   +-> SHA-256 verification
   +-> Reveal
   `-> Wireshark GUI when available
```

Invariant: nothing except `capture run` initiates packet capture.

## Final validation

- backend syntax: PASS
- LAB physical selection: PASS
- LAB runtime state: `wlan4 / phy4`, monitor, unmanaged
- driver: `rtw88_8822bu`
- regdomain: `IN`
- PRIMARY default route: `wlan0`
- capture readiness: true
- saved capture inventory: 6
- latest capture integrity: verified
- latest encapsulation: `ieee-802-11-radiotap`
- latest packet count: 18
- latest duration: 9.932723659 s
- latest bytes: 8024
- offline protocol source: `saved_capture`
- live `tshark -i` code path: absent
- leftover `tshark`/`dumpcap`/`capinfos`: none
- invalid/traversal/missing/symlink refusal: PASS
- legacy Phase 6 captures: PASS
- CONTROL regression: PASS
- TRAFFIC regression: PASS
- CAPTURES QML: PASS
- fixed 1040x720 shell: PASS
- repository working tree at acceptance: clean

## Deferred non-blocking item

The QML AppId `io.github.utkarsh56016.wifilab` currently has no installed matching `.desktop` entry, so Qt/XDG Desktop Portal logs a registration warning in foreground mode. This is a packaging/integration item and has no demonstrated capture, radio, routing, or UI-functional impact.

## Next phase

Phase 8 — NETWORK: start read-only, inventory the workstation topology, derive PRIMARY/LAB/AUXILIARY/VIRTUAL/TUNNEL roles, then build LAB PATH before considering any controlled network mutations.
