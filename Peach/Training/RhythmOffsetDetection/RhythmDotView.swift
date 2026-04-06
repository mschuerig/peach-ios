import SwiftUI

struct RhythmDotView: View {
    let litCount: Int

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<4, id: \.self) { index in
                let size = Self.diameter(forStepIndex: index)
                let opacity = index < litCount ? 1.0 : 0.2

                if Self.isTestedNote(index: index) {
                    ZStack {
                        Circle()
                            .fill(.primary)
                            .frame(width: size, height: size)
                            .offset(x: -Self.overlapOffset / 2)
                        Circle()
                            .fill(.primary)
                            .frame(width: size, height: size)
                            .offset(x: Self.overlapOffset / 2)
                    }
                    .frame(width: Self.testedNoteFrameWidth, height: size)
                    .opacity(opacity)
                } else {
                    Circle()
                        .fill(.primary)
                        .frame(width: size, height: size)
                        .opacity(opacity)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let dotDiameter: CGFloat = 16
    static let beatOneDotDiameter: CGFloat = 22
    static let dotSpacing: CGFloat = 24
    static let testedNoteIndex = RhythmOffsetDetectionSession.testedNoteIndex
    static let overlapOffset: CGFloat = 8
    static let testedNoteFrameWidth: CGFloat = dotDiameter + overlapOffset

    static func diameter(forStepIndex index: Int) -> CGFloat {
        index == 0 ? beatOneDotDiameter : dotDiameter
    }

    static func isTestedNote(index: Int) -> Bool {
        index == testedNoteIndex
    }
}

// MARK: - Previews

#Preview("No dots lit — double circle dimmed") {
    RhythmDotView(litCount: 0)
        .padding()
}

#Preview("2 dots lit — double circle dimmed") {
    RhythmDotView(litCount: 2)
        .padding()
}

#Preview("3 dots lit — double circle lit") {
    RhythmDotView(litCount: 3)
        .padding()
}

#Preview("All dots lit") {
    RhythmDotView(litCount: 4)
        .padding()
}
