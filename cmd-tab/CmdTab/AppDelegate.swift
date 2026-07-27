import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let switcher = AppSwitcherController()
    private var statusItem: NSStatusItem!
    private var permissionRetryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureInitialLoginItemIfNeeded()
        requestAccessibilityAndStart()
    }

    func applicationWillTerminate(_ notification: Notification) {
        switcher.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "Cmd Tab")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let trusted = AXIsProcessTrusted()
        let status = NSMenuItem(title: trusted ? "Cmd+Tab replacement is active" : "Accessibility access required", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if !trusted {
            let settings = NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Cmd Tab", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func requestAccessibilityAndStart() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        tryStartingSwitcher()

        permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tryStartingSwitcher()
        }
    }

    private func tryStartingSwitcher() {
        guard AXIsProcessTrusted() else { return }
        if switcher.start() {
            permissionRetryTimer?.invalidate()
            permissionRetryTimer = nil
        }
    }

    private func configureInitialLoginItemIfNeeded() {
        let key = "configuredLoginItem"
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }
}
