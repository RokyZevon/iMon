import Foundation
import ServiceManagement

public enum LoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    public init(serviceManagementStatus: SMAppService.Status) {
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
            self = .notFound
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
