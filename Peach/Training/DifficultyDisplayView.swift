import SwiftUI

/// Displays current training difficulty and session best cent difference
///
/// Positioned at the top of the Training Screen body, above the Higher/Lower buttons.
/// Uses secondary styling (footnote font, muted color) to remain visually subordinate.
struct DifficultyDisplayView: View {
    let currentDifficulty: Double
    let sessionBest: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Current: \(Self.formattedDifficulty(currentDifficulty)) ¢")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Current difficulty: \(Self.formattedDifficulty(currentDifficulty)) cents"))

            if let best = sessionBest {
                Text("Session best: \(Self.formattedDifficulty(best)) ¢")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Session best: \(Self.formattedDifficulty(best)) cents"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting (extracted for testability)

    static func formattedDifficulty(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func currentDifficultyAccessibilityLabel(_ value: Double) -> String {
        "Current difficulty: \(formattedDifficulty(value)) cents"
    }

    static func sessionBestAccessibilityLabel(_ value: Double) -> String {
        "Session best: \(formattedDifficulty(value)) cents"
    }
}
