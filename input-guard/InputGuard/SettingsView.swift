import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            deviceList
            Divider()
            footer
        }
        .frame(minWidth: 460, minHeight: 440)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input Guard", systemImage: "mic.badge.xmark")
                .font(.title2.bold())
            Text("Excluded devices are never allowed to remain the system default input while protection is enabled.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var deviceList: some View {
        Group {
            if model.devices.isEmpty {
                ContentUnavailableView(
                    "No Input Devices",
                    systemImage: "mic.slash",
                    description: Text("Connect an audio input device to configure it.")
                )
            } else {
                List(model.devices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: model.defaultInputID == device.id,
                        isExcluded: Binding(
                            get: { model.isExcluded(device) },
                            set: { model.setExcluded($0, device: device) }
                        )
                    )
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                "Start Input Guard at login",
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
        }
        .padding(20)
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isDefault: Bool
    @Binding var isExcluded: Bool

    var body: some View {
        Toggle(isOn: $isExcluded) {
            HStack(spacing: 12) {
                Image(systemName: isExcluded ? "mic.slash.fill" : "mic.fill")
                    .foregroundStyle(isExcluded ? .red : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                    if isDefault {
                        Text("Current default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 5)
        .help(isExcluded ? "Allow this device as the default input" : "Exclude this device from becoming the default input")
    }
}
