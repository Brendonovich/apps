import Combine
import Foundation
import Network
import ServiceManagement
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    static let threshold = 25

    @Published private(set) var devices: [BatteryDevice] = []
    @Published private(set) var isChecking = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginItemNeedsApproval = false

    private let poller = BatteryPoller()
    private let defaults: UserDefaults
    private var alertedDeviceIDs: Set<String> = []
    private var localNetworkBrowser: NWBrowser?
    private var timer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configureInitialLoginItemIfNeeded()
        refreshLoginItemStatus()
        startLocalNetworkDiscovery()
        requestNotificationPermissionAndCheck()

        let timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNow() }
        }
        timer.tolerance = 60
        self.timer = timer
    }

    var lowDevices: [BatteryDevice] {
        devices.filter { $0.level < Self.threshold }
    }

    var menuBarIcon: String {
        if !lowDevices.isEmpty { return "battery.25" }
        return devices.isEmpty ? "battery.0" : "battery.100"
    }

    func checkNow() {
        guard !isChecking else { return }
        isChecking = true

        Task {
            let result = await Task.detached { [poller] in poller.poll() }.value
            devices = result.devices
            lastChecked = Date()
            lastError = result.errors.first
            isChecking = false
            sendLowBatteryNotifications(for: result.devices)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refreshLoginItemStatus()
    }

    private func sendLowBatteryNotifications(for devices: [BatteryDevice]) {
        let currentlyLow = Set(devices.filter { $0.level < Self.threshold }.map(\.id))
        let newLowDevices = devices.filter {
            currentlyLow.contains($0.id) && !alertedDeviceIDs.contains($0.id)
        }

        for device in newLowDevices {
            let content = UNMutableNotificationContent()
            content.title = "Low battery"
            content.body = "\(device.displayName) is at \(device.level)%."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "low-battery:\(device.id)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        alertedDeviceIDs = currentlyLow
    }

    private func requestNotificationPermissionAndCheck() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.checkNow() }
        }
    }

    private func startLocalNetworkDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_apple-mobdev2._tcp", domain: nil),
            using: parameters
        )
        browser.stateUpdateHandler = { [weak self] state in
            guard case .ready = state else { return }
            Task { @MainActor in self?.checkNow() }
        }
        browser.start(queue: .global(qos: .utility))
        localNetworkBrowser = browser
    }

    private func configureInitialLoginItemIfNeeded() {
        guard defaults.object(forKey: Keys.configuredLoginItem) == nil else { return }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: Keys.configuredLoginItem)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshLoginItemStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginItemNeedsApproval = status == .requiresApproval
    }

    private enum Keys {
        static let configuredLoginItem = "configuredLoginItem"
    }
}
