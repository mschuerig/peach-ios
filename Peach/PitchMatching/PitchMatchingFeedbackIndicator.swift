import SwiftUI

struct PitchMatchingFeedbackIndicator: View {
    let centError: Double?

    enum FeedbackBand {
        case deadCenter
        case close
        case moderate
        case far
    }

    private static let defaultIconSize: CGFloat = 100
    private static let closeIconSize: CGFloat = 40
    private static let moderateIconSize: CGFloat = 70
    private static let farIconSize: CGFloat = defaultIconSize

    var body: some View {
        if let centError {
            let band = Self.band(centError: centError)
            VStack(spacing: 4) {
                Image(systemName: Self.arrowSymbolName(centError: centError))
                    .font(.system(size: Self.iconSizeForBand(band)))
                    .foregroundStyle(Self.feedbackColor(band: band))
                    .accessibilityRemoveTraits(.isImage)

                Text(Self.centOffsetText(centError: centError))
                    .font(.title2)
                    .foregroundStyle(Self.feedbackColor(band: band))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(centError: centError))
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

    // MARK: - Private

    private static func iconSizeForBand(_ band: FeedbackBand) -> CGFloat {
        switch band {
        case .deadCenter: return defaultIconSize
        case .close: return closeIconSize
        case .moderate: return moderateIconSize
        case .far: return farIconSize
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
