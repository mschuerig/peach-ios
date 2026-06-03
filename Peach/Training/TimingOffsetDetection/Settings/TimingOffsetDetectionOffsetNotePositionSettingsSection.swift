import SwiftUI

/// Mirrors ``RhythmGapPositionsSettingsSection``'s visual chrome but is
/// single-select; `GridToggleRow` is multi-toggle and isn't reusable here.
struct TimingOffsetDetectionOffsetNotePositionSettingsSection: View {
    @AppStorage(TimingOffsetDetectionSettingsKeys.offsetNotePosition)
    private var offsetNotePosition: Int = OffsetNotePosition.default.rawValue

    @ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32

    private static let positions: [OffsetNotePosition] =
        OffsetNotePosition.validRange.map { OffsetNotePosition($0) }

    private var effectivePosition: OffsetNotePosition {
        OffsetNotePosition(clamping: offsetNotePosition)
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

    private func cell(for position: OffsetNotePosition) -> some View {
        let isActive = (position == effectivePosition)
        return Button {
            offsetNotePosition = position.rawValue
        } label: {
            Text("\(position.rawValue)")
                .font(.caption2)
                .frame(width: cellSize, height: cellSize)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isActive ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .platformHoverEffect()
        .accessibilityLabel(String(localized: "Note \(position.rawValue) of \(Self.positions.count)"))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
