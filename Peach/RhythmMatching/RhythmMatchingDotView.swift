import SwiftUI

struct RhythmMatchingDotView: View {
    let litCount: Int
    let fourthDotColor: Color?

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(fillColor(for: index))
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                    .opacity(index < litCount ? 1.0 : 0.2)
            }
        }
        .accessibilityHidden(true)
    }

    private func fillColor(for index: Int) -> Color {
        if index == 3, let fourthDotColor {
            return fourthDotColor
        }
        return .primary
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let dotDiameter: CGFloat = 16
    static let dotSpacing: CGFloat = 24

    // MARK: - Color Mapping

    static func dotColor(forPercentage percentage: Double) -> Color {
        let absolute = abs(percentage)
        if absolute <= 5 {
            return .green
        } else if absolute <= 15 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Previews

#Preview("No dots lit") {
    RhythmMatchingDotView(litCount: 0, fourthDotColor: nil)
        .padding()
}

#Preview("3 dots lit, no feedback") {
    RhythmMatchingDotView(litCount: 3, fourthDotColor: nil)
        .padding()
}

#Preview("4 dots lit, green feedback") {
    RhythmMatchingDotView(litCount: 4, fourthDotColor: .green)
        .padding()
}

#Preview("4 dots lit, red feedback") {
    RhythmMatchingDotView(litCount: 4, fourthDotColor: .red)
        .padding()
}
