# iMon Launch At Login Design

## Goal

Add a user-controlled "Launch at Login" capability for iMon using Apple's current macOS ServiceManagement API.

The feature must keep iMon as a normal menu bar application. It must not install LaunchAgent files, add a separate helper application, or silently enable startup without explicit user action.

## First Principles

At login, macOS can launch user-approved apps and services in the logged-in user's session. iMon is an interactive status bar app, not a daemon. Therefore the correct startup object is the main application as a login item, not a root daemon, background LaunchAgent, or bundled helper.

The user owns startup behavior. iMon should expose a clear menu toggle, reflect the system's current ServiceManagement status, and leave final approval to macOS System Settings when the system requires it.

## Apple API Direction

Use `SMAppService.mainApp` from ServiceManagement. The installed macOS SDK documents this service as the ServiceManagement object that configures the main application to launch at login.

Important constraints from Apple's headers and documentation:

- `SMLoginItemSetEnabled` is deprecated as of macOS 13 in favor of `SMAppService`.
- `SMAppService` APIs require the app to be code signed.
- `SMAppService.mainApp.register()` launches the main app on subsequent logins.
- `SMAppService.mainApp.unregister()` prevents future launch-at-login runs while leaving the current app process running.
- `SMAppService.mainApp.status` can return not registered, enabled, requires approval, or not found.
- `SMAppService.openSystemSettingsLoginItems()` is the supported way to guide users back to the Login Items settings panel.

iMon already has a macOS 13 minimum deployment target, so no older fallback API is needed.

## Confirmed UX

Add a menu item in the status menu:

- `Launch at Login`

The item is a checkbox:

- On when ServiceManagement reports the main app login item is enabled.
- Off when it is not registered.
- Off and still actionable when status is requires approval.
- Disabled when the app is not running as a signed `.app` bundle or ServiceManagement reports not found.

When the user turns the item on, iMon calls `SMAppService.mainApp.register()`.

When the user turns the item off, iMon calls `SMAppService.mainApp.unregister()`.

If ServiceManagement reports `requiresApproval`, iMon adds a secondary menu item:

- `Open Login Items Settings...`

That item calls `SMAppService.openSystemSettingsLoginItems()`.

If register or unregister fails, iMon keeps running, refreshes the visible menu state from ServiceManagement, and logs the error with `NSLog`.

## Architecture

Add a small testable login item layer in `iMonApp`:

- `LoginItemStatus`: app-facing status enum independent of ServiceManagement types.
- `LoginItemServiceManaging`: protocol with `status`, `register()`, `unregister()`, and `openSystemSettingsLoginItems()`.
- `ServiceManagementLoginItemService`: production adapter around `SMAppService.mainApp`.
- `LoginItemMenuController`: menu state/action coordinator that can be tested with a fake service.

Keep `Sources/iMon/main.swift` responsible for assembling menu items and delegating login item behavior to the controller. Keep metric display settings separate from launch-at-login state; startup registration is system state, not a `UserDefaults` preference.

## Packaging

The packaged app must remain code signed. The current `scripts/package_app.sh` ad-hoc signs `dist/iMon.app`, which is enough for local development. The README should explain that launch-at-login is meaningful for the packaged `.app`, not `swift run iMon`.

No entitlements, LaunchAgent plist, daemon plist, or helper bundle are required for this feature.

## Error Handling

The menu state is always derived from ServiceManagement status. iMon does not cache an intended login item state.

Register failures:

- Log `Unable to enable launch at login: <error>`.
- Refresh menu state.
- If the refreshed status is requires approval, show the System Settings item.

Unregister failures:

- Log `Unable to disable launch at login: <error>`.
- Refresh menu state.

Unavailable state:

- If the app is not in a usable bundle/signing state, disable `Launch at Login`.
- Keep `Quit iMon` available.

## Testing

Use the executable self-test target and fake the ServiceManagement adapter.

Coverage:

- The menu item is checked when status is enabled.
- The menu item is unchecked when status is not registered.
- Toggling from off calls `register()`.
- Toggling from on calls `unregister()`.
- Requires-approval status shows `Open Login Items Settings...` and that item calls `openSystemSettingsLoginItems()`.
- Not-found status disables the launch-at-login menu item.
- Register/unregister errors do not crash and cause a status refresh.

Manual verification:

- Run `swift run iMonCoreSelfTests`.
- Run `swift build`.
- Package with `./scripts/package_app.sh`.
- Open `dist/iMon.app`, toggle `Launch at Login`, and confirm it appears under System Settings > General > Login Items.
- Toggle it off and confirm it is removed or disabled for future logins.

## Out Of Scope

- Enabling launch at login automatically on first launch.
- Supporting macOS 12 or older login item APIs.
- Adding a helper login item bundle.
- Installing LaunchAgent or LaunchDaemon plists.
- Notarization or distribution signing beyond the current local ad-hoc signing flow.

## References

- Apple Developer Documentation: [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice)
- Apple Developer Documentation: [`SMAppService.mainApp`](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
- Apple Developer Documentation: [`SMAppService.register()`](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29)
- Apple Developer Documentation: [`SMAppService.openSystemSettingsLoginItems()`](https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems%28%29)
- Local SDK verification: `ServiceManagement.framework/Headers/SMAppService.h` in the installed macOS 26.5 SDK.
