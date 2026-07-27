import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let device = model.defaultInput {
            Text("Input: \(device.name)")
        } else {
            Text("No input device")
        }

        Toggle("Protect default input", isOn: $model.protectionEnabled)

        Divider()

        Button("Manage Excluded Devices…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit Input Guard") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
