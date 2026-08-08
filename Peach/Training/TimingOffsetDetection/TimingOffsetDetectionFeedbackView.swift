import SwiftUI

struct TimingOffsetDetectionFeedbackView: View {
    let isCorrect: Bool?
    let offsetMs: Double?

    var body: some View {
        if let isCorrect, let offsetMs {
            HStack(spacing: 6) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? .green : .red)
                Text(TimingOffsetFormatter.compact(offsetMs))
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(isCorrect: isCorrect, offsetMs: offsetMs))
            .accessibilityRemoveTraits(.isImage)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text(TimingOffsetFormatter.compact(0))
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .hidden()
        }
    }

    // MARK: - Formatting (extracted for testability)

    static func accessibilityLabel(isCorrect: Bool, offsetMs: Double) -> String {
        let correctness = isCorrect ? String(localized: "Correct") : String(localized: "Incorrect")
        return "\(correctness), \(TimingOffsetFormatter.spoken(offsetMs))"
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
