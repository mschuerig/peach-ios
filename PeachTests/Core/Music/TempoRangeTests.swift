import Testing
import Foundation
@testable import Peach

@Suite("TempoRange")
struct TempoRangeTests {

    @Test("contains returns true for tempo within bounds")
    func containsWithinBounds() async {
        let range = TempoRange.medium
        #expect(range.contains(TempoBPM(80)))
        #expect(range.contains(TempoBPM(100)))
        #expect(range.contains(TempoBPM(119)))
    }

    @Test("contains returns false for tempo outside bounds")
    func containsOutsideBounds() async {
        let range = TempoRange.medium
        #expect(!range.contains(TempoBPM(79)))
        #expect(!range.contains(TempoBPM(120)))
    }

    @Test("range(for:) returns correct range")
    func rangeLookup() async {
        #expect(TempoRange.range(for: TempoBPM(60)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(100)) == .medium)
        #expect(TempoRange.range(for: TempoBPM(150)) == .fast)
    }

    @Test("range(for:) returns nil for out-of-range tempo")
    func rangeLookupOutOfRange() async {
        #expect(TempoRange.range(for: TempoBPM(30)) == nil)
    }

    @Test("boundary values map correctly")
    func boundaryValues() async {
        #expect(TempoRange.range(for: TempoBPM(40)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(79)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(80)) == .medium)
        #expect(TempoRange.range(for: TempoBPM(119)) == .medium)
        #expect(TempoRange.range(for: TempoBPM(120)) == .fast)
        #expect(TempoRange.range(for: TempoBPM(200)) == .fast)
    }

    @Test("Comparable orders by lower bound")
    func comparable() async {
        #expect(TempoRange.slow < TempoRange.medium)
        #expect(TempoRange.medium < TempoRange.fast)
    }

    @Test("defaultRanges contains three ranges")
    func defaultRanges() async {
        #expect(TempoRange.defaultRanges.count == 3)
    }

    // MARK: - Spectrogram Ranges

    @Test("spectrogramRanges contains six ranges covering 40-200 BPM")
    func spectrogramRangesCount() async {
        #expect(TempoRange.spectrogramRanges.count == 6)
        #expect(TempoRange.spectrogramRanges.first?.lowerBound == TempoBPM(40))
        #expect(TempoRange.spectrogramRanges.last?.upperBound == TempoBPM(200))
    }

    @Test("spectrogramRanges are contiguous with no gaps")
    func spectrogramRangesContiguous() async {
        let ranges = TempoRange.spectrogramRanges
        for i in 1..<ranges.count {
            #expect(ranges[i].lowerBound.value == ranges[i - 1].upperBound.value + 1)
        }
    }

    @Test("spectrogramRanges boundaries align with defaultRanges boundaries")
    func spectrogramRangesAlignWithDefault() async {
        // Fine range boundaries must not straddle coarse range boundaries
        for fine in TempoRange.spectrogramRanges {
            let coarse = fine.enclosingDefaultRange
            #expect(coarse != nil)
            #expect(coarse!.contains(fine.lowerBound))
            #expect(coarse!.contains(fine.upperBound))
        }
    }

    @Test("enclosingDefaultRange maps each spectrogramRange to the correct coarse range")
    func enclosingDefaultRange() async {
        for fine in TempoRange.spectrogramRanges {
            let coarse = fine.enclosingDefaultRange
            #expect(coarse != nil)
            // Every BPM in the fine range must be within the coarse range
            #expect(coarse!.contains(fine.lowerBound))
            #expect(coarse!.contains(fine.upperBound))
        }
    }

    @Test("spectrogramRanges midpoints are reasonable")
    func spectrogramRangesMidpoints() async {
        for range in TempoRange.spectrogramRanges {
            let mid = range.midpointTempo
            #expect(range.contains(mid))
        }
    }

    @Test("spectrogramRanges displayName returns non-empty strings")
    func spectrogramRangesDisplayNames() async {
        for range in TempoRange.spectrogramRanges {
            #expect(!range.displayName.isEmpty)
        }
    }
}
