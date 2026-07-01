# Task 2 Report

## What I implemented

- Added [Sources/iMonApp/LoginItemService.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonApp/LoginItemService.swift) with:
  - `public enum LoginItemStatus: Equatable, Sendable`
  - `public protocol LoginItemServiceManaging`
  - `public final class ServiceManagementLoginItemService`
- Added [Sources/iMonApp/LoginItemMenuController.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonApp/LoginItemMenuController.swift) with:
  - `@MainActor public final class LoginItemMenuController`
  - menu item title/target/action setup
  - status-driven refresh for `.enabled`, `.notRegistered`, `.requiresApproval`, `.notFound`
  - toggle handling for register, unregister, approval handoff, and logging on failure
  - cached current status so toggle behavior acts on the last refreshed state
  - refresh only after register/unregister attempts, matching the Task 1 test contract
- Made the minimal permitted Swift 6 test adjustment in [Sources/iMonCoreSelfTests/main.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonCoreSelfTests/main.swift):
  - marked `makeLoginItemController(service:)` as `@MainActor private`

## What I tested and test results

Command:

```bash
swift run iMonCoreSelfTests
```

Result:

- Exit code `0`
- `All 49 self-tests passed`

## TDD Evidence

### RED inherited from Task 1

Command:

```bash
swift run iMonCoreSelfTests
```

Observed RED before implementation:

```text
error: cannot find type 'LoginItemServiceManaging' in scope
error: cannot find type 'LoginItemStatus' in scope
error: cannot find type 'LoginItemMenuController' in scope
```

This confirmed the failing surface was the missing Task 2 production implementation.

### GREEN for Task 2

Command:

```bash
swift run iMonCoreSelfTests
```

Observed GREEN after implementation:

```text
PASS login item menu shows enabled state
PASS login item menu shows not registered state
PASS login item menu registers when turned on
PASS login item menu unregisters when turned off
PASS login item menu opens settings when approval is required
PASS login item menu disables when service is not found
PASS login item menu logs and refreshes after register failure
PASS login item status maps ServiceManagement statuses
All 49 self-tests passed
```

## Files changed

- [Sources/iMonApp/LoginItemService.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonApp/LoginItemService.swift)
- [Sources/iMonApp/LoginItemMenuController.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonApp/LoginItemMenuController.swift)
- [Sources/iMonCoreSelfTests/main.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonCoreSelfTests/main.swift)

## Self-review findings or concerns

- Scope stayed within the Task 2 ownership boundary.
- Public API matches the brief and the Task 1 tests exactly.
- `LoginItemMenuController` is `@MainActor`, which is the right isolation boundary for AppKit menu item mutation under Swift 6.
- `ServiceManagementLoginItemService` uses direct `SMAppService` delegation with `@unknown default` mapped to `.notFound`, which is conservative for future OS additions.
- The only test adjustment was the minimal Swift 6 actor/access-control fix permitted by the brief.
- No functional concerns remain from this task. The one behavioral nuance is intentional: the controller does not call `refresh()` after the `.requiresApproval` path because that path only hands off to System Settings and the Task 1 tests define that contract.

## Follow-up fix for review findings

- Removed the cached `currentStatus` from `LoginItemMenuController`.
- Changed `refresh()` to derive menu state directly from `service.status`.
- Changed `toggleLaunchAtLogin(_:)` to switch on `service.status` at action time.
- Changed `toggleLaunchAtLogin(_:)` to call `refresh()` unconditionally after handling `.enabled`, `.notRegistered`, `.requiresApproval`, or `.notFound`.
- Updated the self-test fake service to track status reads and expanded status sequences where the corrected flow now performs init refresh, action-time status read, and post-action refresh.

## Exact verification command and result for the follow-up fix

Command:

```bash
swift run iMonCoreSelfTests
```

Result:

- Exit code `0`
- `All 49 self-tests passed`

## Files changed for the follow-up fix

- [Sources/iMonApp/LoginItemMenuController.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonApp/LoginItemMenuController.swift)
- [Sources/iMonCoreSelfTests/main.swift](/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login/Sources/iMonCoreSelfTests/main.swift)

## Concerns for the follow-up fix

- The earlier report section describing cached status and conditional refresh is now obsolete; the code has been corrected to the Apple best-practice behavior required by review.
