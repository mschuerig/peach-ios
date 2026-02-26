import Testing
import SwiftUI
@testable import Peach

/// Tests for TrendAnalyzer trend computation
@Suite("TrendAnalyzer Tests")
struct TrendAnalyzerTests {

    // MARK: - Helpers

    /// Creates comparison records with known abs cent offsets
    private func makeRecords(absCentOffsets: [Double]) -> [ComparisonRecord] {
        absCentOffsets.enumerated().map { index, offset in
            ComparisonRecord(
                note1: 60,
                note2: 60,
                note2CentOffset: offset,
                isCorrect: true,
                timestamp: Date(timeIntervalSince1970: Double(index) * 60)
            )
        }
    }

    // MARK: - Task 2.2: Trend enum

    @Test("Trend enum has three cases")
    func trendEnumCases() {
        let improving = Trend.improving
        let stable = Trend.stable
        let declining = Trend.declining

        #expect(improving != stable)
        #expect(stable != declining)
    }

    // MARK: - Task 2.3: Trend computation

    @Test("Improving trend when recent mean is lower by >5%")
    func improvingTrend() async throws {
        // Earlier half: mean offset ~50, Later half: mean offset ~30
        // (30 - 50) / 50 = -40% → improving
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 30.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == .improving)
    }

    @Test("Declining trend when recent mean is higher by >5%")
    func decliningTrend() async throws {
        // Earlier half: mean offset ~30, Later half: mean offset ~50
        // (50 - 30) / 30 = +67% → declining
        let offsets = Array(repeating: 30.0, count: 10) + Array(repeating: 50.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == .declining)
    }

    @Test("Stable trend when change is within 5% threshold")
    func stableTrend() async throws {
        // Earlier half: mean offset ~50, Later half: mean offset ~51
        // (51 - 50) / 50 = +2% → stable (within 5%)
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 51.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == .stable)
    }

    // MARK: - Task 2.4: Threshold classification

    @Test("Exactly 5% decrease is still stable (not improving)")
    func boundaryStable() async throws {
        // Earlier: 100, Later: 95 → -5% exactly → stable
        let offsets = Array(repeating: 100.0, count: 10) + Array(repeating: 95.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == .stable)
    }

    @Test("Just over 5% decrease is improving")
    func justOverThreshold() async throws {
        // Earlier: 100, Later: 94.9 → -5.1% → improving
        let offsets = Array(repeating: 100.0, count: 10) + Array(repeating: 94.9, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == .improving)
    }

    // MARK: - Task 2.5: Minimum record count

    @Test("Nil trend when fewer than 20 records")
    func insufficientData() async throws {
        let records = makeRecords(absCentOffsets: Array(repeating: 50.0, count: 19))
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == nil)
    }

    @Test("Nil trend when empty records")
    func emptyRecords() async throws {
        let analyzer = TrendAnalyzer(records: [])

        #expect(analyzer.trend == nil)
    }

    @Test("Exactly 20 records computes trend")
    func exactMinimumRecords() async throws {
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 30.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend != nil)
    }

    // MARK: - Task 2.6: ComparisonObserver incremental update

    @Test("Incremental update via ComparisonObserver")
    func incrementalUpdate() async throws {
        // Start with 19 records (no trend yet)
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 30.0, count: 9)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        #expect(analyzer.trend == nil) // 19 records, not enough

        // Add one more record via observer to reach 20
        let comparison = Comparison(
            note1: 60,
            note2: 60,
            centDifference: Cents(30.0)
        )
        let completed = CompletedComparison(
            comparison: comparison,
            userAnsweredHigher: true,
            timestamp: Date(timeIntervalSince1970: 19 * 60)
        )
        analyzer.comparisonCompleted(completed)

        #expect(analyzer.trend != nil) // Now 20 records
    }

    // MARK: - Task 7.7: Environment key

    @Test("TrendAnalyzer environment key provides default value")
    func environmentKeyDefault() async throws {
        var env = EnvironmentValues()
        let analyzer = env.trendAnalyzer
        #expect(analyzer.trend == nil)
    }

    @Test("TrendAnalyzer environment key can be set and retrieved")
    func environmentKeySetAndGet() async throws {
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 30.0, count: 10)
        let records = makeRecords(absCentOffsets: offsets)
        let analyzer = TrendAnalyzer(records: records)

        var env = EnvironmentValues()
        env.trendAnalyzer = analyzer

        let retrieved = env.trendAnalyzer
        #expect(retrieved.trend == .improving)
    }
}
