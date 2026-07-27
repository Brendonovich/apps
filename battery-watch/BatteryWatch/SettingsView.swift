import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Battery Watch", systemImage: "battery.25")
                .font(.title2.bold())

            Text("Checks trusted iPhones and known AirPods every 15 minutes. A notification is sent when a battery drops below \(AppModel.threshold)%.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 10) {
                    if let lastChecked = model.lastChecked {
                        LabeledContent("Last check", value: lastChecked.formatted(date: .omitted, time: .standard))
                    }
                    LabeledContent("Devices found", value: "\(model.devices.count)")
                    LabeledContent("Low batteries", value: "\(model.lowDevices.count)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            Toggle(
                "Start Battery Watch at login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )

            if model.loginItemNeedsApproval {
                HStack {
                    Text("Login item approval is required in System Settings.")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Login Items") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
                .font(.callout)
            }

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Text("AirPods report their latest Bluetooth battery values. Values may remain unchanged while the case is closed or the AirPods are away from this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 480)
    }
}
