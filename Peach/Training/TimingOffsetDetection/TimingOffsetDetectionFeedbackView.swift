import SwiftUI

struct TimingOffsetDetectionFeedbackView: View {
    let isCorrect: Bool?
    let offsetMs: Double?

    private var config: TrainingDisciplineConfig { TrainingDisciplineID.timingOffsetDetection.config }

    var body: some View {
        if let isCorrect, let offsetMs {
            HStack(spacing: 6) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? .green : .red)
                Text(TimingOffsetFormatter.compact(offsetMs, unitSymbol: config.unitSymbol))
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(isCorrect: isCorrect, offsetMs: offsetMs, unitLabel: config.unitLabel))
            .accessibilityRemoveTraits(.isImage)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text(TimingOffsetFormatter.compact(0, unitSymbol: config.unitSymbol))
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .hidden()
        }
    }

    // MARK: - Formatting (extracted for testability)

    static func accessibilityLabel(isCorrect: Bool, offsetMs: Double, unitLabel: String) -> String {
        let correctness = isCorrect ? String(localized: "Correct") : String(localized: "Incorrect")
        return "\(correctness), \(TimingOffsetFormatter.spoken(offsetMs, unitLabel: unitLabel))"
    }
}

// MARK: - Previews

#Preview("Correct") {
    TimingOffsetDetectionFeedbackView(isCorrect: true, offsetMs: 12)
        .padding()
}

#Preview("Incorrect") {
    TimingOffsetDetectionFeedbackView(isCorrect: false, offsetMs: 38)
        .padding()
}

#Preview("No Feedback") {
    TimingOffsetDetectionFeedbackView(isCorrect: nil, offsetMs: nil)
        .padding()
}
