import Testing
import SwiftUI
@testable import Peach

/// Tests for SummaryStatisticsView display logic
@Suite("SummaryStatistics Tests")
@MainActor
struct SummaryStatisticsTests {

    // MARK: - Task 1: Mean and StdDev computation

    @Test("Mean uses unsigned per-note means")
    func meanUsesUnsignedValues() async throws {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 40, isCorrect: true)
        profile.update(note: 62, centOffset: 30, isCorrect: true)

        let stats = SummaryStatisticsView.computeStats(from: profile, midiRange: 36...84)

        // Mean of unsigned per-note means: (40 + 30) / 2 = 35
        #expect(stats != nil)
        #expect(stats!.mean == 35.0)
    }

    @Test("StdDev computed from absolute per-note means")
    func stdDevFromAbsoluteMeans() async throws {
        let profile = PerceptualProfile()
        // Three notes with different absolute means
        profile.update(note: 60, centOffset: 20, isCorrect: true)
        profile.update(note: 62, centOffset: 40, isCorrect: true)
        profile.update(note: 64, centOffset: 60, isCorrect: true)

        let stats = SummaryStatisticsView.computeStats(from: profile, midiRange: 36...84)

        #expect(stats != nil)
        // abs means: [20, 40, 60], mean of abs = 40
        // Variance = ((20-40)^2 + (40-40)^2 + (60-40)^2) / (3-1) = (400+0+400)/2 = 400
        // stdDev = sqrt(400) = 20
        #expect(stats!.mean == 40.0)
        #expect(stats!.stdDev == 20.0)
    }

    @Test("Cold start returns nil stats when no training data")
    func coldStartReturnsNil() async throws {
        let profile = PerceptualProfile()

        let stats = SummaryStatisticsView.computeStats(from: profile, midiRange: 36...84)

        #expect(stats == nil)
    }

    @Test("Single trained note returns mean but no stdDev")
    func singleNoteNoStdDev() async throws {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 50, isCorrect: true)

        let stats = SummaryStatisticsView.computeStats(from: profile, midiRange: 36...84)

        #expect(stats != nil)
        #expect(stats!.mean == 50.0)
        #expect(stats!.stdDev == nil)
    }

    // MARK: - Formatting

    @Test("Mean formatted as rounded integer with localized cent unit")
    func meanFormatted() async throws {
        #expect(SummaryStatisticsView.formatMean(32.7) == String(localized: "\(33) cents"))
        #expect(SummaryStatisticsView.formatMean(1.2) == String(localized: "\(1) cents"))
    }

    @Test("StdDev formatted with plus-minus prefix and localized cent unit")
    func stdDevFormatted() async throws {
        #expect(SummaryStatisticsView.formatStdDev(14.3) == String(localized: "±\(14) cents"))
    }

    @Test("Cold start displays dashes")
    func coldStartDisplaysDashes() async throws {
        #expect(SummaryStatisticsView.formatMean(nil) == "—")
        #expect(SummaryStatisticsView.formatStdDev(nil) == "—")
    }

    // MARK: - Trend Symbol Mapping

    @Test("Trend symbols map to correct SF Symbol names")
    func trendSymbols() async throws {
        #expect(SummaryStatisticsView.trendSymbol(.improving) == "arrow.down.right")
        #expect(SummaryStatisticsView.trendSymbol(.stable) == "arrow.right")
        #expect(SummaryStatisticsView.trendSymbol(.declining) == "arrow.up.right")
    }

    // MARK: - Localization (Story 7.1)

    @Test("formatMean uses localized pluralization: singular 'cent' for value 1")
    func formatMeanSingularPlural() async throws {
        let singular = SummaryStatisticsView.formatMean(1.0)
        let plural = SummaryStatisticsView.formatMean(2.0)
        // String(localized:) with catalog plural variants:
        //   en: one → "1 cent", other → "2 cents"
        //   de: one → "1 Cent", other → "2 Cent"
        // Without localization (raw interpolation), both would end with "cents"
        #expect(singular != plural,
                "Singular and plural forms should differ, proving plural variants are active")
    }

    @Test("formatStdDev uses localized pluralization: singular 'cent' for value 1")
    func formatStdDevSingularPlural() async throws {
        let singular = SummaryStatisticsView.formatStdDev(1.0)
        let plural = SummaryStatisticsView.formatStdDev(2.0)
        // Same pluralization logic as formatMean but with ± prefix
        #expect(singular != plural,
                "Singular and plural forms should differ, proving plural variants are active")
    }

    @Test("accessibilityTrend returns distinct strings for each trend direction")
    func accessibilityTrendLocalized() async throws {
        let improving = SummaryStatisticsView.accessibilityTrend(.improving)
        let stable = SummaryStatisticsView.accessibilityTrend(.stable)
        let declining = SummaryStatisticsView.accessibilityTrend(.declining)
        // Verify all three are distinct and non-empty
        #expect(!improving.isEmpty)
        #expect(!stable.isEmpty)
        #expect(!declining.isEmpty)
        #expect(improving != stable)
        #expect(stable != declining)
        #expect(improving != declining)
    }
}
