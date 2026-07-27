import Foundation

struct PollResult: Sendable {
    let devices: [BatteryDevice]
    let errors: [String]
}

struct BatteryPoller: Sendable {
    func poll() -> PollResult {
        var devices: [BatteryDevice] = []
        var errors: [String] = []

        do {
            devices.append(contentsOf: try iPhones())
        } catch {
            errors.append(error.localizedDescription)
        }

        do {
            devices.append(contentsOf: try airPods())
        } catch {
            errors.append(error.localizedDescription)
        }

        return PollResult(
            devices: devices.sorted {
                let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
                if nameOrder == .orderedSame {
                    return ($0.component ?? "") < ($1.component ?? "")
                }
                return nameOrder == .orderedAscending
            },
            errors: errors
        )
    }

    private func iPhones() throws -> [BatteryDevice] {
        guard let deviceIDPath = executable(named: "idevice_id"),
              let deviceInfoPath = executable(named: "ideviceinfo") else {
            throw PollError.message("Install libimobiledevice with `brew install libimobiledevice` to monitor iPhones.")
        }

        let identifiers = try run(deviceIDPath, ["--network"])
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)

        return identifiers.compactMap { identifier in
            guard let batteryOutput = try? run(deviceInfoPath, [
                "--network", "--udid", identifier, "--domain", "com.apple.mobile.battery"
            ]) else { return nil }

            let battery = keyValues(in: batteryOutput)
            guard let levelString = battery["BatteryCurrentCapacity"],
                  let level = Int(levelString) else { return nil }

            let name = (try? run(deviceInfoPath, [
                "--network", "--udid", identifier, "--key", "DeviceName"
            ]).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "iPhone"

            return BatteryDevice(
                id: "iphone:\(identifier)",
                name: name.isEmpty ? "iPhone" : name,
                component: nil,
                level: level,
                isCharging: battery["BatteryIsCharging"] == "true",
                kind: .iPhone,
                isConnected: true
            )
        }
    }

    private func airPods() throws -> [BatteryDevice] {
        let output = try run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bluetooth = root["SPBluetoothDataType"] as? [[String: Any]] else {
            throw PollError.message("Could not read Bluetooth battery information.")
        }

        var devices: [BatteryDevice] = []
        for controller in bluetooth {
            devices.append(contentsOf: airPods(in: controller["device_connected"], connected: true))
            devices.append(contentsOf: airPods(in: controller["device_not_connected"], connected: false))
        }
        return devices
    }

    private func airPods(in value: Any?, connected: Bool) -> [BatteryDevice] {
        guard let entries = value as? [[String: Any]] else { return [] }

        return entries.flatMap { entry -> [BatteryDevice] in
            guard let name = entry.keys.first,
                  name.localizedCaseInsensitiveContains("airpods"),
                  let properties = entry[name] as? [String: Any] else { return [] }

            let address = properties["device_address"] as? String ?? name
            func level(for key: String) -> Int? {
                guard let rawLevel = properties[key] as? String else { return nil }
                return Int(rawLevel.trimmingCharacters(in: CharacterSet(charactersIn: "%")))
            }

            let leftLevel = level(for: "device_batteryLevelLeft")
            let rightLevel = level(for: "device_batteryLevelRight")
            let caseLevel = level(for: "device_batteryLevelCase")
            var devices: [BatteryDevice] = []

            let earbudLevels = [leftLevel, rightLevel].compactMap { $0 }
            if let lowestEarbudLevel = earbudLevels.min() {
                devices.append(BatteryDevice(
                    id: "airpods:\(address):earbuds",
                    name: name,
                    component: nil,
                    level: lowestEarbudLevel,
                    isCharging: nil,
                    kind: .airPods,
                    isConnected: connected,
                    leftLevel: leftLevel,
                    rightLevel: rightLevel
                ))
            }

            if let caseLevel {
                devices.append(BatteryDevice(
                    id: "airpods:\(address):case",
                    name: name,
                    component: "Case",
                    level: caseLevel,
                    isCharging: nil,
                    kind: .airPods,
                    isConnected: connected
                ))
            }

            return devices
        }
    }

    private func keyValues(in output: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: output.split(whereSeparator: \Character.isNewline).compactMap { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), parts[1].trimmingCharacters(in: .whitespaces))
        })
    }

    private func executable(named name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw PollError.message(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}

private enum PollError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}
