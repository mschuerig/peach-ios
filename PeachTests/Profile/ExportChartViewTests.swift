import Testing
import Foundation
import SwiftUI
@testable import Peach

@Suite("ExportChartView Tests")
@MainActor
struct ExportChartViewTests {

    private func makeTimeline(records: [PitchDiscriminationRecord]) -> ProgressTimeline {
        let profile = PerceptualProfile { builder in
            builder.feedPitchDiscriminations(records)
        }
        return ProgressTimeline(profile: profile)
    }

    @Test("renders without crashing with mock data")
    func rendersWithMockData() async {
        let now = Date()
        let records = (0..<10).map { i in
            PitchDiscriminationRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: Double(10 + i),
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: now.addingTimeInterval(-Double(10 - i) * 3600)
            )
        }
        let timeline = makeTimeline(records: records)
        let view = ExportChartView(mode: .unisonPitchDiscrimination, progressTimeline: timeline, date: now)

        // Verify the view can be rendered by ImageRenderer without crashing
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let image = renderer.cgImage
        #expect(image != nil)
    }

    @Test("renders without crashing with empty data")
    func rendersWithEmptyData() async {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        let view = ExportChartView(mode: .unisonPitchDiscrimination, progressTimeline: timeline)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        // Empty data still produces an image (just no chart content)
        let image = renderer.cgImage
        #expect(image != nil)
    }

    @Test("ChartImageRenderer.render produces a file URL with correct filename pattern")
    func renderProducesFileURL() async {
        let now = Date()
        let records = (0..<5).map { i in
            PitchDiscriminationRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: Double(10 + i),
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: now.addingTimeInterval(-Double(5 - i) * 3600)
            )
        }
        let timeline = makeTimeline(records: records)
        let url = ChartImageRenderer.render(mode: .unisonPitchDiscrimination, progressTimeline: timeline, date: now)

        #expect(url != nil)
        if let url {
            #expect(url.lastPathComponent.hasPrefix("peach-pitch-discrimination-"))
            #expect(url.lastPathComponent.hasSuffix(".png"))
            // Verify file exists and has content
            let data = try? Data(contentsOf: url)
            #expect(data != nil)
            #expect((data?.count ?? 0) > 0)
            // Clean up
            try? FileManager.default.removeItem(at: url)
        }
    }
}
