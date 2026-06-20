# iMon macOS Menu Monitor Design

## Goal

iMon is a lightweight open source macOS menu bar monitor inspired by iStat. The first release monitors CPU, memory, disk, and network throughput only. It should build and run locally with standard macOS developer tools, keep resource usage low, and keep the sampling core testable without launching UI.

## Requirements

- Provide a macOS menu bar application named iMon.
- Show current CPU usage, memory usage, disk usage, and network receive/transmit rate.
- Use native macOS APIs where practical and avoid heavyweight runtimes.
- Keep monitoring logic modular and separated from AppKit UI.
- Include automated tests for CPU, memory, disk, and network core logic.
- Include README instructions for building, testing, and running.
- Preserve this implementation on the `codex/imon-menu-monitor` branch and its worktree for review.

## Approach Options

### Option A: Swift Package + AppKit Menu Bar

Use Swift Package Manager with an executable target that creates an `NSStatusItem` and runs an AppKit application loop. Core sampling lives in a library target with protocol-backed providers for CPU, memory, disk, and network readings.

Trade-offs: This is the recommended approach. It uses the native platform, has no third-party runtime, builds with `swift build`, and lets tests exercise most logic without UI. It does not produce a polished signed `.app` bundle by default, but the executable is usable for local review.

### Option B: SwiftUI Menu Bar Extra

Use a SwiftUI app with `MenuBarExtra`. This gives modern declarative UI but requires an app bundle/Xcode project style and can complicate simple command-line build/run instructions.

Trade-offs: Nice UI ergonomics, but heavier packaging for this repository stage.

### Option C: Go or Rust Agent + Native Shell UI

Build a fast sampler in Go or Rust and pair it with a small native wrapper. This can be efficient but introduces a split stack and makes a first working macOS menu bar UI more complex.

Trade-offs: Strong systems performance, but worse native UI integration and more moving pieces.

## Selected Architecture

iMon will use Option A: Swift Package + AppKit. The package will contain:

- `iMonCore`: a pure-ish Swift library for metric models, formatting, delta calculations, provider protocols, and aggregation.
- `iMon`: an executable AppKit menu bar app that periodically samples `iMonCore`, renders a compact status title, and exposes a menu with detailed metric rows.
- `iMonCoreTests`: XCTest tests for unit formatting, CPU delta math, memory model, disk model, network throughput delta math, and aggregate snapshot behavior.

This structure keeps platform sampling behind narrow protocols while making calculations deterministic in tests.

## Components

### Metric Models

The core library defines value types for:

- `CPUUsage`: user, system, idle percentages and a computed active percentage.
- `MemoryUsage`: used, total, and computed percentage.
- `DiskUsage`: used, total, and computed percentage.
- `NetworkRate`: receive/transmit bytes per second.
- `SystemSnapshot`: a combined snapshot with timestamp and all four metric groups.

All percentages are clamped to `0...100`. Byte values use unsigned integer storage where practical and formatting converts to human-readable strings.

### Providers

Provider protocols isolate system calls:

- `CPUSampleProvider` returns raw CPU ticks.
- `MemorySampleProvider` returns memory totals and used bytes.
- `DiskSampleProvider` returns disk totals and used bytes for the selected volume.
- `NetworkSampleProvider` returns cumulative receive/transmit byte counters.

Concrete macOS providers use:

- CPU: `host_processor_info` tick counters.
- Memory: `host_statistics64` plus `host_page_size`.
- Disk: `FileManager.attributesOfFileSystem`.
- Network: `getifaddrs` interface byte counters, excluding loopback and inactive interfaces.

### Sampler

`SystemSampler` owns provider instances and previous CPU/network raw samples. Each `sample(now:)` call:

1. Reads current raw provider values.
2. Computes CPU percentages from tick deltas when a previous CPU sample exists.
3. Computes network bytes/sec from counter deltas and elapsed time.
4. Reads memory and disk instantaneous values.
5. Returns a `SystemSnapshot`.

The first sample returns zero CPU/network rates where deltas are not yet available. Provider failures do not crash the app; they produce conservative zero/unknown values while preserving the UI loop.

### Formatting

`MetricFormatter` converts bytes, percentages, and status titles into compact strings. The menu bar title will prioritize scanability, for example:

`CPU 18% MEM 62% v 1.2 MB/s ^ 120 KB/s`

The expanded menu shows CPU, memory, disk, download, and upload rows plus Quit.

### AppKit UI

`MenuBarController` creates the `NSStatusItem`, starts a timer, and updates title/menu rows on the main thread. The timer interval defaults to one second. The app sets activation policy to accessory so it behaves like a menu bar utility.

UI stays deliberately small: no charts, no preferences window, no login item, no notifications. Those are outside the first release scope.

## Error Handling

Sampling errors should be contained inside concrete providers or sampler fallbacks:

- CPU delta with zero total ticks returns 0% active.
- Network elapsed time less than or equal to zero returns 0 B/s.
- Counter reset or wrap returns 0 B/s for that interval.
- Disk or memory provider failure returns zero totals so formatting shows safe fallback values.
- AppKit timer continues after failed samples.

## Performance

The sampling loop runs once per second and performs O(number of CPUs + number of network interfaces) work. There are no background worker pools and no third-party dependencies. Value types are small, and UI updates rewrite a handful of menu item titles.

## Testing Strategy

Tests will cover:

- CPU tick delta conversion, including first sample and zero-delta behavior.
- Network rate delta conversion, including first sample, elapsed time, and counter reset.
- Memory and disk percentage calculations and clamping.
- Byte and percentage formatting.
- Aggregation through `SystemSampler` using deterministic fake providers.

The AppKit executable will be verified with `swift build`; UI behavior will be manually runnable through `.build/debug/iMon`.

## Out of Scope

- Sensors, fan speed, GPU, battery, process lists, notifications, history charts, preferences, login items, packaging/signing/notarization, and iCloud/sync support.

## Acceptance Evidence

Completion is proven by:

- Design doc committed in `docs/superpowers/specs/`.
- Implementation plan committed in `docs/superpowers/plans/`.
- Swift package with `iMonCore`, `iMon`, and tests.
- `swift test` passing.
- `swift build` passing.
- README explaining build, run, and test commands.
- Final report listing branch, worktree, test output, and any residual risks.
