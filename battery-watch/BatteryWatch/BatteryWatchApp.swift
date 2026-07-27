import SwiftUI

@main
struct BatteryWatchApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
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
