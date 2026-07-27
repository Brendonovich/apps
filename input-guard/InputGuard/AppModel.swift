import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultInputID: AudioDevice.ID?
    @Published private(set) var excludedUIDs: Set<String>
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginItemNeedsApproval = false
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let audio = AudioDeviceController()
    private var lastAllowedUID: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        excludedUIDs = Set(defaults.stringArray(forKey: Keys.excludedUIDs) ?? [])
        lastAllowedUID = defaults.string(forKey: Keys.lastAllowedUID)

        audio.onChange = { [weak self] in self?.refresh() }
        refresh()
        configureInitialLoginItemIfNeeded()
        refreshLoginItemStatus()
    }

    var defaultInput: AudioDevice? {
        devices.first { $0.id == defaultInputID }
    }

    var menuBarIcon: String {
        "mic.badge.xmark"
    }

    func isExcluded(_ device: AudioDevice) -> Bool {
        excludedUIDs.contains(device.uid)
    }

    func setExcluded(_ excluded: Bool, device: AudioDevice) {
        if excluded {
            excludedUIDs.insert(device.uid)
        } else {
            excludedUIDs.remove(device.uid)
        }
        defaults.set(Array(excludedUIDs).sorted(), forKey: Keys.excludedUIDs)
        enforceAllowedDefault()
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

    func refresh() {
        devices = audio.inputDevices()
        defaultInputID = audio.defaultInputID()

        guard let current = defaultInput else { return }
        if !excludedUIDs.contains(current.uid) {
            lastAllowedUID = current.uid
            defaults.set(current.uid, forKey: Keys.lastAllowedUID)
            return
        }
        enforceAllowedDefault()
    }

    private func enforceAllowedDefault() {
        guard let current = defaultInput,
              excludedUIDs.contains(current.uid) else { return }

        let allowed = devices.filter { !excludedUIDs.contains($0.uid) }
        guard let fallback = allowed.first(where: { $0.uid == lastAllowedUID }) ?? allowed.first else {
            lastError = "No allowed input device is available."
            return
        }
        guard audio.setDefaultInput(fallback.id) else {
            lastError = "Could not change the default input device."
            return
        }
        defaultInputID = fallback.id
        lastAllowedUID = fallback.uid
        defaults.set(fallback.uid, forKey: Keys.lastAllowedUID)
        lastError = nil
    }

    private func configureInitialLoginItemIfNeeded() {
        guard defaults.object(forKey: Keys.configuredLoginItem) == nil else { return }
        defaults.set(true, forKey: Keys.configuredLoginItem)
        do {
            try SMAppService.mainApp.register()
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
        static let excludedUIDs = "excludedDeviceUIDs"
        static let lastAllowedUID = "lastAllowedDeviceUID"
        static let configuredLoginItem = "configuredLoginItem"
    }
}
