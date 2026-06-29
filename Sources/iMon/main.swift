import AppKit
import Foundation
import iMonApp
import iMonCore

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let sampler: SystemSampler
    private let settingsStore: MenuBarDisplaySettingsStore
    private let menu = NSMenu()
    private let cpuToggleItem = NSMenuItem()
    private let memoryToggleItem = NSMenuItem()
    private let uploadToggleItem = NSMenuItem()
    private let downloadToggleItem = NSMenuItem()
    private let diskToggleItem = NSMenuItem()
    private let cpuItem = NSMenuItem()
    private let memoryItem = NSMenuItem()
    private let diskItem = NSMenuItem()
    private let uploadItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private var settings: MenuBarDisplaySettings
    private var latestSnapshot: SystemSnapshot?
    private var timer: Timer?

    init(
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        sampler: SystemSampler = .live(),
        settingsStore: MenuBarDisplaySettingsStore = MenuBarDisplaySettingsStore()
    ) {
        self.statusItem = statusItem
        self.sampler = sampler
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
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

        configureToggle(cpuToggleItem, title: "Show CPU in Menu Bar", action: #selector(toggleCPU))
        configureToggle(memoryToggleItem, title: "Show Memory in Menu Bar", action: #selector(toggleMemory))
        configureToggle(uploadToggleItem, title: "Show Upload in Menu Bar", action: #selector(toggleUpload))
        configureToggle(downloadToggleItem, title: "Show Download in Menu Bar", action: #selector(toggleDownload))
        configureToggle(diskToggleItem, title: "Show Disk in Menu Bar", action: #selector(toggleDisk))

        menu.addItem(MenuBarMenuItemFactory.sectionTitle("Menu Bar"))
        menu.addItem(cpuToggleItem)
        menu.addItem(memoryToggleItem)
        menu.addItem(uploadToggleItem)
        menu.addItem(downloadToggleItem)
        menu.addItem(diskToggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(MenuBarMenuItemFactory.sectionTitle("Details"))
        menu.addItem(cpuItem)
        menu.addItem(memoryItem)
        menu.addItem(diskItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(uploadItem)
        menu.addItem(downloadItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit iMon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        updateToggleStates()
    }

    private func configureToggle(_ item: NSMenuItem, title: String, action: Selector) {
        item.title = title
        item.target = self
        item.action = action
    }

    @objc private func toggleCPU() {
        toggle(.cpu)
    }

    @objc private func toggleMemory() {
        toggle(.memory)
    }

    @objc private func toggleUpload() {
        toggle(.upload)
    }

    @objc private func toggleDownload() {
        toggle(.download)
    }

    @objc private func toggleDisk() {
        toggle(.disk)
    }

    private func toggle(_ metric: MenuBarDisplayMetric) {
        settings.toggle(metric)
        settingsStore.save(settings)
        updateToggleStates()
        if let latestSnapshot {
            renderTitle(for: latestSnapshot)
        }
    }

    private func updateToggleStates() {
        cpuToggleItem.state = settings.showsCPU ? .on : .off
        memoryToggleItem.state = settings.showsMemory ? .on : .off
        uploadToggleItem.state = settings.showsUpload ? .on : .off
        downloadToggleItem.state = settings.showsDownload ? .on : .off
        diskToggleItem.state = settings.showsDisk ? .on : .off
    }

    private func update() {
        let snapshot = sampler.sample()
        latestSnapshot = snapshot
        renderTitle(for: snapshot)
        updateDetailItems(for: snapshot)
    }

    private func renderTitle(for snapshot: SystemSnapshot) {
        let title = MenuBarTitleFormatter.stackedTitle(for: snapshot, settings: settings)
        let attributedTitle = MenuBarAttributedTitleFactory.attributedTitle(for: title)
        statusItem.length = MenuBarAttributedTitleFactory.statusItemLength(for: attributedTitle)
        statusItem.button?.title = ""
        statusItem.button?.alignment = .center
        statusItem.button?.attributedTitle = attributedTitle
    }

    private func updateDetailItems(for snapshot: SystemSnapshot) {
        cpuItem.title = "CPU: \(MetricFormatter.percent(snapshot.cpu.active))"
        memoryItem.title = "Memory: \(MetricFormatter.percent(snapshot.memory.percentage)) (\(MetricFormatter.bytes(snapshot.memory.usedBytes)) / \(MetricFormatter.bytes(snapshot.memory.totalBytes)))"
        diskItem.title = "Disk: \(MetricFormatter.percent(snapshot.disk.percentage)) (\(MetricFormatter.bytes(snapshot.disk.usedBytes)) / \(MetricFormatter.bytes(snapshot.disk.totalBytes)))"
        uploadItem.title = "Upload: \(MetricFormatter.rate(snapshot.network.transmitBytesPerSecond))"
        downloadItem.title = "Download: \(MetricFormatter.rate(snapshot.network.receiveBytesPerSecond))"
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
