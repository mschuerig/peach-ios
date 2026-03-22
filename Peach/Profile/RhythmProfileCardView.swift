import SwiftUI
import os

struct RhythmProfileCardView: View {
    let mode: TrainingDisciplineID

    @Environment(\.progressTimeline) private var progressTimeline

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
        let content = RhythmProfileCardExportView(mode: mode)
            .environment(\.progressTimeline, progressTimeline)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else { return nil }
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

    @Environment(\.progressTimeline) private var progressTimeline

    var body: some View {
        let config = mode.config
        let ewma = progressTimeline.currentEWMA(for: mode)
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let stddev = buckets.last?.stddev ?? 0
        let trend = progressTimeline.trend(for: mode)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
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
            RhythmSpectrogramView(mode: mode)
        }
        .padding()
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
