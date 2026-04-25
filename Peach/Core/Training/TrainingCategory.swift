import Foundation

/// Display partition for grouping training disciplines in lists and menus.
/// Each discipline declares its category alongside its identifier.
enum TrainingCategory: String, CaseIterable, Sendable {
    case pitch
    case intervals
    case rhythm
}
