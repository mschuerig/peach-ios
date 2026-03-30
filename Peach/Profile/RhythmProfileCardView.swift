import SwiftUI
import os

struct RhythmProfileCardView: View {
    let mode: TrainingDisciplineID

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.perceptualProfile) private var perceptualProfile

    @State private var shareImageURL: URL?

    private var config: TrainingDisciplineConfig { mode.config }

    var body: some View {
        let state = progressTimeline.state(for: mode)

        switch state {
        case .noData:
            emptyCard
        case .active:
            activeCard
        }
    }

    // MARK: - Active Card

    private var activeCard: some View {
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let ewma = progressTimeline.currentEWMA(for: mode)
        let trend = progressTimeline.trend(for: mode)
        let stddev = buckets.last?.stddev ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            headlineRow(ewma: ewma, stddev: stddev, trend: trend)
            RhythmSpectrogramView(mode: mode)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Rhythm profile for \(config.displayName)"))
        .task(id: progressTimeline.recordCount(for: mode)) {
            shareImageURL = renderShareImage()
        }
    }

    // MARK: - Empty Card

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(config.displayName)
                    .font(.headline)
                Spacer()
                Text("—")
                    .font(.title2.bold())
            }
            Text(String(localized: "Start rhythm training to build your profile"))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "No training data for \(config.displayName). Start training to build your profile."))
    }

    // MARK: - Headline Row

    private func headlineRow(ewma: Double?, stddev: Double, trend: Trend?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(config.displayName)
                .font(.headline)

            Spacer()

            if let ewma {
                Text(Self.formatRhythmEWMA(ewma))
                    .font(.title2.bold())
                    .accessibilityLabel(String(localized: "Current average \(Self.formatRhythmEWMA(ewma))"))
                Text(Self.formatRhythmStdDev(stddev))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let trend {
                Image(systemName: TrainingStatsView.trendSymbol(trend))
                    .foregroundStyle(TrainingStatsView.trendColor(trend))
                    .accessibilityLabel(TrainingStatsView.trendLabel(trend))
            }

            if let shareURL = shareImageURL {
                ShareLink(
                    item: shareURL,
                    preview: SharePreview(config.displayName)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Share \(config.displayName) chart"))
            }
        }
    }

    // MARK: - Share Image

    private func renderShareImage() -> URL? {
        let content = RhythmProfileCardExportView(mode: mode, date: Date())
            .environment(\.progressTimeline, progressTimeline)
            .environment(\.perceptualProfile, perceptualProfile)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage,
              let pngData = ChartImageRenderer.pngData(from: cgImage, scale: renderer.scale) else { return nil }
        let fileName = ChartImageRenderer.exportFileName(mode: mode)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Formatting

    static func formatRhythmEWMA(_ value: Double) -> String {
        "\(String(format: "%.1f", value)) ms"
    }

    static func formatRhythmStdDev(_ value: Double) -> String {
        "±\(String(format: "%.1f", value)) ms"
    }
}

// MARK: - Export View

private struct RhythmProfileCardExportView: View {
    let mode: TrainingDisciplineID
    let date: Date

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.perceptualProfile) private var perceptualProfile

    private static let thresholds = SpectrogramThresholds.default

    private var config: TrainingDisciplineConfig { mode.config }

    var body: some View {
        let ewma = progressTimeline.currentEWMA(for: mode)
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let stddev = buckets.last?.stddev ?? 0
        let trend = progressTimeline.trend(for: mode)
        let data = SpectrogramData.compute(mode: mode, profile: perceptualProfile, timeBuckets: buckets)

        VStack(alignment: .leading, spacing: 12) {
            headlineRow(ewma: ewma, stddev: stddev, trend: trend)
            timestampRow
            if !data.trainedRanges.isEmpty {
                flatSpectrogramGrid(data: data)
                legend
            }
        }
        .padding()
        .frame(width: exportWidth(columnCount: data.columns.count))
        .background(Color.platformBackground)
    }

    // MARK: - Headline

    private func headlineRow(ewma: Double?, stddev: Double, trend: Trend?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image("ExportIcon")
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }

            Text(config.displayName)
                .font(.headline)

            Spacer()

            if let ewma {
                Text(RhythmProfileCardView.formatRhythmEWMA(ewma))
                    .font(.title2.bold())
                Text(RhythmProfileCardView.formatRhythmStdDev(stddev))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let trend {
                Image(systemName: TrainingStatsView.trendSymbol(trend))
                    .foregroundStyle(TrainingStatsView.trendColor(trend))
            }
        }
    }

    private var timestampRow: some View {
        Text(date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Flat Spectrogram Grid

    private func flatSpectrogramGrid(data: SpectrogramData) -> some View {
        let cellSize = exportCellSize(columnCount: data.columns.count, rangeCount: data.trainedRanges.count)

        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(data.trainedRanges.reversed(), id: \.self) { range in
                    HStack(spacing: 0) {
                        ForEach(data.columns) { column in
                            if let cell = column.cells.first(where: { $0.tempoRange == range }) {
                                let level = Self.thresholds.accuracyLevel(for: cell.meanAccuracyPercent, tempoRange: cell.tempoRange)
                                Rectangle()
                                    .fill(RhythmSpectrogramView.cellColor(for: level))
                                    .frame(width: cellSize, height: cellSize)
                                    .border(Color.primary.opacity(0.1), width: 0.5)
                            }
                        }
                    }
                }

                HStack(spacing: 0) {
                    ForEach(data.columns) { column in
                        Text(RhythmSpectrogramView.columnLabel(data.timeBuckets[column.index], index: column.index, buckets: data.timeBuckets))
                            .font(.caption2)
                            .frame(width: cellSize, alignment: .center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            VStack(spacing: 0) {
                ForEach(data.trainedRanges.reversed(), id: \.self) { range in
                    Text(RhythmSpectrogramView.rangeLabel(range))
                        .font(.caption2)
                        .frame(width: 44, height: cellSize, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: RhythmSpectrogramView.cellColor(for: .excellent), label: String(localized: "Excellent"))
            legendItem(color: RhythmSpectrogramView.cellColor(for: .precise), label: String(localized: "Precise"))
            legendItem(color: RhythmSpectrogramView.cellColor(for: .moderate), label: String(localized: "Moderate"))
            legendItem(color: RhythmSpectrogramView.cellColor(for: .loose), label: String(localized: "Loose"))
            legendItem(color: RhythmSpectrogramView.cellColor(for: .erratic), label: String(localized: "Erratic"))
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

    // MARK: - Layout

    private func exportCellSize(columnCount: Int, rangeCount: Int) -> CGFloat {
        guard columnCount > 0, rangeCount > 0 else { return 24 }
        return max(14, min(36, 310.0 / CGFloat(max(columnCount, rangeCount))))
    }

    private func exportWidth(columnCount: Int) -> CGFloat {
        guard columnCount > 0 else { return 390 }
        let cellSize = exportCellSize(columnCount: columnCount, rangeCount: 1)
        return max(390, cellSize * CGFloat(columnCount) + 48 + 32)
    }
}
