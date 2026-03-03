import Testing
@testable import Peach

@Suite("NoteRange")
struct NoteRangeTests {

    // MARK: - Construction & Validation

    @Test("creates valid range with minimum 12-semitone gap")
    func validMinimumGap() async {
        let range = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        #expect(range.lowerBound == MIDINote(60))
        #expect(range.upperBound == MIDINote(72))
    }

    @Test("creates valid range with large gap")
    func validLargeGap() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.lowerBound == MIDINote(36))
        #expect(range.upperBound == MIDINote(84))
    }

    @Test("creates valid range at minimum MIDI boundary")
    func validMinimumMIDIBoundary() async {
        let range = NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(12))
        #expect(range.lowerBound == MIDINote(0))
        #expect(range.upperBound == MIDINote(12))
    }

    @Test("creates valid range at maximum MIDI boundary")
    func validMaximumMIDIBoundary() async {
        let range = NoteRange(lowerBound: MIDINote(115), upperBound: MIDINote(127))
        #expect(range.lowerBound == MIDINote(115))
        #expect(range.upperBound == MIDINote(127))
    }

    // MARK: - Equatable & Hashable

    @Test("equal ranges are equal")
    func equalRanges() async {
        let a = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let b = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(a == b)
    }

    @Test("different ranges are not equal")
    func differentRanges() async {
        let a = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let b = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(84))
        #expect(a != b)
    }

    @Test("can be used in a Set")
    func hashable() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let set: Set<NoteRange> = [range, range]
        #expect(set.count == 1)
    }

    // MARK: - contains

    @Test("contains note at lowerBound")
    func containsLowerBound() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(36)))
    }

    @Test("contains note at upperBound")
    func containsUpperBound() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(84)))
    }

    @Test("contains note in middle")
    func containsMiddle() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(60)))
    }

    @Test("does not contain note below lowerBound")
    func doesNotContainBelow() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(!range.contains(MIDINote(35)))
    }

    @Test("does not contain note above upperBound")
    func doesNotContainAbove() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(!range.contains(MIDINote(85)))
    }

    @Test("contains note at MIDI zero boundary")
    func containsMIDIZero() async {
        let range = NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(12))
        #expect(range.contains(MIDINote(0)))
        #expect(!range.contains(MIDINote(127)))
    }

    @Test("contains note at MIDI 127 boundary")
    func containsMIDI127() async {
        let range = NoteRange(lowerBound: MIDINote(115), upperBound: MIDINote(127))
        #expect(range.contains(MIDINote(127)))
        #expect(!range.contains(MIDINote(0)))
    }

    // MARK: - clamped

    @Test("clamps note below range to lowerBound")
    func clampsBelowToLower() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(20)) == MIDINote(36))
    }

    @Test("clamps note above range to upperBound")
    func clampsAboveToUpper() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(100)) == MIDINote(84))
    }

    @Test("clamps to MIDI zero boundary")
    func clampsMIDIZeroBoundary() async {
        let range = NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(12))
        #expect(range.clamped(MIDINote(0)) == MIDINote(0))
        #expect(range.clamped(MIDINote(12)) == MIDINote(12))
    }

    @Test("clamps to MIDI 127 boundary")
    func clampsMIDI127Boundary() async {
        let range = NoteRange(lowerBound: MIDINote(115), upperBound: MIDINote(127))
        #expect(range.clamped(MIDINote(127)) == MIDINote(127))
        #expect(range.clamped(MIDINote(0)) == MIDINote(115))
    }

    @Test("clamped returns same note when within range")
    func clampedWithinRange() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(60)) == MIDINote(60))
    }

    @Test("clamped returns same note at boundaries")
    func clampedAtBoundaries() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(36)) == MIDINote(36))
        #expect(range.clamped(MIDINote(84)) == MIDINote(84))
    }

    // MARK: - semitoneSpan

    @Test("semitoneSpan returns difference between bounds")
    func semitoneSpanMinimum() async {
        let range = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        #expect(range.semitoneSpan == 12)
    }

    @Test("semitoneSpan for default range C2-C6 is 48")
    func semitoneSpanDefault() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.semitoneSpan == 48)
    }
}
