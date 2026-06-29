# iMon Compact Menu Bar Display Design

## Goal

Reduce iMon's menu bar width while preserving glanceable system state. The menu bar must stay compact under changing network throughput, keep upload/download arrows visible, and let users decide exactly which metrics appear.

The product UI is English-only.

## Current Problem

The earlier compact design still used medium-length text labels for load, pressure, and disk, and it treated disk as one menu-bar option. That creates three problems:

- The label column consumes too much menu bar width.
- A single disk toggle does not match the selected per-metric configuration model.
- Network value width can shift as rates change, making the status item visually unstable.

CPU frequency was explored and rejected for the current implementation because macOS does not expose a reliable, Apple-supported live CPU-frequency value across modern Apple Silicon machines. CPU load pressure is the replacement metric because it reflects runnable work relative to active processor capacity.

## Confirmed UX

The menu bar uses a compact two-line metric view. Every visible metric has a short label on the left and a right-aligned value on the right.

Visible labels are first-letter or symbol labels:

- `C`: CPU usage percentage.
- `L`: CPU load pressure percentage.
- `M`: memory usage percentage.
- `P`: memory pressure text.
- `↑`: upload throughput.
- `↓`: download throughput.
- `D`: disk used percentage.
- `F`: disk free capacity.

The default menu bar shows:

```text
C  18%   M  62%   ↑  244K
L  31%   P  Low   ↓  1.2M
```

The default visible values are:

- CPU usage (`C`)
- CPU load pressure (`L`)
- Memory usage (`M`)
- Memory pressure (`P`)
- Upload (`↑`)
- Download (`↓`)

Disk used (`D`) and disk free (`F`) are available but disabled by default.

## User Configuration

Every menu bar field is independently configurable from the `Menu Bar` section in the status menu:

- `Show CPU Usage (C) in Menu Bar`
- `Show CPU Load (L) in Menu Bar`
- `Show Memory Usage (M) in Menu Bar`
- `Show Memory Pressure (P) in Menu Bar`
- `Show Upload (↑) in Menu Bar`
- `Show Download (↓) in Menu Bar`
- `Show Disk Used (D) in Menu Bar`
- `Show Disk Free (F) in Menu Bar`

Toggling a field immediately updates the menu bar and persists the setting. If all fields in a column are disabled, that column disappears. If every field is disabled, the status item falls back to `iMon` so the menu remains recoverable.

The `Details` section keeps full English metric names and full units. It may use the short labels only as secondary hints, not as the primary meaning.

## Layout Rules

The menu bar renderer must follow these rules:

- Labels are left-aligned.
- Values are right-aligned.
- Upload remains above download.
- Upload/download arrows remain visible as the network labels.
- Network values reserve a stable width so the status item does not resize as speeds change.
- Network rows follow the same layout rule as every other row: arrow label left-aligned, value right-aligned.
- Network values use a narrow representative reserved width, for example `99.9M`, to reduce the gap without special-casing arrow layout.
- Kilobyte network values use no decimal point, for example `244K`.
- Megabyte network values use one decimal place, for example `1.2M`.
- Memory pressure and CPU load pressure color the value text, not only an adjacent indicator.
- Dynamic system colors are used for pressure coloring; do not hard-code RGB colors.
- Spacing should be tight enough for menu bar use, without sacrificing readability.

## Metric Semantics

CPU load pressure is computed from one-minute load average divided by active processor count. It is displayed as a percentage and colored with dynamic system colors:

- Normal: system green.
- Warning: system yellow.
- High: system orange.
- Critical: system red.

Memory pressure keeps the existing macOS-derived pressure semantics and dynamic system colors.

Disk used (`D`) is the root volume used percentage. Disk free (`F`) is root volume free capacity, formatted compactly for the menu bar.

## Technical Approach

Use the current Swift Package + AppKit architecture:

- Keep `NSStatusItem` with `NSStatusItem.variableLength`.
- Render the compact layout with a tested AppKit view/helper that computes a stable fitting width.
- Keep `NSMenu` for details and field toggles.
- Persist field visibility with `UserDefaults`.
- Keep pure formatting, settings, and metric semantics in `iMonCore` where practical.

The implementation should stay narrowly scoped to the compact menu bar display, menu toggles, and necessary formatting/model support.

## Verification

Automated checks:

- `swift run iMonCoreSelfTests`
- `swift build`

Self-test coverage should include:

- Default visibility for `C/L/M/P/↑/↓`, with `D/F` disabled.
- Independent toggling and persistence for all eight fields.
- First-letter labels in the menu bar model.
- Disk used and disk free as separate display fields.
- Compact network formatting: no decimals for `K`, one decimal for `M`.
- Stable network display width across representative `K` and `M` values.
- Value coloring for CPU load pressure and memory pressure.
- Fallback title when every field is hidden.

Manual visual verification:

- Run the app and inspect the menu bar.
- Confirm labels are left-aligned and values are right-aligned.
- Confirm arrows remain present for upload and download.
- Confirm network width does not visibly resize when values change.
- Confirm the popup toggle labels explain the short labels in parentheses.
- Capture and display the screenshot directly in Codex for user confirmation.

## Out Of Scope

- Preferences window.
- Charts or historical graphs.
- Sensors, fans, GPU, battery, or process lists.
- Reintroducing CPU frequency without a reliable Apple-supported source.
- Changing metric collection beyond what is needed for CPU load pressure and disk free display.
- Full SwiftUI migration.

## References

- Apple Developer Documentation: [`NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem)
- Apple Developer Documentation: [`NSStatusBarButton`](https://developer.apple.com/documentation/appkit/nsstatusbarbutton)
- Apple Developer Documentation: [`NSColor`](https://developer.apple.com/documentation/appkit/nscolor)
- Local SDK verification: `NSStatusItem.view` is deprecated in the installed macOS SDK, while `NSStatusItem.button` remains available.
