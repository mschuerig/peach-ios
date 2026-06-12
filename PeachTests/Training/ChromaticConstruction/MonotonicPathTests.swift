import Testing
@testable import Peach

@Suite("MonotonicPath")
struct MonotonicPathTests {

    @Test("produces ascending semitone path for an ascending P5")
    func ascendingP5() throws {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.perfectFifth)
        )
        #expect(path.steps == Array(repeating: Direction.up, count: 7))
        #expect(path.interiorPositionCount == 6)
        #expect(path.upperAnchor == MIDINote(67))
    }

    @Test("produces descending semitone path for a descending octave")
    func descendingOctave() throws {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(72),
            outerInterval: .down(.octave)
        )
        #expect(path.steps == Array(repeating: Direction.down, count: 12))
        #expect(path.upperAnchor == MIDINote(60))
    }

    @Test("ascending minor third produces 3 .up steps")
    func ascendingMinorThird() throws {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(60),
            outerInterval: .up(.minorThird)
        )
        #expect(path.steps == [.up, .up, .up])
    }

    @Test("descending major sixth produces 9 .down steps")
    func descendingMajorSixth() throws {
        let path = try MonotonicPath().chromaticPath(
            lowerAnchor: MIDINote(72),
            outerInterval: .down(.majorSixth)
        )
        #expect(path.steps == Array(repeating: Direction.down, count: 9))
    }

    @Test("throws degeneratePath for outerInterval = .prime")
    func rejectsPrime() {
        #expect(throws: ChromaticConstructionError.self) {
            try MonotonicPath().chromaticPath(
                lowerAnchor: MIDINote(60),
                outerInterval: .up(.prime)
            )
        }
    }

    @Test("throws pathExceedsMIDIRange when ascending walk exits MIDI range")
    func ascendingMIDIOverflow() {
        #expect(throws: ChromaticConstructionError.self) {
            try MonotonicPath().chromaticPath(
                lowerAnchor: MIDINote(120),
                outerInterval: .up(.octave)
            )
        }
    }
}
