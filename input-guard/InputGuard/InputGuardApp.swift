import Sparkle
import SwiftUI

@main
struct InputGuardApp: App {
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
            Label("Input Guard", systemImage: model.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)

        Window("Input Guard", id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 520, height: 560)
        .windowResizability(.contentMinSize)
    }
}
