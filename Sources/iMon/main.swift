import AppKit
import Foundation
import iMonCore

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let sampler: SystemSampler
    private let menu = NSMenu()
    private let cpuItem = NSMenuItem()
    private let memoryItem = NSMenuItem()
    private let diskItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private let uploadItem = NSMenuItem()
    private var timer: Timer?

    init(
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        sampler: SystemSampler = .live()
    ) {
        self.statusItem = statusItem
        self.sampler = sampler
        super.init()
        configureMenu()
    }

    func start() {
        guard timer == nil else {
            return
        }

        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func configureMenu() {
        statusItem.button?.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.title = "iMon"
        statusItem.menu = menu

        menu.addItem(cpuItem)
        menu.addItem(memoryItem)
        menu.addItem(diskItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(downloadItem)
        menu.addItem(uploadItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func update() {
        let snapshot = sampler.sample()
        statusItem.button?.title = MetricFormatter.menuTitle(for: snapshot)
        cpuItem.title = "CPU: \(MetricFormatter.percent(snapshot.cpu.active))"
        memoryItem.title = "Memory: \(MetricFormatter.percent(snapshot.memory.percentage)) (\(MetricFormatter.bytes(snapshot.memory.usedBytes)) / \(MetricFormatter.bytes(snapshot.memory.totalBytes)))"
        diskItem.title = "Disk: \(MetricFormatter.percent(snapshot.disk.percentage)) (\(MetricFormatter.bytes(snapshot.disk.usedBytes)) / \(MetricFormatter.bytes(snapshot.disk.totalBytes)))"
        downloadItem.title = "Download: \(MetricFormatter.rate(snapshot.network.receiveBytesPerSecond))"
        uploadItem.title = "Upload: \(MetricFormatter.rate(snapshot.network.transmitBytesPerSecond))"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !NSApp.setActivationPolicy(.accessory) {
            NSLog("iMon could not switch to accessory activation policy")
        }
        controller = MenuBarController()
        controller?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
