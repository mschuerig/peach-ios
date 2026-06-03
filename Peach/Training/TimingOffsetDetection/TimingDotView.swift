import SwiftUI

struct TimingDotView: View {
    let litCount: Int
    let testedNoteIndex: Int

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<4, id: \.self) { index in
                let size = Self.diameter(forStepIndex: index)
                let opacity = index < litCount ? 1.0 : 0.2

                if Self.isTestedNote(index: index, testedNoteIndex: testedNoteIndex) {
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
    static let overlapOffset: CGFloat = 8
    static let testedNoteFrameWidth: CGFloat = dotDiameter + overlapOffset

    static func diameter(forStepIndex index: Int) -> CGFloat {
        index == 0 ? beatOneDotDiameter : dotDiameter
    }

    static func isTestedNote(index: Int, testedNoteIndex: Int) -> Bool {
        index == testedNoteIndex
    }
}

// MARK: - Previews

private let previewTestedNoteIndex = TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition - 1

#Preview("No dots lit — double circle dimmed") {
    TimingDotView(litCount: 0, testedNoteIndex: previewTestedNoteIndex)
        .padding()
}

#Preview("2 dots lit — double circle dimmed") {
    TimingDotView(litCount: 2, testedNoteIndex: previewTestedNoteIndex)
        .padding()
}

#Preview("3 dots lit — double circle lit") {
    TimingDotView(litCount: 3, testedNoteIndex: previewTestedNoteIndex)
        .padding()
}

#Preview("All dots lit") {
    TimingDotView(litCount: 4, testedNoteIndex: previewTestedNoteIndex)
        .padding()
}
