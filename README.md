# iMon

iMon is a lightweight open source macOS menu bar monitor inspired by iStat. This first release monitors CPU, memory, disk usage, and network throughput.

License: MIT.

## Tech Stack

- Swift Package Manager
- Swift + AppKit for the menu bar application
- Native macOS/Darwin APIs for metric collection
- Executable self-test harness for core metric tests

## Build

```bash
swift build
```

## Run

```bash
swift run iMon
```

The app appears in the macOS menu bar and uses accessory activation policy, so it does not show a Dock icon.

## Package As A macOS App

```bash
./scripts/package_app.sh
open dist/iMon.app
```

The packaged app is created at `dist/iMon.app`. It is ad-hoc signed for local use, but it is not notarized.

## Test

```bash
swift run iMonCoreSelfTests
```

This repository uses an executable self-test target instead of XCTest because the CommandLineTools-only environment used during development could compile Swift/AppKit but did not expose XCTest to SwiftPM test targets.

## Scope

Implemented:

- CPU usage
- Memory usage
- Disk usage for the root volume
- Network receive/transmit throughput

Out of scope for this first release:

- Sensors
- Fans
- GPU
- Battery
- Process lists
- Charts
- Preferences
- Login items
- Signing and notarized app packaging

## Architecture

`iMonCore` contains metric models, formatting, provider protocols, macOS providers, and the stateful sampler. The `iMon` executable owns the AppKit status item and timer. UI code only consumes snapshots from the core sampler.

## Notes

- CPU and network throughput are delta-based, so the first sample intentionally shows zero for those metrics until a second sample is available.
- Network counters use macOS `ifmibdata` / `if_data64` counters and skip loopback plus common virtual interfaces.
- The current output is an unsigned local executable, not a packaged `.app`.
