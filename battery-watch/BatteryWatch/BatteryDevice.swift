import Foundation

struct BatteryDevice: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case iPhone
        case airPods
    }

    let id: String
    let name: String
    let component: String?
    let level: Int
    let isCharging: Bool?
    let kind: Kind
    let isConnected: Bool

    var displayName: String {
        guard let component else { return name }
        return "\(name) \(component)"
    }

    var symbolName: String {
        switch kind {
        case .iPhone: "iphone"
        case .airPods: "airpodspro"
        }
    }
}
