import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.devices.isEmpty {
            Text(model.isChecking ? "Checking devices..." : "No battery data available")
        } else {
            ForEach(model.devices) { device in
                Label {
                    HStack {
                        Text(device.displayName)
                        Spacer()
                        Text("\(device.level)%")
                    }
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

        Divider()

        Button("Quit Battery Watch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
