import SwiftUI

struct ContinuousRhythmMatchingDotView: View {
    let activeStep: StepPosition?
    let gapPosition: StepPosition?

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<4, id: \.self) { index in
                dotView(for: index)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dotView(for index: Int) -> some View {
        let diameter = Self.diameter(forStepIndex: index)
        let isGap = Self.isGapDot(stepIndex: index, gapPosition: gapPosition)
        let opacity = Self.dotOpacity(stepIndex: index, activeStep: activeStep, gapPosition: gapPosition)

        if isGap {
            Circle()
                .stroke(.primary, lineWidth: Self.gapStrokeWidth)
                .frame(width: diameter, height: diameter)
                .opacity(opacity)
        } else {
            Circle()
                .fill(.primary)
                .frame(width: diameter, height: diameter)
                .opacity(opacity)
        }
    }

    // MARK: - Layout Parameters

    static let dotDiameter: CGFloat = 16
    static let beatOneDotDiameter: CGFloat = 22
    static let dotSpacing: CGFloat = 24
    private static let gapStrokeWidth: CGFloat = 2

    // MARK: - Static Logic (extracted for testability)

    static func diameter(forStepIndex index: Int) -> CGFloat {
        index == 0 ? beatOneDotDiameter : dotDiameter
    }

    static func isGapDot(stepIndex: Int, gapPosition: StepPosition?) -> Bool {
        guard let gapPosition else { return false }
        return stepIndex == gapPosition.rawValue
    }

    static func dotOpacity(stepIndex: Int, activeStep: StepPosition?, gapPosition: StepPosition?) -> Double {
        guard let activeStep else { return 0.2 }
        if stepIndex == activeStep.rawValue {
            return 1.0
        }
        return 0.2
    }

}

// MARK: - Previews

#Preview("Gap at position 2, step 1 active") {
    ContinuousRhythmMatchingDotView(
        activeStep: .first,
        gapPosition: .second
    )
    .padding()
}

#Preview("Gap dot active") {
    ContinuousRhythmMatchingDotView(
        activeStep: .second,
        gapPosition: .second
    )
    .padding()
}

#Preview("No active step") {
    ContinuousRhythmMatchingDotView(
        activeStep: nil,
        gapPosition: .fourth
    )
    .padding()
}
