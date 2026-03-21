import SwiftUI

struct RhythmMatchingFeedbackView: View {
    let offsetPercentage: Double?

    enum FeedbackBand {
        case precise
        case moderate
        case erratic
    }

    var body: some View {
        if let offsetPercentage {
            let band = Self.band(offsetPercentage: offsetPercentage)
            HStack(spacing: 4) {
                Image(systemName: Self.arrowSymbolName(offsetPercentage: offsetPercentage))
                    .foregroundStyle(Self.feedbackColor(band: band))
                    .accessibilityRemoveTraits(.isImage)
                Text(Self.feedbackText(offsetPercentage: offsetPercentage))
                    .foregroundStyle(Self.feedbackColor(band: band))
            }
            .font(.title2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(offsetPercentage: offsetPercentage))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                Text("0% " + String(localized: "late"))
            }
            .font(.title2)
            .hidden()
        }
    }

    // MARK: - Static Methods

    static func band(offsetPercentage: Double) -> FeedbackBand {
        let absolute = abs(offsetPercentage)
        if absolute <= 5 {
            return .precise
        } else if absolute <= 15 {
            return .moderate
        } else {
            return .erratic
        }
    }

    static func feedbackColor(band: FeedbackBand) -> Color {
        switch band {
        case .precise: .green
        case .moderate: .yellow
        case .erratic: .red
        }
    }

    static func arrowSymbolName(offsetPercentage: Double) -> String {
        let rounded = Int(offsetPercentage.rounded())
        if rounded < 0 {
            return "arrow.left"
        } else if rounded > 0 {
            return "arrow.right"
        } else {
            return "circle.fill"
        }
    }

    static func feedbackText(offsetPercentage: Double) -> String {
        let rounded = Int(offsetPercentage.rounded())
        if rounded < 0 {
            return "\(abs(rounded))% " + String(localized: "early")
        } else if rounded > 0 {
            return "\(rounded)% " + String(localized: "late")
        } else {
            return String(localized: "On the beat")
        }
    }

    static func accessibilityLabel(offsetPercentage: Double) -> String {
        let rounded = Int(offsetPercentage.rounded())
        if rounded < 0 {
            return "\(abs(rounded)) " + String(localized: "percent early")
        } else if rounded > 0 {
            return "\(rounded) " + String(localized: "percent late")
        } else {
            return String(localized: "On the beat")
        }
    }
}

// MARK: - Previews

#Preview("Early (-3%)") {
    RhythmMatchingFeedbackView(offsetPercentage: -3)
        .padding()
}

#Preview("Late (+8%)") {
    RhythmMatchingFeedbackView(offsetPercentage: 8)
        .padding()
}

#Preview("On the beat") {
    RhythmMatchingFeedbackView(offsetPercentage: 0)
        .padding()
}

#Preview("No Feedback (nil)") {
    RhythmMatchingFeedbackView(offsetPercentage: nil)
        .padding()
}
