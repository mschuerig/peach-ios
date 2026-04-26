import Foundation

extension TrainingCategory {
    /// Localized section header used by ``StartScreen`` and ``PeachCommands``
    /// when grouping disciplines by category.
    var localizedTitle: String {
        switch self {
        case .pitch:     String(localized: "Pitch")
        case .intervals: String(localized: "Intervals")
        case .rhythm:    String(localized: "Rhythm")
        }
    }
}
