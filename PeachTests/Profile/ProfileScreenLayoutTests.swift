import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Layout Tests")
struct ProfileScreenLayoutTests {

    // MARK: - Accessibility Summary

    @Test("Accessibility summary lists active modes")
    func accessibilitySummaryWithData() async throws {
        let profile = PerceptualProfile { builder in
            for i in 0..<25 {
                builder.addPoint(
                    MetricPoint(timestamp: Date().addingTimeInterval(Double(i - 25) * 3600), value: Double(30 + i)),
                    for: .pitch(.unisonPitchDiscrimination)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)

        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        let expectedName = TrainingDisciplineID.unisonPitchDiscrimination.config.displayName
        #expect(summary.contains(expectedName))
    }

    @Test("Accessibility summary empty state is non-empty")
    func accessibilitySummaryEmpty() async throws {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        #expect(!summary.isEmpty)
    }
}
