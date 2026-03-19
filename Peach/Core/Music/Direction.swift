import Foundation

enum Direction: Int, Hashable, Comparable, Sendable, CaseIterable, Codable {
    case up = 0
    case down = 1

    var displayName: String {
        switch self {
        case .up: String(localized: "Up")
        case .down: String(localized: "Down")
        }
    }

    static func < (lhs: Direction, rhs: Direction) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
