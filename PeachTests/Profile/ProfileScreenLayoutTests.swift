import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Layout Tests")
struct ProfileScreenLayoutTests {

    // MARK: - Accessibility Summary

    @Test("Accessibility summary lists active modes")
    func accessibilitySummaryWithData() async throws {
        let records = (0..<25).map { i in
            ComparisonRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: Double(30 + i),
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament",
                timestamp: Date().addingTimeInterval(Double(i - 25) * 3600)
            )
        }
        let timeline = ProgressTimeline(comparisonRecords: records)

        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        let expectedName = TrainingModeConfig.unisonComparison.displayName
        #expect(summary.contains(expectedName))
    }

    @Test("Accessibility summary empty state is non-empty")
    func accessibilitySummaryEmpty() async throws {
        let timeline = ProgressTimeline()
        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        #expect(!summary.isEmpty)
    }
}
