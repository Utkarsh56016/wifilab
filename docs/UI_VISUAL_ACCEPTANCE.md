# WiFiLab UI Visual Acceptance

The approved design reference is `ref_design.png`.

## Current status

The v3 read-only Quickshell render is **not visually accepted** yet.

Compositor integration is healthy:

- app ID: `io.github.utkarsh56016.wifilab`
- niri floating rule works
- window geometry is 1040 x 720
- rounded clipping works
- Quickshell loads without QML binding/reference errors

The remaining failure is QML layout allocation, not compositor integration.

## Reference structure

The CONTROL page should read as a stable three-column instrument panel:

```text
Adapters / Mode / Runtime
Channel  / State / Restore
Activity / Diagnostics / Future
```

The TRAFFIC page is allowed to differ from the control mockup, but must preserve the same shell, summary strip, spacing, typography, and card proportions.

## v3 failure observed on workstation

The TRAFFIC tab showed the adapter/safety summary row stretched to several hundred pixels, while the RX/TX/MODE/PROTOCOL metric row and lower traffic content were pushed into the footer region.

Root cause is deterministic Qt Quick Layout behavior: rows/cards that are meant to be fixed-height use `Layout.preferredHeight` without matching `Layout.minimumHeight` and `Layout.maximumHeight`. With remaining vertical space, the layout is free to stretch them.

Affected constraints include at minimum:

- `panel.qml` adapter/safety summary row: 74 px
- `panel.qml` header: 44 px
- `panel.qml` footer: 20 px
- `TrafficDashboard.qml` metric row: 78 px
- `TrafficDashboard.qml` protocol card: 132 px
- `ControlDashboard.qml` row 1: 170 px
- `ControlDashboard.qml` row 2: 160 px

These fixed rows should use matching min/preferred/max heights. Only the intentionally flexible content area should use `Layout.fillHeight`.

## Acceptance rule

Do not enable the privileged UI helper until both CONTROL and TRAFFIC pages satisfy visual acceptance against `ref_design.png` and render without clipping/overlap.
