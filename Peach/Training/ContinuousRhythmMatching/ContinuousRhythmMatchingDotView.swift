import SwiftUI

struct ContinuousRhythmMatchingDotView: View {
    let activeBeatPosition: BeatPosition?
    let gapPosition: BeatPosition?

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
        let diameter = Self.diameter(forIndex: index)
        let isGap = Self.isGapDot(index: index, gapPosition: gapPosition)
        let opacity = Self.dotOpacity(index: index, activeBeatPosition: activeBeatPosition, gapPosition: gapPosition)

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

    static func diameter(forIndex index: Int) -> CGFloat {
        index == 0 ? beatOneDotDiameter : dotDiameter
    }

    static func isGapDot(index: Int, gapPosition: BeatPosition?) -> Bool {
        guard let gapPosition else { return false }
        return index == gapPosition.rawValue
    }

    static func dotOpacity(index: Int, activeBeatPosition: BeatPosition?, gapPosition: BeatPosition?) -> Double {
        guard let activeBeatPosition else { return 0.2 }
        if index == activeBeatPosition.rawValue {
            return 1.0
        }
        return 0.2
    }

}

// MARK: - Previews

#Preview("Gap at position 2, position 1 active") {
    ContinuousRhythmMatchingDotView(
        activeBeatPosition: .first,
        gapPosition: .second
    )
    .padding()
}

#Preview("Gap dot active") {
    ContinuousRhythmMatchingDotView(
        activeBeatPosition: .second,
        gapPosition: .second
    )
    .padding()
}

#Preview("No active position") {
    ContinuousRhythmMatchingDotView(
        activeBeatPosition: nil,
        gapPosition: .fourth
    )
    .padding()
}
