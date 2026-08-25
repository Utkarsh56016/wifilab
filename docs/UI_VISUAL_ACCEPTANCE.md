# WiFiLab UI Visual Acceptance

## Reference

The approved design reference is `ref_design.png` in the repository root.

## Current accepted visual baseline

The v4 Quickshell shell is accepted as the first usable visual baseline.

Validated characteristics:

- centered 1040x720 floating niri window
- rounded clipped geometry
- DMS-aligned dark palette
- two-tab CONTROL / TRAFFIC structure
- deterministic fixed instrument-panel geometry
- adapter selector with persistent physical identity
- protected system adapter visibility
- prominent MAN / MON state control
- regulatory/channel controls
- runtime interface/PHY information
- diagnostics, activity and rollback areas
- Traffic page with RX/TX metrics, graph area and protocol section
- footer state indicators remain isolated from body content

## Glass treatment

The accepted geometry must not be changed to obtain transparency. Glass styling is handled independently through:

- mild QML surface translucency
- niri compositor-side background blur
- restrained compositor opacity
- low noise and near-neutral background saturation

Readability takes priority over transparency.

## Hard rules

1. Do not reintroduce stretchable QtQuick Layouts into the fixed 1040x720 visual shell.
2. Header, summary strip, instrument area and footer have deterministic geometry.
3. CONTROL and TRAFFIC content must never overlap the footer.
4. System/protected adapter controls remain disabled in the UI and backend.
5. Quickshell remains unprivileged.
6. Privileged mutations stay behind the root-owned polkit helper.
7. Visual changes must not alter the validated backend safety contract.

## Next acceptance stage

Visual geometry is frozen while functional validation proceeds:

- install and probe polkit/helper path without mutation
- validate MAN -> MON transition
- validate channel control
- validate emergency restore / rollback
- verify system Wi-Fi remains connected throughout
- verify unplug/replug recovery with UI open
- exercise Traffic graph with real counter changes

Only after those gates pass should further cosmetic polish be considered.
