import SwiftUI

struct RhythmSpectrogramView: View {
    let mode: TrainingDiscipline

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.perceptualProfile) private var perceptualProfile

    @State private var selectedCell: SelectedCell?

    private let thresholds = SpectrogramThresholds.default

    var body: some View {
        let state = progressTimeline.state(for: mode)
        switch state {
        case .noData:
            EmptyView()
        case .active:
            activeCard
        }
    }

    // MARK: - Active Card

    private var activeCard: some View {
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let data = SpectrogramData.compute(mode: mode, profile: perceptualProfile, timeBuckets: buckets)

        return VStack(alignment: .leading, spacing: 12) {
            headlineRow
            if !data.trainedRanges.isEmpty {
                spectrogramGrid(data: data, buckets: buckets)
                legend
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Rhythm spectrogram for \(mode.config.displayName)"))
    }

    // MARK: - Headline

    private var headlineRow: some View {
        Text(String(localized: "Timing Accuracy"))
            .font(.headline)
    }

    // MARK: - Grid

    private func spectrogramGrid(data: SpectrogramData, buckets: [TimeBucket]) -> some View {
        let cellSize = Self.cellSize(columnCount: data.columns.count, rangeCount: data.trainedRanges.count)

        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Grid rows (top = fastest, bottom = slowest)
                ForEach(data.trainedRanges.reversed(), id: \.self) { range in
                    HStack(spacing: 0) {
                        // Y-axis label
                        Text(Self.rangeLabel(range))
                            .font(.caption2)
                            .frame(width: 44, alignment: .trailing)
                            .padding(.trailing, 4)

                        // Cells for this range
                        ForEach(Array(data.columns.enumerated()), id: \.offset) { columnIndex, column in
                            if let cell = column.cells.first(where: { $0.tempoRange == range }) {
                                cellView(cell: cell, size: cellSize)
                            }
                        }
                    }
                }

                // VoiceOver: per-column accessibility elements (spatially aligned with grid columns)
                HStack(spacing: 0) {
                    Color.clear.frame(width: 48)
                    ForEach(Array(data.columns.enumerated()), id: \.offset) { columnIndex, column in
                        Color.clear
                            .frame(width: cellSize, height: 1)
                            .accessibilityElement()
                            .accessibilityLabel(Self.columnAccessibilityLabel(
                                column: column,
                                buckets: buckets,
                                columnIndex: columnIndex,
                                thresholds: thresholds
                            ))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction {
                                selectedCell = SelectedCell(tempoRange: column.cells.first?.tempoRange ?? .slow, columnIndex: columnIndex)
                            }
                    }
                }

                // X-axis labels
                HStack(spacing: 0) {
                    Color.clear.frame(width: 48)
                    ForEach(Array(buckets.enumerated()), id: \.offset) { index, bucket in
                        Text(Self.columnLabel(bucket, index: index, buckets: buckets))
                            .font(.caption2)
                            .frame(width: cellSize, alignment: .center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
        .overlay {
            if let selected = selectedCell {
                detailOverlay(selected: selected, data: data, buckets: buckets)
            }
        }
    }

    private func cellView(cell: SpectrogramCell, size: CGFloat) -> some View {
        let level = thresholds.accuracyLevel(for: cell.meanAccuracyPercent)
        let hasData = cell.meanAccuracyPercent != nil

        return Rectangle()
            .fill(Self.cellColor(for: level))
            .frame(width: size, height: size)
            .border(Color.primary.opacity(0.1), width: 0.5)
            .onTapGesture {
                guard hasData else { return }
                if selectedCell?.tempoRange == cell.tempoRange && selectedCell?.columnIndex == cell.columnIndex {
                    selectedCell = nil
                } else {
                    selectedCell = SelectedCell(tempoRange: cell.tempoRange, columnIndex: cell.columnIndex)
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: - Detail Overlay

    private func detailOverlay(selected: SelectedCell, data: SpectrogramData, buckets: [TimeBucket]) -> some View {
        let column = data.columns.indices.contains(selected.columnIndex) ? data.columns[selected.columnIndex] : nil
        let cell = column?.cells.first { $0.tempoRange == selected.tempoRange }
        let bucket = buckets.indices.contains(selected.columnIndex) ? buckets[selected.columnIndex] : nil

        return Group {
            if let cell, cell.meanAccuracyPercent != nil, let bucket {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(selected.tempoRange.displayName) – \(Self.columnDateLabel(bucket))")
                        .font(.caption.bold())

                    if let early = cell.earlyStats {
                        Text(String(localized: "Early: \(Self.formatPercent(early.meanPercent)) ±\(Self.formatPercent(early.stdDevPercent)), \(early.count) hits"))
                            .font(.caption2)
                    }
                    if let late = cell.lateStats {
                        Text(String(localized: "Late: \(Self.formatPercent(late.meanPercent)) ±\(Self.formatPercent(late.stdDevPercent)), \(late.count) hits"))
                            .font(.caption2)
                    }
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
                .onTapGesture { selectedCell = nil }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: String(localized: "Precise"))
            legendItem(color: .yellow, label: String(localized: "Moderate"))
            legendItem(color: .red, label: String(localized: "Erratic"))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: - VoiceOver (per-column summaries)

    static func columnAccessibilityLabel(
        column: SpectrogramColumn,
        buckets: [TimeBucket],
        columnIndex: Int,
        thresholds: SpectrogramThresholds
    ) -> String {
        let dateLabel = columnDateLabel(buckets[columnIndex])
        let descriptions = column.cells.compactMap { cell -> String? in
            guard let level = thresholds.accuracyLevel(for: cell.meanAccuracyPercent) else {
                return "\(cell.tempoRange.displayName) \(String(localized: "no data"))"
            }
            let levelName = accuracyLevelName(level)
            return "\(cell.tempoRange.displayName) \(levelName)"
        }
        return "\(dateLabel): \(descriptions.joined(separator: ", "))"
    }

    // MARK: - Static Helpers

    static func cellColor(for level: SpectrogramAccuracyLevel?) -> Color {
        switch level {
        case .precise: .green
        case .moderate: .yellow
        case .erratic: .red
        case nil: .clear
        }
    }

    static func accuracyLevelName(_ level: SpectrogramAccuracyLevel) -> String {
        switch level {
        case .precise: String(localized: "precise")
        case .moderate: String(localized: "moderate")
        case .erratic: String(localized: "erratic")
        }
    }

    static func cellSize(columnCount: Int, rangeCount: Int) -> CGFloat {
        guard columnCount > 0, rangeCount > 0 else { return 24 }
        return max(20, min(36, 240.0 / CGFloat(max(columnCount, rangeCount))))
    }

    static func rangeLabel(_ range: TempoRange) -> String {
        "\(range.lowerBound.value)–\(range.upperBound.value)"
    }

    static func columnLabel(_ bucket: TimeBucket, index: Int, buckets: [TimeBucket]) -> String {
        ProgressChartView.formatAxisLabel(bucket.periodStart, size: bucket.bucketSize, index: index, buckets: buckets)
    }

    static func columnDateLabel(_ bucket: TimeBucket) -> String {
        ProgressChartView.annotationDateLabel(bucket.periodStart, size: bucket.bucketSize)
    }

    static func formatPercent(_ value: Double) -> String {
        (value / 100.0).formatted(.percent.precision(.fractionLength(1)))
    }
}

// MARK: - SelectedCell

private struct SelectedCell {
    let tempoRange: TempoRange
    let columnIndex: Int
}
