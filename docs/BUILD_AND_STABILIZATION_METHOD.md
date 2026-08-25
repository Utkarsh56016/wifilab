# WiFiLab Build and Stabilization Method

## Purpose

WiFiLab will be expanded as a workstation wireless-lab and adapter-management application using a strict one-feature-at-a-time engineering cycle.

The objective is to increase capability without destabilizing the already validated CONTROL, TRAFFIC, radio-safety, capture, and primary-network protection behavior.

## Core Rule

**Only one expansion feature may be under active implementation at a time.**

A feature is not considered complete when the code exists. It is complete only after its backend contract, real-hardware behavior, UI integration, safety invariants, documentation, and rollback point have been validated.

No later phase begins until the current phase is stabilized.

## Stable-First Branching Model

`main` represents the latest accepted stable state.

For each expansion phase:

```text
main (stable)
  |
  +--> feature/<phase-name>
          |
          +-- backend contract
          +-- implementation
          +-- CLI/JSON tests
          +-- hardware validation
          +-- UI integration
          +-- UI/safety validation
          |
          +--> accepted
                  |
                  v
               main
                  |
                  +--> checkpoint/<phase>-validated-<date>
```

Rules:

- Do not develop two feature phases in parallel.
- Do not merge an unvalidated feature into `main`.
- Documentation-only updates may be made on `main` when they do not change runtime behavior.
- Every accepted phase receives a named checkpoint branch pinned to the exact validated commit.
- Existing checkpoint branches are immutable historical rollback references.

## Per-Feature Engineering Cycle

### Gate 0 — Baseline confirmation

Before modifying a feature area:

- confirm the current stable commit
- confirm the previous checkpoint exists
- verify the selected lab adapter resolves correctly
- verify the primary/default-route interface remains protected
- verify the current UI opens and the existing stabilized tabs function

This gate prevents debugging a new feature on top of an already-broken baseline.

### Gate 1 — Scope freeze

Define one bounded feature only.

Record:

- problem being solved
- user-facing instrument/view
- backend data required
- commands or mutations required
- safety boundaries
- explicit non-goals
- acceptance criteria

Do not add adjacent features during implementation just because they are convenient.

### Gate 2 — Backend contract first

Implement or extend the backend before changing the Quickshell UI.

Requirements:

- CLI remains usable without the GUI
- machine-readable JSON is authoritative
- runtime interface names are never trusted as persistent identity
- protected/default-route interfaces remain guarded
- privileged operations remain narrowly allowlisted
- read-only functionality remains unprivileged where possible
- failures are explicit and non-destructive

Healthy backend behavior must be testable from a terminal before UI work begins.

### Gate 3 — Controlled backend validation

Test the feature with the smallest meaningful real-hardware matrix.

Every validation command must have a defined purpose and expected result.

Validate:

- intended success path
- at least one meaningful refusal/failure path
- selected physical adapter identity
- primary-network safety
- rollback/restore behavior when mutation is involved

Do not repeat large soak matrices unless new evidence indicates an intermittent problem.

### Gate 4 — UI integration

Only after the backend passes do we integrate the feature into Quickshell.

UI rules:

- Quickshell is presentation/control, not policy authority
- backend JSON remains the source of truth
- no root Quickshell process
- no duplicated safety logic that can diverge from the backend
- do not disturb stabilized CONTROL or TRAFFIC behavior unnecessarily
- preserve the 1040×720 application geometry unless a dedicated UI-shell phase explicitly changes it
- reuse existing components, palette, spacing, and interaction patterns
- new instruments must degrade gracefully when optional capabilities are unavailable

### Gate 5 — UI acceptance validation

Test only the new UI path plus the regression-sensitive stabilized paths.

Minimum regression checks:

- CONTROL still resolves/selects the physical lab adapter
- MAN/MON/Restore behavior remains correct
- protected primary interface remains non-mutable
- TRAFFIC still renders and does not interfere with primary connectivity
- new tab/instrument reflects backend state correctly
- closing the UI does not unexpectedly mutate radio state

### Gate 6 — Stabilization window

After functional acceptance, stop adding scope.

Only perform:

- bug fixes
- error-state cleanup
- race/state synchronization fixes
- UI overflow/layout corrections
- documentation corrections

A phase is not stabilized if new capabilities are still being added to it.

### Gate 7 — Documentation and checkpoint

Record:

- problem
- design/root cause where applicable
- implementation
- commands executed
- validation results
- known limitations
- final state
- rollback method

Then:

1. merge/fast-forward the validated feature to `main`
2. create a checkpoint branch at that exact accepted commit
3. update `ROADMAP.md`
4. only then open the next feature phase

## Invariants That Must Survive Every Phase

The following are release-blocking invariants:

1. The system/default-route Wi-Fi adapter must remain protected from lab mutations.
2. Physical adapter identity must survive changing `wlanX`/`phyX` runtime names.
3. NetworkManager must never be globally killed or disabled for WiFiLab operations.
4. No `airmon-ng check kill` style global disruption.
5. Regulatory restrictions are never bypassed.
6. Quickshell never runs as root.
7. Capture does not use `sudo`, `pkexec`, or a root capture process.
8. Failure in a new feature must not mutate unrelated network/radio state.
9. Existing stabilized tabs must be regression-tested before the new phase is accepted.
10. A rollback checkpoint must exist before moving to the next phase.

## UI Stability Policy

The current accepted application shell is treated as stable infrastructure.

Current stable views:

```text
CONTROL
TRAFFIC
```

Expansion target:

```text
CONTROL | TRAFFIC | CAPTURES | NETWORK | SURVEY | LAB
```

New tabs are added incrementally. A tab is not exposed as an active production view until its backend and minimum UI behavior are ready for validation.

The navigation shell may be resized/reworked only as much as required to support the expanded tab set while preserving:

- 1040×720 window geometry
- existing visual language
- header controls
- summary strip
- footer
- CONTROL/TRAFFIC instrument geometry unless a phase explicitly requires local layout changes

## Stop Conditions

Pause a phase instead of pushing forward if any of the following occurs:

- default route unexpectedly changes
- `wlan0` becomes unprotected or mutated
- adapter identity resolves to the wrong physical device
- a backend operation requires broader privilege than designed
- UI state disagrees with backend state
- a new feature causes periodic process churn or excessive resource use
- restore fails
- previous stable tab behavior regresses

The correct response is investigation and rollback, not adding compensating complexity.
