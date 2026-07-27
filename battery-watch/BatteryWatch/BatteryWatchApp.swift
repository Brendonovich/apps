import Sparkle
import SwiftUI

@main
struct BatteryWatchApp: App {
    @StateObject private var model = AppModel()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model, updaterController: updaterController)
        } label: {
            Label("Battery Watch", systemImage: model.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)

        Window("Battery Watch", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
