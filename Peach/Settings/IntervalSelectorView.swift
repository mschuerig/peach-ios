import SwiftUI

struct IntervalSelectorView: View {
    @Binding var selection: IntervalSelection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 4) {
                headerRow
                directionRow(direction: .up)
                directionRow(direction: .down)
            }
            .padding(.vertical, 4)
        }
    }

    private var headerRow: some View {
        GridRow {
            Text("")
                .frame(width: 24)
            ForEach(Interval.allCases, id: \.self) { interval in
                Text(interval.abbreviation)
                    .font(.caption2)
                    .frame(width: 32)
            }
        }
    }

    private func directionRow(direction: Direction) -> some View {
        GridRow {
            Text(direction == .up ? "⏶" : "⏷")
                .font(.caption)
                .frame(width: 24)
            ForEach(Interval.allCases, id: \.self) { interval in
                intervalCell(interval: interval, direction: direction)
            }
        }
    }

    private func intervalCell(interval: Interval, direction: Direction) -> some View {
        let directedInterval = direction == .up
            ? DirectedInterval.up(interval)
            : DirectedInterval.down(interval)
        let isActive = selection.intervals.contains(directedInterval)
        let isPrimeDown = interval == .prime && direction == .down
        let isLastActive = selection.isLastRemaining(directedInterval)

        return Button {
            toggle(directedInterval)
        } label: {
            Text(interval.abbreviation)
                .font(.caption2)
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isActive ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isPrimeDown || isLastActive)
        .opacity(isPrimeDown ? 0.3 : 1.0)
    }

    private func toggle(_ directedInterval: DirectedInterval) {
        if selection.intervals.contains(directedInterval) {
            selection.intervals.remove(directedInterval)
        } else {
            selection.intervals.insert(directedInterval)
        }
    }
}
