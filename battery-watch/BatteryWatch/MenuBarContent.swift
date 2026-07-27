import AppKit
import Sparkle
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.devices.isEmpty {
            Text(model.isChecking ? "Checking devices..." : "No battery data available")
        } else {
            ForEach(model.devices) { device in
                Label {
                    Text("\(device.displayName)  \(device.levelText)")
                } icon: {
                    Image(systemName: device.symbolName)
                }
            }
        }

        Divider()

        Button(model.isChecking ? "Checking..." : "Check Now") {
            model.checkNow()
        }
        .disabled(model.isChecking)

        Button("Settings...") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Check for Updates...") {
            updaterController.checkForUpdates(nil)
        }

        Divider()

        Button("Quit Battery Watch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
