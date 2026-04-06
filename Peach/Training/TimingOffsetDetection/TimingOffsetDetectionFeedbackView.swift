import SwiftUI

struct TimingOffsetDetectionFeedbackView: View {
    let isCorrect: Bool?
    let offsetPercentage: Double?

    var body: some View {
        if let isCorrect, let offsetPercentage {
            HStack(spacing: 6) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? .green : .red)
                Text(Self.percentageText(offsetPercentage))
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(isCorrect: isCorrect, offsetPercentage: offsetPercentage))
            .accessibilityRemoveTraits(.isImage)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("0%")
                    .foregroundStyle(.secondary)
            }
            .font(.title2)
            .hidden()
        }
    }

    // MARK: - Formatting (extracted for testability)

    static func percentageText(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func accessibilityLabel(isCorrect: Bool, offsetPercentage: Double) -> String {
        let correctness = isCorrect ? String(localized: "Correct") : String(localized: "Incorrect")
        let percentage = String(format: "%.0f", offsetPercentage)
        return "\(correctness), \(percentage) " + String(localized: "percent")
    }
}

// MARK: - Previews

#Preview("Correct") {
    TimingOffsetDetectionFeedbackView(isCorrect: true, offsetPercentage: 4)
        .padding()
}

#Preview("Incorrect") {
    TimingOffsetDetectionFeedbackView(isCorrect: false, offsetPercentage: 12)
        .padding()
}

#Preview("No Feedback") {
    TimingOffsetDetectionFeedbackView(isCorrect: nil, offsetPercentage: nil)
        .padding()
}
