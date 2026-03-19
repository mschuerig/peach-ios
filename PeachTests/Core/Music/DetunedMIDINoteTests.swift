import Testing
import Foundation
@testable import Peach

@Suite("DetunedMIDINote Tests")
struct DetunedMIDINoteTests {

    // MARK: - Construction (AC #1)

    @Test("stores note and offset")
    func storesNoteAndOffset() async {
        let note = DetunedMIDINote(note: MIDINote(60), offset: Cents(25))
        #expect(note.note == MIDINote(60))
        #expect(note.offset == Cents(25))
    }

    @Test("stores negative cent offset")
    func storesNegativeOffset() async {
        let note = DetunedMIDINote(note: MIDINote(69), offset: Cents(-30.5))
        #expect(note.note == MIDINote(69))
        #expect(note.offset == Cents(-30.5))
    }

    @Test("stores zero cent offset")
    func storesZeroOffset() async {
        let note = DetunedMIDINote(note: MIDINote(48), offset: Cents(0))
        #expect(note.note == MIDINote(48))
        #expect(note.offset == Cents(0))
    }

    // MARK: - Convenience Init (AC #2)

    @Test("convenience init sets offset to zero")
    func convenienceInitZeroOffset() async {
        let note = DetunedMIDINote(MIDINote(60))
        #expect(note.note == MIDINote(60))
        #expect(note.offset == Cents(0))
    }

    @Test("convenience init with A4")
    func convenienceInitA4() async {
        let note = DetunedMIDINote(MIDINote(69))
        #expect(note.note == MIDINote(69))
        #expect(note.offset == Cents(0))
    }

    // MARK: - Hashable (AC #1)

    @Test("can be used as Set element")
    func hashableSetElement() async {
        let note1 = DetunedMIDINote(note: MIDINote(60), offset: Cents(0))
        let note2 = DetunedMIDINote(note: MIDINote(60), offset: Cents(0))
        let note3 = DetunedMIDINote(note: MIDINote(60), offset: Cents(25))
        let set: Set<DetunedMIDINote> = [note1, note2, note3]
        #expect(set.count == 2)
    }

    @Test("can be used as Dictionary key")
    func hashableDictionaryKey() async {
        let note = DetunedMIDINote(note: MIDINote(69), offset: Cents(0))
        var dict: [DetunedMIDINote: String] = [:]
        dict[note] = "A4"
        #expect(dict[note] == "A4")
    }

    @Test("different offsets produce different hash values")
    func differentOffsetsAreDistinct() async {
        let note1 = DetunedMIDINote(note: MIDINote(60), offset: Cents(0))
        let note2 = DetunedMIDINote(note: MIDINote(60), offset: Cents(1))
        #expect(note1 != note2)
    }

    @Test("different notes produce different hash values")
    func differentNotesAreDistinct() async {
        let note1 = DetunedMIDINote(note: MIDINote(60), offset: Cents(0))
        let note2 = DetunedMIDINote(note: MIDINote(61), offset: Cents(0))
        #expect(note1 != note2)
    }

    // MARK: - Sendable (AC #1)

    @Test("can be sent across concurrency boundaries")
    func sendableAcrossBoundary() async {
        let note = DetunedMIDINote(note: MIDINote(69), offset: Cents(50))
        let result = await Task.detached { note }.value
        #expect(result == note)
    }
}
