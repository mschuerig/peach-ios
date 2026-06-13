import SwiftUI

/// Result-mode view for the Chromatic Construction discipline.
///
/// Renders the user's chromatic path as dots (no connecting line) with
/// absolute and relative cent labels per placed dot. On appear the screen
/// auto-plays the user's path note-by-note; this view itself owns no audio.
/// Tapping any dot delegates to `onTapDot` so the parent can interrupt the
/// auto-playback and replay a single pitch.
struct ChromaticTrialResultView: View {
    let completed: CompletedChromaticConstructionTrial
    let onTapDot: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ChromaticContourView(
                path: completed.trial.path,
                placedOffsets: completed.trial.placed.map(\.offset),
                audibleOffsets: completed.trial.audibleOffsets,
                activePositionIndex: nil,
                preservedValueForActive: nil,
                isShowingResult: true,
                onRevertTo: { _ in },
                onDragStarted: { _ in },
                onDragChanged: { _ in },
                onCommit: { _ in },
                onResultTap: onTapDot
            )
            centLabelsRow
        }
    }

    private var centLabelsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(completed.trial.placed.indices, id: \.self) { index in
                let absolute = completed.trial.placed[index].offset
                let priorAbsolute = index == 0 ? Cents(0) : completed.trial.placed[index - 1].offset
                let relative = absolute - priorAbsolute
                centLabel(index: index + 1, absolute: absolute, relative: relative)
                if index < completed.trial.placed.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private func centLabel(index: Int, absolute: Cents, relative: Cents) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(verbatim: "\(index)")
                .font(.caption2)
            Text(verbatim: "\(formatSignedCents(absolute))")
            Text(verbatim: "(\(formatSignedCents(relative)))")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatSignedCents(_ cents: Cents) -> String {
        let rounded = Int(cents.rawValue.rounded())
        if rounded == 0 { return "0¢" }
        return rounded > 0 ? "+\(rounded)¢" : "\(rounded)¢"
    }
}
