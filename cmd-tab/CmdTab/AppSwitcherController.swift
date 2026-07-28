import AppKit
import ApplicationServices

final class AppSwitcherController {
    private enum KeyCode {
        static let tab: Int64 = 48
        static let q: Int64 = 12
        static let h: Int64 = 4
        static let escape: Int64 = 53
        static let leftArrow: Int64 = 123
        static let rightArrow: Int64 = 124
    }

    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var applications: [NSRunningApplication] = []
    private var recentProcessIDs: [pid_t] = []
    private var selectedIndex = 0
    private var isSwitching = false
    private let panel = SwitcherPanel()
    private var observers: [NSObjectProtocol] = []
    private let windowRestoreAttempts = 10

    init() {
        panel.onSelect = { [weak self] index in
            self?.selectedIndex = index
            self?.panel.updateSelection(index)
        }
        panel.onCommit = { [weak self] index in
            self?.selectedIndex = index
            self?.finish(commit: true)
        }
        observeWorkspace()
    }

    deinit {
        stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<AppSwitcherController>.fromOpaque(userInfo).takeUnretainedValue()
                return controller.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return false }
        eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func stop() {
        if let eventSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let commandDown = event.flags.contains(.maskCommand)
        if type == .flagsChanged, isSwitching, !commandDown {
            finish(commit: true)
            return nil
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == KeyCode.tab, commandDown {
            if type == .keyDown {
                if isSwitching {
                    moveSelection(by: event.flags.contains(.maskShift) ? -1 : 1)
                } else {
                    begin(reverse: event.flags.contains(.maskShift))
                }
            }
            return nil
        }

        guard isSwitching, type == .keyDown else { return Unmanaged.passUnretained(event) }
        switch keyCode {
        case KeyCode.escape:
            finish(commit: false)
            return nil
        case KeyCode.leftArrow:
            moveSelection(by: -1)
            return nil
        case KeyCode.rightArrow:
            moveSelection(by: 1)
            return nil
        case KeyCode.h where commandDown:
            hideSelectedApplication()
            return nil
        case KeyCode.q where commandDown:
            quitSelectedApplication()
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func begin(reverse: Bool) {
        applications = orderedApplications()
        guard applications.count > 1 else { return }
        isSwitching = true
        selectedIndex = reverse ? applications.count - 1 : 1
        panel.show(applications: applications, selectedIndex: selectedIndex)
    }

    private func moveSelection(by offset: Int) {
        guard !applications.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + applications.count) % applications.count
        panel.updateSelection(selectedIndex)
    }

    private func finish(commit: Bool) {
        guard isSwitching else { return }
        isSwitching = false
        panel.hide()
        guard commit, applications.indices.contains(selectedIndex) else { return }
        activateAndOpenWindow(for: applications[selectedIndex])
    }

    private func hideSelectedApplication() {
        guard applications.indices.contains(selectedIndex) else { return }
        applications[selectedIndex].hide()
    }

    private func quitSelectedApplication() {
        guard applications.indices.contains(selectedIndex) else { return }
        let application = applications.remove(at: selectedIndex)
        application.terminate()
        guard !applications.isEmpty else {
            finish(commit: false)
            return
        }
        selectedIndex %= applications.count
        panel.show(applications: applications, selectedIndex: selectedIndex)
    }

    private func activateAndOpenWindow(for application: NSRunningApplication) {
        if application.isHidden {
            moveFrontmostWindowToCurrentSpace(processID: application.processIdentifier)
        }
        application.unhide()
        guard let bundleURL = application.bundleURL, bundleURL.pathExtension == "app" else {
            application.activate(options: [.activateAllWindows])
            restoreOrOpenWindow(for: application, attemptsRemaining: windowRestoreAttempts)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] reopenedApplication, _ in
            guard let self else { return }
            let activeApplication = reopenedApplication ?? application
            activeApplication.activate(options: [.activateAllWindows])
            self.restoreOrOpenWindow(for: activeApplication, attemptsRemaining: self.windowRestoreAttempts)
        }
    }

    private func restoreOrOpenWindow(for application: NSRunningApplication, attemptsRemaining: Int) {
        guard !hasOnScreenWindow(processID: application.processIdentifier) else { return }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXHiddenAttribute as CFString, kCFBooleanFalse)

        if let window = windows(of: appElement).first {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }

        guard attemptsRemaining > 0 else {
            if hasWindowOnAnySpace(processID: application.processIdentifier) {
                application.activate(options: [.activateAllWindows])
            } else {
                sendNewWindowShortcut(to: application.processIdentifier)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.restoreOrOpenWindow(for: application, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func windows(of application: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    private func sendNewWindowShortcut(to processID: pid_t) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 45, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 45, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(processID)
        keyUp.postToPid(processID)
    }

    private func hasOnScreenWindow(processID: pid_t) -> Bool {
        let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windowInfo.contains { isRegularWindow($0, ownedBy: processID) }
    }

    private func hasWindowOnAnySpace(processID: pid_t) -> Bool {
        let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windowInfo.contains { isRegularWindow($0, ownedBy: processID) }
    }

    private func moveFrontmostWindowToCurrentSpace(processID: pid_t) {
        typealias MainConnectionID = @convention(c) () -> UInt32
        typealias GetActiveSpace = @convention(c) (UInt32) -> UInt64
        typealias MoveWindows = @convention(c) (UInt32, CFArray, UInt64) -> Void

        let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let windowID = windowInfo.first(where: { isRegularWindow($0, ownedBy: processID) })?[kCGWindowNumber as String] as? NSNumber,
              let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return }
        defer { dlclose(skyLight) }
        guard let mainConnectionSymbol = dlsym(skyLight, "SLSMainConnectionID"),
              let activeSpaceSymbol = dlsym(skyLight, "SLSGetActiveSpace"),
              let moveWindowsSymbol = dlsym(skyLight, "SLSMoveWindowsToManagedSpace") else { return }

        let mainConnectionID = unsafeBitCast(mainConnectionSymbol, to: MainConnectionID.self)
        let getActiveSpace = unsafeBitCast(activeSpaceSymbol, to: GetActiveSpace.self)
        let moveWindows = unsafeBitCast(moveWindowsSymbol, to: MoveWindows.self)
        let connectionID = mainConnectionID()
        moveWindows(connectionID, [windowID] as CFArray, getActiveSpace(connectionID))
    }

    private func isRegularWindow(_ info: [String: Any], ownedBy processID: pid_t) -> Bool {
        let ownerProcessID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue
        return ownerProcessID == processID && layer == 0
    }

    private func orderedApplications() -> [NSRunningApplication] {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ownProcessID
        }
        let byProcessID = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0) })
        var orderedProcessIDs: [pid_t] = []

        if let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            orderedProcessIDs.append(frontmost)
        }
        orderedProcessIDs.append(contentsOf: recentProcessIDs)

        let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        orderedProcessIDs.append(contentsOf: windowInfo.compactMap { info in
            (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        })

        var seen = Set<pid_t>()
        var result = orderedProcessIDs.compactMap { processID -> NSRunningApplication? in
            guard seen.insert(processID).inserted else { return nil }
            return byProcessID[processID]
        }
        let remaining = running.filter { seen.insert($0.processIdentifier).inserted }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        result.append(contentsOf: remaining)
        return result
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.recordActivation(of: application)
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.recentProcessIDs.removeAll { $0 == application.processIdentifier }
        })
    }

    private func recordActivation(of application: NSRunningApplication) {
        let processID = application.processIdentifier
        recentProcessIDs.removeAll { $0 == processID }
        recentProcessIDs.insert(processID, at: 0)

        guard application.activationPolicy == .regular,
              !application.isTerminated,
              processID != ProcessInfo.processInfo.processIdentifier else { return }
        let selectedProcessID = applications.indices.contains(selectedIndex)
            ? applications[selectedIndex].processIdentifier
            : nil
        applications.removeAll { $0.processIdentifier == processID }
        applications.insert(application, at: 0)

        guard isSwitching else { return }
        if let selectedProcessID,
           let index = applications.firstIndex(where: { $0.processIdentifier == selectedProcessID }) {
            selectedIndex = index
        }
        panel.show(applications: applications, selectedIndex: selectedIndex)
    }
}
