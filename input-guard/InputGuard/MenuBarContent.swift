import AppKit
import Sparkle
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let device = model.defaultInput {
            Text("Input: \(device.name)")
        } else {
            Text("No input device")
        }

        Divider()

        Button("Manage Excluded Devices…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Check for Updates…") {
            updaterController.checkForUpdates(nil)
        }

        Divider()

        Button("Quit Input Guard") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
