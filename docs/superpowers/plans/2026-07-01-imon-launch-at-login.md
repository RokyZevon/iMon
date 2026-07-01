# iMon Launch At Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-controlled `Launch at Login` menu capability backed by Apple's `SMAppService.mainApp`.

**Architecture:** Add a small testable login item layer in `iMonApp`, wire it into the existing AppKit status menu, and keep runtime state derived from ServiceManagement rather than `UserDefaults`. Tests use a fake service so no automated test registers a real login item.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit `NSMenuItem`, ServiceManagement `SMAppService`, executable self-test target.

## Global Constraints

- Minimum platform remains macOS 13.
- Use `SMAppService.mainApp`; do not use deprecated `SMLoginItemSetEnabled`.
- Do not add a helper bundle, LaunchAgent plist, LaunchDaemon plist, entitlements, or auto-enable behavior.
- Launch-at-login must be explicitly user-controlled through the status menu.
- Implementation work happens in isolated worktree `/Users/rokyzevon/dev/projects/iMon/.worktrees/launch-at-login` on branch `feature/launch-at-login`.
- Do not dispatch implementation subagents unless the worker model can be explicitly set to `gpt-5.4-medium`.

---

## File Structure

- Create `Sources/iMonApp/LoginItemService.swift`: app-facing status enum, fakeable protocol, and ServiceManagement adapter.
- Create `Sources/iMonApp/LoginItemMenuController.swift`: AppKit menu item state/action coordinator.
- Modify `Sources/iMon/main.swift`: add login item menu items, inject the production service, and refresh menu state on menu open.
- Modify `Sources/iMonCoreSelfTests/main.swift`: add fake-service tests for menu state/actions, including unknown status behavior.
- Modify `README.md`: document that launch-at-login is available from the packaged signed `.app`.

---

### Task 1: Failing Login Item Tests

**Files:**
- Modify: `Sources/iMonCoreSelfTests/main.swift`

**Interfaces:**
- Consumes: current `expect`, `expectEqual`, `NSMenuItem`, and `iMonApp` import.
- Produces: tests that define expected `LoginItemStatus`, `LoginItemServiceManaging`, and `LoginItemMenuController` behavior.

- [ ] **Step 1: Add the fake service and tests before production code**

Add this block near the existing menu item tests:

```swift
private final class FakeLoginItemService: LoginItemServiceManaging {
    var statuses: [LoginItemStatus]
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSettingsCallCount = 0
    var registerError: Error?
    var unregisterError: Error?

    init(statuses: [LoginItemStatus]) {
        self.statuses = statuses
    }

    var status: LoginItemStatus {
        statuses.removeFirst()
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
    }

    func openSystemSettingsLoginItems() {
        openSettingsCallCount += 1
    }
}

func makeLoginItemController(
    service: FakeLoginItemService
) -> (LoginItemMenuController, NSMenuItem, NSMenuItem, [String]) {
    let launchItem = NSMenuItem()
    let settingsItem = NSMenuItem()
    var logMessages: [String] = []
    let controller = LoginItemMenuController(
        launchAtLoginItem: launchItem,
        openSettingsItem: settingsItem,
        service: service,
        logger: { logMessages.append($0) }
    )
    return (controller, launchItem, settingsItem, logMessages)
}

@MainActor
func testLoginItemMenuShowsEnabledState() throws {
    let service = FakeLoginItemService(statuses: [.enabled])
    let (_, launchItem, settingsItem, _) = makeLoginItemController(service: service)

    try expectEqual(launchItem.title, "Launch at Login", "launch item title")
    try expectEqual(launchItem.state, .on, "enabled status checks launch item")
    try expect(launchItem.isEnabled, "enabled status keeps launch item enabled")
    try expect(settingsItem.isHidden, "settings item hidden when approval is not required")
}

@MainActor
func testLoginItemMenuShowsNotRegisteredState() throws {
    let service = FakeLoginItemService(statuses: [.notRegistered])
    let (_, launchItem, settingsItem, _) = makeLoginItemController(service: service)

    try expectEqual(launchItem.state, .off, "not registered status unchecks launch item")
    try expect(launchItem.isEnabled, "not registered status keeps launch item enabled")
    try expect(settingsItem.isHidden, "settings item hidden for not registered status")
}

@MainActor
func testLoginItemMenuRegistersWhenTurnedOn() throws {
    let service = FakeLoginItemService(statuses: [.notRegistered, .enabled])
    let (controller, launchItem, _, _) = makeLoginItemController(service: service)

    controller.toggleLaunchAtLogin(launchItem)

    try expectEqual(service.registerCallCount, 1, "turning on calls register")
    try expectEqual(service.unregisterCallCount, 0, "turning on does not call unregister")
    try expectEqual(launchItem.state, .on, "menu refreshes after registering")
}

@MainActor
func testLoginItemMenuUnregistersWhenTurnedOff() throws {
    let service = FakeLoginItemService(statuses: [.enabled, .notRegistered])
    let (controller, launchItem, _, _) = makeLoginItemController(service: service)

    controller.toggleLaunchAtLogin(launchItem)

    try expectEqual(service.unregisterCallCount, 1, "turning off calls unregister")
    try expectEqual(service.registerCallCount, 0, "turning off does not call register")
    try expectEqual(launchItem.state, .off, "menu refreshes after unregistering")
}

@MainActor
func testLoginItemMenuOpensSettingsWhenApprovalIsRequired() throws {
    let service = FakeLoginItemService(statuses: [.requiresApproval, .requiresApproval, .requiresApproval, .requiresApproval])
    let (controller, launchItem, settingsItem, _) = makeLoginItemController(service: service)

    try expectEqual(launchItem.state, .off, "requires approval is not checked")
    try expect(launchItem.isEnabled, "requires approval keeps launch item actionable")
    try expect(!settingsItem.isHidden, "settings item is visible when approval is required")

    controller.toggleLaunchAtLogin(launchItem)
    controller.openLoginItemsSettings(settingsItem)

    try expectEqual(service.registerCallCount, 0, "requires approval does not retry register")
    try expectEqual(service.openSettingsCallCount, 2, "both approval actions open settings")
    try expectEqual(service.statusReadCount, 4, "approval flow re-reads service status after both settings actions")
}

@MainActor
func testLoginItemMenuDisablesWhenServiceIsNotFound() throws {
    let service = FakeLoginItemService(statuses: [.notFound])
    let (_, launchItem, settingsItem, _) = makeLoginItemController(service: service)

    try expectEqual(launchItem.state, .off, "not found is unchecked")
    try expect(!launchItem.isEnabled, "not found disables launch item")
    try expectEqual(launchItem.toolTip, "Launch at login is available from the packaged app.", "not found tooltip")
    try expect(settingsItem.isHidden, "settings item hidden when service is not found")
}

@MainActor
func testLoginItemMenuLogsAndRefreshesAfterRegisterFailure() throws {
    let service = FakeLoginItemService(statuses: [.notRegistered, .requiresApproval])
    service.registerError = FakeProviderError.unavailable
    let (controller, launchItem, settingsItem, logMessages) = makeLoginItemController(service: service)

    controller.toggleLaunchAtLogin(launchItem)

    try expectEqual(service.registerCallCount, 1, "register was attempted")
    try expectEqual(launchItem.state, .off, "failed register refreshes state")
    try expect(!settingsItem.isHidden, "failed register can reveal approval settings")
    try expect(logMessages.contains { $0.hasPrefix("Unable to enable launch at login:") }, "register failure is logged")
}
```

Add an unknown-status behavior test:

```swift
@MainActor
func testLoginItemMenuTreatsUnknownStatusAsSettingsAction() throws {
    let service = FakeLoginItemService(statuses: [.unknown, .unknown, .unknown])
    let (controller, launchItem, settingsItem, _) = makeLoginItemController(service: service)

    try expectEqual(launchItem.state, .off, "unknown status is unchecked")
    try expect(launchItem.isEnabled, "unknown status keeps launch item actionable")
    try expectEqual(
        launchItem.toolTip,
        "Review iMon in Login Items settings to confirm launch at login.",
        "unknown status tooltip"
    )
    try expect(!settingsItem.isHidden, "settings item is visible for unknown status")

    controller.toggleLaunchAtLogin(launchItem)

    try expectEqual(service.registerCallCount, 0, "unknown status does not register blindly")
    try expectEqual(service.unregisterCallCount, 0, "unknown status does not unregister blindly")
    try expectEqual(service.openSettingsCallCount, 1, "unknown status opens settings")
    try expectEqual(service.statusReadCount, 3, "unknown status re-reads service status after toggle")
}
```

Add test entries to `tests`:

```swift
("login item menu shows enabled state", { try MainActor.assumeIsolated { try testLoginItemMenuShowsEnabledState() } }),
("login item menu shows not registered state", { try MainActor.assumeIsolated { try testLoginItemMenuShowsNotRegisteredState() } }),
("login item menu registers when turned on", { try MainActor.assumeIsolated { try testLoginItemMenuRegistersWhenTurnedOn() } }),
("login item menu unregisters when turned off", { try MainActor.assumeIsolated { try testLoginItemMenuUnregistersWhenTurnedOff() } }),
("login item menu opens settings when approval is required", { try MainActor.assumeIsolated { try testLoginItemMenuOpensSettingsWhenApprovalIsRequired() } }),
("login item menu disables when service is not found", { try MainActor.assumeIsolated { try testLoginItemMenuDisablesWhenServiceIsNotFound() } }),
("login item menu treats unknown status as settings action", { try MainActor.assumeIsolated { try testLoginItemMenuTreatsUnknownStatusAsSettingsAction() } }),
("login item menu logs and refreshes after register failure", { try MainActor.assumeIsolated { try testLoginItemMenuLogsAndRefreshesAfterRegisterFailure() } }),
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: FAIL at compile time because `LoginItemServiceManaging`, `LoginItemStatus`, and `LoginItemMenuController` do not exist.

---

### Task 2: Login Item Service And Menu Controller

**Files:**
- Create: `Sources/iMonApp/LoginItemService.swift`
- Create: `Sources/iMonApp/LoginItemMenuController.swift`
- Modify: `Sources/iMonCoreSelfTests/main.swift` only if Swift access control requires a test-only signature adjustment.

**Interfaces:**
- Consumes: tests from Task 1.
- Produces:
  - `public enum LoginItemStatus: Equatable`
  - `public protocol LoginItemServiceManaging`
  - `public final class ServiceManagementLoginItemService`
  - `@MainActor public final class LoginItemMenuController`

- [ ] **Step 1: Implement `LoginItemService.swift`**

```swift
import ServiceManagement

public enum LoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown

    init(serviceManagementStatus: SMAppService.Status) {
        switch serviceManagementStatus {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .unknown
        }
    }
}

public protocol LoginItemServiceManaging: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

public final class ServiceManagementLoginItemService: LoginItemServiceManaging {
    private let appService: SMAppService

    public init(appService: SMAppService = .mainApp) {
        self.appService = appService
    }

    public var status: LoginItemStatus {
        LoginItemStatus(serviceManagementStatus: appService.status)
    }

    public func register() throws {
        try appService.register()
    }

    public func unregister() throws {
        try appService.unregister()
    }

    public func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

- [ ] **Step 2: Implement `LoginItemMenuController.swift`**

```swift
import AppKit

@MainActor
public final class LoginItemMenuController: NSObject {
    private let launchAtLoginItem: NSMenuItem
    private let openSettingsItem: NSMenuItem
    private let service: LoginItemServiceManaging
    private let logger: (String) -> Void

    public init(
        launchAtLoginItem: NSMenuItem,
        openSettingsItem: NSMenuItem,
        service: LoginItemServiceManaging = ServiceManagementLoginItemService(),
        logger: @escaping (String) -> Void = { NSLog("%@", $0) }
    ) {
        self.launchAtLoginItem = launchAtLoginItem
        self.openSettingsItem = openSettingsItem
        self.service = service
        self.logger = logger
        super.init()
        configureMenuItems()
        refresh()
    }

    public func refresh() {
        switch service.status {
        case .enabled:
            launchAtLoginItem.state = .on
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = nil
            openSettingsItem.isHidden = true
        case .notRegistered:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = nil
            openSettingsItem.isHidden = true
        case .requiresApproval:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = "Allow iMon in Login Items settings to launch at login."
            openSettingsItem.isHidden = false
        case .notFound:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = false
            launchAtLoginItem.toolTip = "Launch at login is available from the packaged app."
            openSettingsItem.isHidden = true
        case .unknown:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = "Review iMon in Login Items settings to confirm launch at login."
            openSettingsItem.isHidden = false
        }
    }

    @objc public func toggleLaunchAtLogin(_ sender: Any?) {
        switch service.status {
        case .enabled:
            do {
                try service.unregister()
            } catch {
                logger("Unable to disable launch at login: \(error)")
            }
        case .notRegistered:
            do {
                try service.register()
            } catch {
                logger("Unable to enable launch at login: \(error)")
            }
        case .requiresApproval:
            service.openSystemSettingsLoginItems()
        case .notFound:
            break
        case .unknown:
            service.openSystemSettingsLoginItems()
        }

        refresh()
    }

    @objc public func openLoginItemsSettings(_ sender: Any?) {
        service.openSystemSettingsLoginItems()
        refresh()
    }

    private func configureMenuItems() {
        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin(_:))

        openSettingsItem.title = "Open Login Items Settings..."
        openSettingsItem.target = self
        openSettingsItem.action = #selector(openLoginItemsSettings(_:))
    }
}
```

- [ ] **Step 3: Run test to verify GREEN**

Run:

```bash
swift run iMonCoreSelfTests
```

Expected: PASS for all existing and new self-tests.

---

### Task 3: Wire The Status Menu

**Files:**
- Modify: `Sources/iMon/main.swift`

**Interfaces:**
- Consumes: `LoginItemMenuController`, `ServiceManagementLoginItemService`, and existing `MenuBarController`.
- Produces: visible `Launch at Login` and conditional `Open Login Items Settings...` status menu items.

- [ ] **Step 1: Add menu item properties and controller injection**

Change the class declaration from:

```swift
@MainActor
final class MenuBarController: NSObject {
```

to:

```swift
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
```

Add these stored properties after `private let downloadToggleItem = NSMenuItem()`:

```swift
private let loginItemToggleItem: NSMenuItem
private let openLoginItemsSettingsItem: NSMenuItem
private let loginItemMenuController: LoginItemMenuController
```

Replace the initializer signature with:

```swift
init(
    statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
    sampler: SystemSampler = .live(),
    settingsStore: MenuBarDisplaySettingsStore = MenuBarDisplaySettingsStore(),
    loginItemService: LoginItemServiceManaging = ServiceManagementLoginItemService()
) {
```

Replace the initializer body before `super.init()` with:

```swift
self.statusItem = statusItem
self.sampler = sampler
self.settingsStore = settingsStore
self.settings = settingsStore.load()
let loginItemToggleItem = NSMenuItem()
let openLoginItemsSettingsItem = NSMenuItem()
self.loginItemToggleItem = loginItemToggleItem
self.openLoginItemsSettingsItem = openLoginItemsSettingsItem
self.loginItemMenuController = LoginItemMenuController(
    launchAtLoginItem: loginItemToggleItem,
    openSettingsItem: openLoginItemsSettingsItem,
    service: loginItemService
)
```

- [ ] **Step 2: Add login item items to the menu**

In `configureMenu()`, add this immediately after `statusItem.menu = menu`:

```swift
menu.delegate = self
```

Replace the final separator plus quit item:

```swift
menu.addItem(NSMenuItem.separator())
menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
```

with:

```swift
menu.addItem(NSMenuItem.separator())
menu.addItem(MenuBarMenuItemFactory.sectionTitle("App"))
menu.addItem(loginItemToggleItem)
menu.addItem(openLoginItemsSettingsItem)
menu.addItem(NSMenuItem.separator())
menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
```

Remove the old direct separator plus quit item so there is only one quit item.

- [ ] **Step 3: Refresh ServiceManagement status when the menu opens**

Add this method to `MenuBarController`:

```swift
func menuWillOpen(_ menu: NSMenu) {
    loginItemMenuController.refresh()
}
```

- [ ] **Step 4: Run build and tests**

Run:

```bash
swift run iMonCoreSelfTests
swift build
```

Expected: both pass.

---

### Task 4: Documentation

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: final app behavior.
- Produces: user-facing launch-at-login documentation.

- [ ] **Step 1: Update README scope and packaged app section**

Change the packaged app section to mention launch at login:

```markdown
The packaged app is created at `dist/iMon.app`. It is ad-hoc signed for local use, but it is not notarized. Launch at login is available from the packaged app through the status menu's `Launch at Login` item; the `swift run iMon` development executable is not a signed app bundle for login item registration.
```

Move `Login items` from out of scope to implemented scope:

```markdown
- User-controlled launch at login for the packaged app
```

- [ ] **Step 2: Run documentation consistency search**

Run:

```bash
rg -n "Login items|Launch at Login|launch at login|Out of scope" README.md docs Sources scripts
```

Expected: README no longer says login items are out of scope; docs/spec references are consistent.

---

### Task 5: Final Verification And Commit

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run automated verification**

Run:

```bash
swift run iMonCoreSelfTests
swift build
git diff --check
```

Expected: 49 self-tests pass, build passes, diff check has no output.

- [ ] **Step 2: Package the app**

Run:

```bash
./scripts/package_app.sh
```

Expected: `dist/iMon.app` is built and ad-hoc signed. Do not auto-register the login item during packaging.

- [ ] **Step 3: Inspect diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only the planned files changed.

- [ ] **Step 4: Commit implementation on the worktree branch**

Run:

```bash
git add Sources/iMonApp/LoginItemService.swift Sources/iMonApp/LoginItemMenuController.swift Sources/iMon/main.swift Sources/iMonCoreSelfTests/main.swift README.md docs/superpowers/plans/2026-07-01-imon-launch-at-login.md
git commit -m "feat: add launch at login"
```

Expected: implementation commit on `feature/launch-at-login`.
