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
