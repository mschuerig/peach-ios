import SwiftUI

struct PitchMatchingFeedbackIndicator: View {
    let centError: Cents?

    enum FeedbackBand {
        case deadCenter
        case close
        case moderate
        case far
    }

    var body: some View {
        if let centError {
            let error = centError.rawValue
            let band = Self.band(centError: error)
            HStack(spacing: 4) {
                Image(systemName: Self.arrowSymbolName(centError: error))
                    .font(.title2)
                    .foregroundStyle(Self.feedbackColor(band: band))
                    .accessibilityRemoveTraits(.isImage)

                Text(Self.centOffsetText(centError: error))
                    .font(.title2)
                    .foregroundStyle(Self.feedbackColor(band: band))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(centError: error))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.title2)
                Text("0 " + String(localized: "cents"))
                    .font(.title2)
            }
            .hidden()
        }
    }

    // MARK: - Static Methods

    static func band(centError: Double) -> FeedbackBand {
        let rounded = abs(centError).rounded()
        if rounded == 0 {
            return .deadCenter
        } else if rounded < 10 {
            return .close
        } else if rounded <= 30 {
            return .moderate
        } else {
            return .far
        }
    }

    static func centOffsetText(centError: Double) -> String {
        let rounded = Int(centError.rounded())
        if rounded > 0 {
            return "+\(rounded) " + String(localized: "cents")
        } else if rounded < 0 {
            return "\(rounded) " + String(localized: "cents")
        } else {
            return "0 " + String(localized: "cents")
        }
    }

    static func arrowSymbolName(centError: Double) -> String {
        let rounded = centError.rounded()
        if rounded > 0 {
            return "arrow.up"
        } else if rounded < 0 {
            return "arrow.down"
        } else {
            return "circle.fill"
        }
    }

    static func feedbackColor(band: FeedbackBand) -> Color {
        switch band {
        case .deadCenter, .close: return .green
        case .moderate: return .yellow
        case .far: return .red
        }
    }

    static func accessibilityLabel(centError: Double) -> String {
        let rounded = Int(centError.rounded())
        if rounded > 0 {
            return "\(rounded) " + String(localized: "cents sharp")
        } else if rounded < 0 {
            return "\(abs(rounded)) " + String(localized: "cents flat")
        } else {
            return String(localized: "Dead center")
        }
    }
}

// MARK: - Previews

#Preview("Dead Center (0 cents)") {
    PitchMatchingFeedbackIndicator(centError: 0.0)
        .padding()
}

#Preview("Close Match (+4 cents)") {
    PitchMatchingFeedbackIndicator(centError: 4.0)
        .padding()
}

#Preview("Moderate Miss (-22 cents)") {
    PitchMatchingFeedbackIndicator(centError: -22.0)
        .padding()
}

#Preview("Far Off (+55 cents)") {
    PitchMatchingFeedbackIndicator(centError: 55.0)
        .padding()
}

#Preview("No Feedback (nil)") {
    PitchMatchingFeedbackIndicator(centError: nil)
        .padding()
}
