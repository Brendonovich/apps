import SwiftUI

@main
struct InputGuardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
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
