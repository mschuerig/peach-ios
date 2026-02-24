import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Layout Tests")
@MainActor
struct ProfileScreenLayoutTests {

    // MARK: - Accessibility Summary

    @Test("Accessibility summary shows comparison count and current average")
    func accessibilitySummaryWithData() async throws {
        // 30 records across 30 different days so aggregation produces 30 points
        let records = (0..<30).map { i in
            ComparisonRecord(
                note1: 60,
                note2: 60,
                note2CentOffset: Double(30 + i),
                isCorrect: true,
                timestamp: Date().addingTimeInterval(Double(i - 30) * 86400)
            )
        }
        let timeline = ThresholdTimeline(records: records)

        let summary = ProfileScreen.accessibilitySummary(timeline: timeline)

        #expect(summary.contains("30"), "Expected comparison count 30 in: \(summary)")
        #expect(summary.contains("50"), "Expected current average ~50 in: \(summary)")
    }

    @Test("Accessibility summary empty state is non-empty")
    func accessibilitySummaryEmpty() async throws {
        let timeline = ThresholdTimeline()
        let summary = ProfileScreen.accessibilitySummary(timeline: timeline)

        #expect(!summary.isEmpty)
    }
}
