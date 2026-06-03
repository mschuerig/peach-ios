import Testing
import Foundation
@testable import Peach

@Suite("PianoKeyboardLayout Tests")
struct PianoKeyboardLayoutTests {

    // MARK: - Fixtures

    private static let fullPiano = PianoKeyboardLayout(
        noteRange: NoteRange(lowerBound: MIDINote(21), upperBound: MIDINote(108))
    )

    private static let oneOctave = PianoKeyboardLayout(
        noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
    )

    // MARK: - Pitch-class predicates

    @Test("C is a white key")
    func cIsWhite() async {
        #expect(PianoKeyboardLayout.isWhiteKey(MIDINote(60)))
    }

    @Test("C# is a black key")
    func cSharpIsBlack() async {
        #expect(!PianoKeyboardLayout.isWhiteKey(MIDINote(61)))
    }

    @Test("B is a white key")
    func bIsWhite() async {
        #expect(PianoKeyboardLayout.isWhiteKey(MIDINote(71)))
    }

    @Test("All C notes are octave boundaries")
    func cIsBoundary() async {
        for octave in -1...9 {
            let raw = (octave + 1) * 12
            if MIDINote.validRange.contains(raw) {
                #expect(PianoKeyboardLayout.isOctaveBoundary(MIDINote(raw)))
            }
        }
    }

    @Test("Non-C notes are not octave boundaries")
    func nonCNotBoundary() async {
        #expect(!PianoKeyboardLayout.isOctaveBoundary(MIDINote(61)))
        #expect(!PianoKeyboardLayout.isOctaveBoundary(MIDINote(69)))
        #expect(!PianoKeyboardLayout.isOctaveBoundary(MIDINote(71)))
    }

    // MARK: - White-key count

    @Test("88-key piano has 52 white keys")
    func fullPianoWhiteKeyCount() async {
        #expect(Self.fullPiano.whiteKeyCount == 52)
    }

    @Test("C4 to C5 inclusive has 8 white keys")
    func octaveWhiteKeyCount() async {
        #expect(Self.oneOctave.whiteKeyCount == 8)
    }

    // MARK: - x-position geometry

    @Test("Lower-bound white key sits at half a key-width from the left edge")
    func lowestWhiteKeyAtLeftEdge() async {
        let width: CGFloat = 1000
        let keyWidth = Self.fullPiano.whiteKeyWidth(totalWidth: width)
        let x = Self.fullPiano.xPosition(forNote: MIDINote(21), totalWidth: width)
        #expect(abs(x - keyWidth / 2) < 0.001)
    }

    @Test("Upper-bound white key sits at half a key-width from the right edge")
    func highestWhiteKeyAtRightEdge() async {
        let width: CGFloat = 1000
        let keyWidth = Self.fullPiano.whiteKeyWidth(totalWidth: width)
        let x = Self.fullPiano.xPosition(forNote: MIDINote(108), totalWidth: width)
        #expect(abs(x - (width - keyWidth / 2)) < 0.001)
    }

    @Test("x-position is strictly monotonic across all keys")
    func xPositionMonotonic() async {
        let width: CGFloat = 1000
        var previous = -CGFloat.infinity
        for raw in 21...108 {
            let x = Self.fullPiano.xPosition(forNote: MIDINote(raw), totalWidth: width)
            #expect(x > previous, "x-position should increase at MIDI \(raw)")
            previous = x
        }
    }

    @Test("Black key sits between its adjacent white keys")
    func blackKeyBetweenWhites() async {
        let width: CGFloat = 1000
        let cSharp4 = Self.fullPiano.xPosition(forNote: MIDINote(61), totalWidth: width)
        let c4 = Self.fullPiano.xPosition(forNote: MIDINote(60), totalWidth: width)
        let d4 = Self.fullPiano.xPosition(forNote: MIDINote(62), totalWidth: width)
        #expect(cSharp4 > c4)
        #expect(cSharp4 < d4)
        #expect(abs(cSharp4 - (c4 + d4) / 2) < 0.001)
    }

    // MARK: - Inverse hit-test

    @Test("Hit-test at a key's exact centre returns that key")
    func hitTestAtCentreRoundTrips() async {
        let width: CGFloat = 1000
        for raw in [21, 23, 36, 48, 60, 61, 65, 84, 96, 108] {
            let note = MIDINote(raw)
            let x = Self.fullPiano.xPosition(forNote: note, totalWidth: width)
            let hit = Self.fullPiano.midiNote(at: x, totalWidth: width)
            #expect(hit == note, "round-trip failed for MIDI \(raw): hit was \(hit.rawValue)")
        }
    }

    @Test("Hit-test between two adjacent keys returns the nearer one")
    func hitTestBetweenAdjacent() async {
        let width: CGFloat = 1000
        let c4X = Self.fullPiano.xPosition(forNote: MIDINote(60), totalWidth: width)
        let cSharp4X = Self.fullPiano.xPosition(forNote: MIDINote(61), totalWidth: width)
        let nearC = Self.fullPiano.midiNote(at: c4X + 0.1 * (cSharp4X - c4X), totalWidth: width)
        let nearCSharp = Self.fullPiano.midiNote(at: c4X + 0.9 * (cSharp4X - c4X), totalWidth: width)
        #expect(nearC == MIDINote(60))
        #expect(nearCSharp == MIDINote(61))
    }

    @Test("Hit-test at x = 0 returns the lower bound")
    func hitTestAtLeftEdgeReturnsLowerBound() async {
        let hit = Self.fullPiano.midiNote(at: 0, totalWidth: 1000)
        #expect(hit == MIDINote(21))
    }

    @Test("Hit-test at x = totalWidth returns the upper bound")
    func hitTestAtRightEdgeReturnsUpperBound() async {
        let hit = Self.fullPiano.midiNote(at: 1000, totalWidth: 1000)
        #expect(hit == MIDINote(108))
    }

    @Test("Hit-test outside the viewport clamps to the boundary note")
    func hitTestOutsideViewportClamps() async {
        let belowZero = Self.fullPiano.midiNote(at: -500, totalWidth: 1000)
        let pastWidth = Self.fullPiano.midiNote(at: 2500, totalWidth: 1000)
        #expect(belowZero == MIDINote(21))
        #expect(pastWidth == MIDINote(108))
    }

    // MARK: - Octave boundaries

    @Test("88-key piano lists C1 through C8 as boundaries")
    func fullPianoOctaveBoundaries() async {
        let names = Self.fullPiano.octaveBoundaries.map(\.name)
        #expect(names == ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"])
    }

    @Test("12-semitone range straddling a C lists that single boundary")
    func singleOctaveBoundary() async {
        let layout = PianoKeyboardLayout(
            noteRange: NoteRange(lowerBound: MIDINote(62), upperBound: MIDINote(74))
        )
        let boundaries = layout.octaveBoundaries.map(\.name)
        #expect(boundaries == ["C5"])
    }
}
