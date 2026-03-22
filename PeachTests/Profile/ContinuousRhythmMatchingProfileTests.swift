import Testing
import SwiftUI
@testable import Peach

@Suite("Continuous Rhythm Matching Profile Tests")
struct ContinuousRhythmMatchingProfileTests {

    // MARK: - Profile Card Integration

    @Test("Profile accessibility summary includes continuous rhythm matching when data exists")
    func accessibilitySummaryIncludesContinuousRhythmMatching() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<10 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(15 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .medium, .early)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)

        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        let expectedName = TrainingDisciplineConfig.continuousRhythmMatching.displayName
        #expect(summary.contains(expectedName))
    }

    @Test("Rhythm profile card view shows empty state for continuous rhythm matching with no data")
    func emptyStateForContinuousRhythmMatching() async {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        let state = timeline.state(for: .continuousRhythmMatching)

        #expect(state == .noData)
    }

    @Test("Rhythm profile card view shows active state for continuous rhythm matching with data")
    func activeStateForContinuousRhythmMatching() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<10 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(15 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .medium, .early)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)

        #expect(timeline.state(for: .continuousRhythmMatching) == .active)
        #expect(timeline.currentEWMA(for: .continuousRhythmMatching) != nil)
        #expect(timeline.trend(for: .continuousRhythmMatching) != nil)
    }

    // MARK: - Spectrogram Data

    @Test("Spectrogram computes for continuous rhythm matching data")
    func spectrogramComputesForContinuousRhythmMatching() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<10 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(15 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .medium, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(10 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .medium, .late)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)
        let buckets = timeline.allGranularityBuckets(for: .continuousRhythmMatching)
        let data = SpectrogramData.compute(mode: .continuousRhythmMatching, profile: profile, timeBuckets: buckets)

        #expect(!data.trainedRanges.isEmpty)
        #expect(data.trainedRanges.contains(.medium))
        #expect(!data.columns.isEmpty)
    }

    // MARK: - Share Image File Name

    @Test("Export file name contains continuous-rhythm-matching slug")
    func exportFileNameContainsSlug() async {
        let date = Date()
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .continuousRhythmMatching)

        #expect(fileName.contains("continuous-rhythm-matching"))
        #expect(fileName.hasSuffix(".png"))
    }

    // MARK: - Formatting

    @Test("Rhythm EWMA formats correctly for continuous matching values")
    func rhythmEWMAFormattingForContinuousMatching() async {
        let formatted = RhythmProfileCardView.formatRhythmEWMA(18.3)
        #expect(formatted == "18.3 ms")
    }

    @Test("Rhythm stddev formats correctly for continuous matching values")
    func rhythmStdDevFormattingForContinuousMatching() async {
        let formatted = RhythmProfileCardView.formatRhythmStdDev(5.7)
        #expect(formatted == "±5.7 ms")
    }
}
