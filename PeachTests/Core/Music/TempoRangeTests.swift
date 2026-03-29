import Testing
import Foundation
@testable import Peach

@Suite("TempoRange")
struct TempoRangeTests {

    @Test("contains returns true for tempo within bounds")
    func containsWithinBounds() async {
        let range = TempoRange.moderate
        #expect(range.contains(TempoBPM(80)))
        #expect(range.contains(TempoBPM(90)))
        #expect(range.contains(TempoBPM(99)))
    }

    @Test("contains returns false for tempo outside bounds")
    func containsOutsideBounds() async {
        let range = TempoRange.moderate
        #expect(!range.contains(TempoBPM(79)))
        #expect(!range.contains(TempoBPM(100)))
    }

    @Test("range(for:) returns correct range")
    func rangeLookup() async {
        #expect(TempoRange.range(for: TempoBPM(50)) == .verySlow)
        #expect(TempoRange.range(for: TempoBPM(70)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(90)) == .moderate)
        #expect(TempoRange.range(for: TempoBPM(110)) == .brisk)
        #expect(TempoRange.range(for: TempoBPM(140)) == .fast)
        #expect(TempoRange.range(for: TempoBPM(180)) == .veryFast)
    }

    @Test("range(for:) returns nil for out-of-range tempo")
    func rangeLookupOutOfRange() async {
        #expect(TempoRange.range(for: TempoBPM(30)) == nil)
    }

    @Test("boundary values map correctly")
    func boundaryValues() async {
        #expect(TempoRange.range(for: TempoBPM(40)) == .verySlow)
        #expect(TempoRange.range(for: TempoBPM(59)) == .verySlow)
        #expect(TempoRange.range(for: TempoBPM(60)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(79)) == .slow)
        #expect(TempoRange.range(for: TempoBPM(80)) == .moderate)
        #expect(TempoRange.range(for: TempoBPM(99)) == .moderate)
        #expect(TempoRange.range(for: TempoBPM(100)) == .brisk)
        #expect(TempoRange.range(for: TempoBPM(119)) == .brisk)
        #expect(TempoRange.range(for: TempoBPM(120)) == .fast)
        #expect(TempoRange.range(for: TempoBPM(159)) == .fast)
        #expect(TempoRange.range(for: TempoBPM(160)) == .veryFast)
        #expect(TempoRange.range(for: TempoBPM(200)) == .veryFast)
    }

    @Test("Comparable orders by lower bound")
    func comparable() async {
        #expect(TempoRange.verySlow < TempoRange.slow)
        #expect(TempoRange.slow < TempoRange.moderate)
        #expect(TempoRange.moderate < TempoRange.brisk)
        #expect(TempoRange.brisk < TempoRange.fast)
        #expect(TempoRange.fast < TempoRange.veryFast)
    }

    @Test("defaultRanges contains six ranges")
    func defaultRanges() async {
        #expect(TempoRange.defaultRanges.count == 6)
    }

    @Test("defaultRanges are contiguous with no gaps")
    func defaultRangesContiguous() async {
        let ranges = TempoRange.defaultRanges
        for i in 1..<ranges.count {
            #expect(ranges[i].lowerBound.value == ranges[i - 1].upperBound.value + 1)
        }
    }

    @Test("defaultRanges cover 40-200 BPM")
    func defaultRangesCoverage() async {
        #expect(TempoRange.defaultRanges.first?.lowerBound == TempoBPM(40))
        #expect(TempoRange.defaultRanges.last?.upperBound == TempoBPM(200))
    }

    @Test("defaultRanges midpoints are within their range")
    func defaultRangesMidpoints() async {
        for range in TempoRange.defaultRanges {
            let mid = range.midpointTempo
            #expect(range.contains(mid))
        }
    }

    @Test("defaultRanges displayName returns non-empty strings")
    func defaultRangesDisplayNames() async {
        for range in TempoRange.defaultRanges {
            #expect(!range.displayName.isEmpty)
        }
    }
}
