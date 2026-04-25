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

    /// Optional localized intro paragraph rendered before this category's
    /// disciplines in the Info screen description. Returns `nil` when no
    /// intro is desired, in which case the generator emits only the
    /// per-discipline paragraphs.
    var localizedIntro: String? { nil }
}
