import Testing
import SwiftUI
@testable import Peach

@Suite("Continuous Rhythm Matching Profile Tests")
struct ContinuousRhythmMatchingProfileTests {

    // MARK: - Profile Screen Routing

    @Test("continuousRhythmMatching is routed to rhythm profile card alongside other rhythm modes")
    func routedToRhythmProfileCard() async {
        // The rhythm card set in ProfileScreen routes these modes to RhythmProfileCardView.
        // Verify continuousRhythmMatching is grouped with the other rhythm modes by checking
        // that it shares the same card infrastructure (statisticsKeys use rhythm keys).
        let keys = TrainingDisciplineID.continuousRhythmMatching.statisticsKeys
        let allAreRhythmKeys = keys.allSatisfy {
            if case .rhythm(.continuousRhythmMatching, _, _) = $0 { return true }
            return false
        }
        #expect(allAreRhythmKeys)
        #expect(!keys.isEmpty)
    }

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
                    for: .rhythm(.continuousRhythmMatching, .moderate, .early)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)

        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        let expectedName = TrainingDisciplineID.continuousRhythmMatching.config.displayName
        #expect(summary.contains(expectedName))
    }

    @Test("Empty profile does not include continuous rhythm matching in accessibility summary")
    func emptyProfileExcludesContinuousRhythmMatching() async {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        let summary = ProfileScreen.accessibilitySummary(progressTimeline: timeline)

        let name = TrainingDisciplineID.continuousRhythmMatching.config.displayName
        #expect(!summary.contains(name))
    }

    @Test("ProgressTimeline reports noData for continuous rhythm matching with no data")
    func noDataState() async {
        let timeline = ProgressTimeline(profile: PerceptualProfile())
        #expect(timeline.state(for: .continuousRhythmMatching) == .noData)
    }

    @Test("ProgressTimeline reports active state with EWMA and trend when data exists")
    func activeStateWithEWMAAndTrend() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<10 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(15 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .moderate, .early)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)

        #expect(timeline.state(for: .continuousRhythmMatching) == .active)
        #expect(timeline.currentEWMA(for: .continuousRhythmMatching) != nil)
        #expect(timeline.trend(for: .continuousRhythmMatching) != nil)
    }

    // MARK: - Spectrogram Data

    @Test("Spectrogram computes for continuous rhythm matching data with correct trained ranges")
    func spectrogramComputesWithCorrectRanges() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<10 {
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(15 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .moderate, .early)
                )
                builder.addPoint(
                    MetricPoint(
                        timestamp: Date().addingTimeInterval(Double(i - 10) * 3600),
                        value: Double(10 + i)
                    ),
                    for: .rhythm(.continuousRhythmMatching, .moderate, .late)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)
        let buckets = timeline.allGranularityBuckets(for: .continuousRhythmMatching)
        let data = SpectrogramData.compute(mode: .continuousRhythmMatching, profile: profile, timeBuckets: buckets)

        #expect(data.trainedRanges == [.moderate])
        #expect(!data.columns.isEmpty)
    }

    // MARK: - Share Image File Name

    @Test("Export file name contains continuous-rhythm-matching slug")
    @MainActor
    func exportFileNameContainsSlug() async {
        let date = Date()
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .continuousRhythmMatching)

        #expect(fileName.contains("continuous-rhythm-matching"))
        #expect(fileName.hasSuffix(".png"))
    }
}
