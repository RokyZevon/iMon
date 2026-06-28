# iMon Compact Menu Bar Display Design

## Goal

Reduce iMon's menu bar width while preserving glanceable CPU, memory, and network throughput. The new display should use a compact two-line stack inspired by dense macOS menu bar utilities, but prioritize the simplest Apple-supported implementation path over visual imitation.

## Current Problem

The current menu bar title is a single text string:

```text
CPU 18% MEM 62% v 1.2 MB/s ^ 120 KB/s
```

This wastes menu bar space because every label and network unit expands horizontally. Network upload and download are also currently shown as peer text fragments instead of a compact paired display.

## Confirmed UX

The default menu bar title will contain two side-by-side stacked groups:

- Left group: `CPU` on the first line, `MEM` on the second line.
- Right group: upload on the first line, download on the second line.

Example:

```text
CPU 18%   ↑ 120K
MEM 62%   ↓ 1.2M
```

The network order is intentional: upload is above download. Short network units are used in the menu bar (`120K`, `1.2M`) to keep width low. Full units remain available in the menu details (`120 KB/s`, `1.2 MB/s`).

## Default Visible Values

On first launch, the menu bar shows:

- CPU
- Memory
- Upload
- Download

Disk is not shown in the menu bar by default. Disk remains visible in the detail section of the menu, and users can opt into showing it in the menu bar.

## User Configuration

The user can configure menu bar visibility at the individual value level from the status item menu:

- CPU row
- Memory row
- Upload row
- Download row
- Disk row

The menu contains a `Menu Bar` section with checkable `NSMenuItem`s. Toggling a row immediately updates the menu bar title and persists the setting. The menu also contains a `Details` section that always shows the complete metric values for CPU, memory, disk, upload, and download.

If all rows in a group are disabled, that group disappears from the menu bar and the status item becomes narrower. If only one row in a group is enabled, the enabled value remains visible in that group's stack.

## Technical Approach

Use the current AppKit architecture and stay on official standard controls:

- Keep `NSStatusItem` with `NSStatusItem.variableLength`.
- Use the standard `statusItem.button` for rendering.
- Set `statusItem.button?.attributedTitle` to a compact two-line attributed string.
- Do not use `NSStatusItem.view`, which Apple marks deprecated in the macOS SDK.
- Keep the existing `NSMenu` structure and add checkable menu items for display settings.
- Persist display settings with `UserDefaults`.

This is the smallest official path for the current codebase. SwiftUI `MenuBarExtra` remains a fallback or future migration option because the project targets macOS 13, but moving the app lifecycle and menu UI to SwiftUI is larger than this focused width reduction.

## Components

### MenuBarDisplaySettings

A small value type or controller-owned helper will define:

- Default row visibility.
- `UserDefaults` keys.
- Load/save behavior.
- Toggle helpers for individual rows.

The default configuration enables CPU, memory, upload, and download, and disables disk.

### MetricFormatter

Add compact menu bar formatting for network throughput:

- Bytes per second below 1024 use `B`.
- Kilobytes use `K`.
- Megabytes use `M`.
- Gigabytes use `G`.

The compact format omits `/s` in the menu bar to save space. Existing `rate(_:)` remains for menu details.

### MenuBarTitleFormatter

Add a formatter that converts a `SystemSnapshot` plus `MenuBarDisplaySettings` into an `NSAttributedString` suitable for the status bar button. It should:

- Preserve the row order: CPU above memory, upload above download.
- Use tabular or monospaced digits.
- Use small system fonts appropriate for a two-line menu bar title.
- Keep labels short and stable.
- Return a minimal fallback title if every row is hidden.

### MenuBarController

`MenuBarController` will:

- Load display settings at initialization.
- Build the menu with configuration items and detail items.
- Update checkmark state from settings.
- Re-render the attributed title on every sample and every toggle.
- Save settings immediately after a toggle.

## Error Handling

Existing sampling fallbacks remain unchanged. Formatting should handle zero or unavailable values without crashing. If every menu bar row is disabled, the status item should still remain visible with a short fallback such as `iMon`, so the user can reopen the menu and re-enable rows.

## Verification

Automated checks:

- `swift run iMonCoreSelfTests`
- `swift build`

Self-test coverage should include:

- Compact network rate formatting.
- Default display settings.
- Toggle behavior and persistence boundaries where practical.
- Title formatter row order, especially upload above download.
- Fallback title when all rows are hidden.

Manual verification:

- Run the app and confirm the menu bar displays two stacked groups.
- Confirm upload appears above download.
- Confirm menu checkmarks toggle rows immediately.
- Confirm hiding rows narrows the status item.
- Confirm the detail menu still shows full CPU, memory, disk, upload, and download values.

## Fallback Strategy

If `NSStatusBarButton.attributedTitle` cannot render the two-line stack reliably in the real macOS menu bar, do not use deprecated custom status item views. The next official option is to evaluate SwiftUI `MenuBarExtra` for a custom label layout on macOS 13+.

## Out of Scope

- Preferences window.
- Charts or historical graphs.
- Sensors, fans, GPU, battery, or process lists.
- Full SwiftUI migration unless the AppKit attributed-title approach fails visual verification.

## References

- Apple Developer Documentation: [`NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem)
- Apple Developer Documentation: [`NSStatusBarButton`](https://developer.apple.com/documentation/appkit/nsstatusbarbutton)
- Apple Developer Documentation: [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra)
- Local SDK verification: `NSStatusItem.view` is deprecated in the installed macOS SDK, while `NSStatusItem.button` and `NSButton.attributedTitle` remain available.
