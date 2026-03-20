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
}
