import SwiftUI

struct RhythmTimingFeedbackIndicator: View {
    let offsetMs: Double?
    let tempo: TempoBPM

    var body: some View {
        if let offsetMs {
            let level = Self.accuracyLevel(offsetMs: offsetMs, tempo: tempo)
            let color = Self.feedbackColor(level: level)
            HStack(spacing: 4) {
                Image(systemName: Self.arrowSymbolName(offsetMs: offsetMs))
                    .font(.title2)
                    .foregroundStyle(color)
                    .accessibilityRemoveTraits(.isImage)

                Text(Self.offsetText(offsetMs: offsetMs))
                    .font(.title2)
                    .foregroundStyle(color)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(offsetMs: offsetMs))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.title2)
                Text("0 " + String(localized: "ms"))
                    .font(.title2)
            }
            .hidden()
        }
    }

    // MARK: - Static Methods

    static func arrowSymbolName(offsetMs: Double) -> String {
        let rounded = offsetMs.rounded()
        if rounded < 0 {
            return "arrow.left"
        } else if rounded > 0 {
            return "arrow.right"
        } else {
            return "circle.fill"
        }
    }

    static func offsetText(offsetMs: Double) -> String {
        let rounded = abs(Int(offsetMs.rounded()))
        let msUnit = String(localized: "ms")
        return "\(rounded) \(msUnit)"
    }

    static func accuracyLevel(offsetMs: Double, tempo: TempoBPM) -> SpectrogramAccuracyLevel {
        let absMs = abs(offsetMs)
        let sixteenthMs = tempo.sixteenthNoteDuration.timeInterval * 1000.0
        let percentage = (absMs / sixteenthMs) * 100.0
        let tempoRange = TempoRange(lowerBound: tempo, upperBound: tempo)
        return SpectrogramThresholds.default.accuracyLevel(for: percentage, tempoRange: tempoRange) ?? .precise
    }

    static func feedbackColor(level: SpectrogramAccuracyLevel) -> Color {
        switch level {
        case .excellent: Color(hue: 0.45, saturation: 0.7, brightness: 0.7)
        case .precise: .green
        case .moderate: .yellow
        case .loose: .orange
        case .erratic: .red
        }
    }

    static func accessibilityLabel(offsetMs: Double) -> String {
        let rounded = Int(offsetMs.rounded())
        if rounded < 0 {
            return "\(abs(rounded)) " + String(localized: "milliseconds early")
        } else if rounded > 0 {
            return "\(rounded) " + String(localized: "milliseconds late")
        } else {
            return String(localized: "Dead center")
        }
    }
}

// MARK: - Previews

#Preview("Early tap (-5 ms)") {
    RhythmTimingFeedbackIndicator(offsetMs: -5.0, tempo: TempoBPM(120))
        .padding()
}

#Preview("Late tap (+12 ms)") {
    RhythmTimingFeedbackIndicator(offsetMs: 12.0, tempo: TempoBPM(120))
        .padding()
}

#Preview("Dead center (0 ms)") {
    RhythmTimingFeedbackIndicator(offsetMs: 0.0, tempo: TempoBPM(120))
        .padding()
}

#Preview("Far off (+45 ms)") {
    RhythmTimingFeedbackIndicator(offsetMs: 45.0, tempo: TempoBPM(120))
        .padding()
}

#Preview("No feedback (nil)") {
    RhythmTimingFeedbackIndicator(offsetMs: nil, tempo: TempoBPM(120))
        .padding()
}
