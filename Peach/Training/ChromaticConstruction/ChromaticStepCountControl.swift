import SwiftUI

/// Picker for the number of equal-cent steps the chromatic walk should
/// span. Replaces the outer-interval picker — Michael's iteration-3
/// decision: the discipline trains chained equal-cent steps; users care
/// about how many steps, not the interval name they happen to land on. The
/// number of steps directly determines the path length and the outer
/// interval (`Interval(rawValue: stepCount)`).
struct ChromaticStepCountControl: View {
    @Binding var stepCount: Int

    static let allowedStepCounts: [Int] = Array(2...12)

    var body: some View {
        Picker(selection: $stepCount) {
            ForEach(Self.allowedStepCounts, id: \.self) { n in
                Text("\(n) steps").tag(n)
            }
        } label: {
            Text(String(localized: "Steps"))
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Steps"))
    }
}
