import SwiftUI

struct RhythmDotView: View {
    let litCount: Int

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<4, id: \.self) { index in
                let size = Self.diameter(forStepIndex: index)
                Circle()
                    .fill(.primary)
                    .frame(width: size, height: size)
                    .opacity(index < litCount ? 1.0 : 0.2)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let dotDiameter: CGFloat = 16
    static let beatOneDotDiameter: CGFloat = 22
    static let dotSpacing: CGFloat = 24

    static func diameter(forStepIndex index: Int) -> CGFloat {
        index == 0 ? beatOneDotDiameter : dotDiameter
    }
}

// MARK: - Previews

#Preview("No dots lit") {
    RhythmDotView(litCount: 0)
        .padding()
}

#Preview("2 dots lit") {
    RhythmDotView(litCount: 2)
        .padding()
}

#Preview("All dots lit") {
    RhythmDotView(litCount: 4)
        .padding()
}
