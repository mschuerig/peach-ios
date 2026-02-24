import SwiftUI
import Charts

struct ProfilePreviewView: View {
    @Environment(\.thresholdTimeline) private var timeline

    var body: some View {
        if timeline.dataPoints.isEmpty {
            EmptyView()
        } else {
            sparklineChart
        }
    }

    private var sparklineChart: some View {
        let means = timeline.rollingMean()

        return Chart {
            ForEach(Array(means.enumerated()), id: \.offset) { _, mean in
                LineMark(
                    x: .value("Time", mean.date),
                    y: .value("Mean", mean.value)
                )
                .foregroundStyle(.tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    var accessibilityLabel: String {
        Self.accessibilityLabel(timeline: timeline)
    }

    static func accessibilityLabel(timeline: ThresholdTimeline) -> String {
        let means = timeline.rollingMean()
        if let lastMean = means.last {
            let rounded = Int(lastMean.value.rounded())
            return String(localized: "Your training progress. Tap to view details. Current threshold: \(rounded) cents.")
        } else {
            return String(localized: "Your training progress. Tap to view details.")
        }
    }
}

#Preview("With Data") {
    ProfilePreviewView()
        .padding(.horizontal)
        .environment(\.thresholdTimeline, {
            let records = (0..<50).map { i in
                let baseOffset = 50.0 - Double(i) * 0.5
                let noise = Double.random(in: -10...10)
                return ComparisonRecord(
                    note1: 60,
                    note2: 60,
                    note2CentOffset: baseOffset + noise,
                    isCorrect: Bool.random(),
                    timestamp: Date().addingTimeInterval(Double(i - 50) * 86400)
                )
            }
            return ThresholdTimeline(records: records)
        }())
}

#Preview("Cold Start") {
    ProfilePreviewView()
        .padding(.horizontal)
}
