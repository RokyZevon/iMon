# iMon Compact Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:test-driven-development` for code changes and `superpowers:verification-before-completion` before claiming completion. Use `superpowers:subagent-driven-development` only for independent research or review tasks.

**Goal:** Implement the finalized compact menu bar design: first-letter metric labels, stable network width, value-aligned rows, independent visibility configuration for every field, and direct visual validation.

**Architecture:** Keep the existing Swift Package + AppKit status item architecture. Put metric semantics, display settings, formatting, and persistence in `iMonCore`. Keep AppKit rendering helpers in `iMonApp`. Keep `Sources/iMon/main.swift` focused on menu wiring and live status-item updates.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit `NSStatusItem`/`NSStatusBarButton`, Foundation `UserDefaults`, executable self-test target.

---

## Current Baseline

Work from a fresh worktree based on latest `origin/main` before writing code. The active worktree for this revision is `/private/tmp/imon-latest-main-layout`, based on commit `605f4f17ecc9e6492cca01dd5ce6beb8d9ce4da2`.

Existing in-progress implementation already includes:

- CPU load sampling via one-minute load average divided by active processor count.
- CPU load pressure levels and dynamic value coloring.
- A compact AppKit menu bar metrics view.
- Menu bar display settings persisted with `UserDefaults`.
- Self-tests for the existing compact display path.

This plan updates that implementation to match the finalized UX decisions in `docs/superpowers/specs/2026-06-28-imon-compact-menubar-design.md`.

## File Structure

- Modify `Sources/iMonCore/Metrics.swift`: add disk free capacity, compact storage formatting, and compact network formatting rules if needed.
- Modify `Sources/iMonCore/MenuBarDisplay.swift`: replace single disk visibility with separate disk used/free fields and update defaults/persistence.
- Modify `Sources/iMonApp/MenuBarMetricsView.swift`: use first-letter labels, fixed network value width, and right-aligned values.
- Modify `Sources/iMon/main.swift`: update toggle items, states, actions, and detail labels.
- Modify `Sources/iMonCoreSelfTests/main.swift`: update and add tests before implementation.
- Modify `README.md`: document the finalized compact labels and individual menu-bar configuration.

---

## Task 1: Tests For Finalized Labels And Formatting

**Files:**

- Modify `Sources/iMonCoreSelfTests/main.swift`

- [x] Add or update a test proving the default menu bar model uses these labels in order: `C/L`, `M/P`, `↑/↓`.
- [x] Add a test proving disk used and disk free are separate display fields labeled `D` and `F`.
- [x] Add a test proving default visibility enables `C`, `L`, `M`, `P`, `↑`, and `↓`, while disabling `D` and `F`.
- [x] Add a test proving all eight fields toggle independently.
- [x] Add a test proving display settings persistence stores all eight fields independently.
- [x] Add compact network formatting tests:
  - `41K` has no decimal point.
  - `244K` has no decimal point.
  - `1.2M` has one decimal point.
- [x] Add a stable-width test for the AppKit view/model so representative `K` and `M` network values produce the same reserved network value width.
- [x] Run `swift run iMonCoreSelfTests` and confirm the new/updated tests fail for the expected reasons.

## Task 2: Core Settings And Formatter Implementation

**Files:**

- Modify `Sources/iMonCore/Metrics.swift`
- Modify `Sources/iMonCore/MenuBarDisplay.swift`

- [x] Add `DiskUsage.freeBytes`.
- [x] Add compact storage formatting for disk free capacity, for example `128G`.
- [x] Add or adjust compact network formatting for menu bar values:
  - Bytes: compact `B` value.
  - Kilobytes: integer `K`.
  - Megabytes: one-decimal `M`.
  - Gigabytes and above: keep compact one-decimal units if needed.
- [x] Replace the single disk menu-bar field with independent `.diskUsed` and `.diskFree` metrics.
- [x] Replace the legacy single disk visibility property with independent disk-used and disk-free visibility properties.
- [x] Keep both disk fields disabled by default.
- [x] Preserve or migrate legacy `menuBarDisplay.disk` only as a compatibility fallback if it does not complicate the focused change.
- [x] Run `swift run iMonCoreSelfTests` and confirm core tests pass or fail only on expected AppKit/UI work.

## Task 3: Compact View Layout Implementation

**Files:**

- Modify `Sources/iMonApp/MenuBarMetricsView.swift`
- Modify `Sources/iMonApp/MenuBarAttributedTitle.swift` only if legacy/fallback attributed-title tests require consistency.

- [x] Change visible labels to `C`, `L`, `M`, `P`, `↑`, `↓`, `D`, and `F`.
- [x] Preserve upload/download arrows.
- [x] Ensure each row draws the label left-aligned and value right-aligned.
- [x] Reserve a stable network value width using a narrow representative maximum such as `99.9M`, so the status item does not resize as values move between `K` and `M`.
- [x] Keep network rows on the same label-left/value-right layout as every other row; reduce the arrow/value gap by narrowing the reserved value slot, not by special-casing arrow placement.
- [x] Keep the inter-column spacing tight.
- [x] Keep CPU load pressure and memory pressure color on the value text using dynamic `NSColor` values.
- [x] Run `swift run iMonCoreSelfTests`.

## Task 4: Menu Wiring And Popup Labels

**Files:**

- Modify `Sources/iMon/main.swift`

- [x] Replace toggle titles with full English labels plus short labels in parentheses:
  - `Show CPU Usage (C) in Menu Bar`
  - `Show CPU Load (L) in Menu Bar`
  - `Show Memory Usage (M) in Menu Bar`
  - `Show Memory Pressure (P) in Menu Bar`
  - `Show Upload (↑) in Menu Bar`
  - `Show Download (↓) in Menu Bar`
  - `Show Disk Used (D) in Menu Bar`
  - `Show Disk Free (F) in Menu Bar`
- [x] Replace one disk toggle item with separate disk used and disk free toggle items.
- [x] Update menu item state refresh for all eight fields.
- [x] Update toggle actions for all eight fields.
- [x] Keep details readable with full English metric names and full units.
- [x] Run `swift run iMonCoreSelfTests`.

## Task 5: Documentation

**Files:**

- Modify `README.md`

- [x] Document that the menu bar uses compact first-letter labels.
- [x] Document that the status menu explains labels in parentheses and allows independent field configuration.
- [x] Mention disk used/free are available but disabled by default.
- [x] Search README, Superpowers docs, and `Sources` for old product-facing labels or the legacy single disk toggle, then resolve remaining contradictions.

## Task 6: Build And Automated Verification

- [x] Run `swift run iMonCoreSelfTests`.
- [x] Run `swift build`.
- [x] Inspect `git diff --stat` and `git diff --check`.
- [x] Confirm no unrelated user changes were reverted.

## Task 7: Visual Verification

- [x] Run the app from the verified worktree.
- [x] Capture the menu bar/status item.
- [x] Display the screenshot directly in Codex with the local image viewer, not only as a file path.
- [x] Confirm visually:
  - Labels are first-letter labels.
  - Labels are left-aligned.
  - Values are right-aligned.
  - Upload/download arrows are visible.
  - Network columns have stable width.
  - Popup labels explain abbreviations in parentheses.
- [x] Ask the user to confirm the visual result.

## Out Of Scope

- Preferences window.
- Charts or history.
- Sensors, fans, GPU, battery, or process lists.
- CPU frequency collection.
- Replacing AppKit with SwiftUI.
- Adding new metrics beyond CPU load pressure and disk free capacity.
