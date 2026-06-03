import SwiftUI

/// Mirrors ``RhythmGapPositionsSettingsSection``'s visual chrome but is
/// single-select; `GridToggleRow` is multi-toggle and isn't reusable here.
/// "Offset Note Position" is a placeholder term — see story 82.2 / 82.4 for the
/// rename.
struct TimingOffsetDetectionOffsetNotePositionSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.offsetNotePosition)
    private var offsetNotePosition: Int = TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition

    @ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32

    private static let positions: [Int] = Array(TimingOffsetDetectionSettingsKeys.validOffsetNotePositionRange)

    private var effectivePosition: Int {
        TimingOffsetDetectionSettingsKeys.clamped(offsetNotePosition)
    }

    var body: some View {
        Section {
            HStack(spacing: 4) {
                ForEach(Self.positions, id: \.self) { position in
                    cell(for: position)
                }
            }
        } header: {
            Text(String(localized: "Offset Note Position"))
        } footer: {
            Text(String(localized: "Pick which of the four 16th notes carries the timing offset."))
        }
    }

    private func cell(for position: Int) -> some View {
        let isActive = (position == effectivePosition)
        return Button {
            offsetNotePosition = position
        } label: {
            Text("\(position)")
                .font(.caption2)
                .frame(width: cellSize, height: cellSize)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isActive ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .platformHoverEffect()
        .accessibilityLabel(String(localized: "Note \(position) of \(Self.positions.count)"))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
