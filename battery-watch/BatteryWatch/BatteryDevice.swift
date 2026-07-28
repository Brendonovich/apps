import Foundation

struct BatteryDevice: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case iPhone
        case airPods
        case headphones
    }

    let id: String
    let name: String
    let component: String?
    let level: Int
    let isCharging: Bool?
    let kind: Kind
    let isConnected: Bool
    let leftLevel: Int?
    let rightLevel: Int?

    init(
        id: String,
        name: String,
        component: String?,
        level: Int,
        isCharging: Bool?,
        kind: Kind,
        isConnected: Bool,
        leftLevel: Int? = nil,
        rightLevel: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.component = component
        self.level = level
        self.isCharging = isCharging
        self.kind = kind
        self.isConnected = isConnected
        self.leftLevel = leftLevel
        self.rightLevel = rightLevel
    }

    var displayName: String {
        guard let component else { return name }
        return "\(name) \(component)"
    }

    var symbolName: String {
        switch kind {
        case .iPhone: "iphone"
        case .airPods: "airpodspro"
        case .headphones: "headphones"
        }
    }

    var levelText: String {
        let earbuds = [("L", leftLevel), ("R", rightLevel)].compactMap { side, level in
            level.map { "\(side) \($0)%" }
        }
        return earbuds.isEmpty ? "\(level)%" : "(\(earbuds.joined(separator: ", ")))"
    }
}
