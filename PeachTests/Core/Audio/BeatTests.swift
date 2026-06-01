import Foundation
import Testing
@testable import Peach

@Suite("Beat / Subdivision")
struct BeatTests {

    private static let sampleRate = SampleRate.standard44100
    private static let beatDuration: Int64 = 22050  // 120 BPM @ 44100 Hz
    private static let channel = MIDIChannel(0)
    private static let clickNote = MIDINote(76)
    private static let noteOffDelay: Int64 = 100

    private static let noteOnStatus = SoundFontEngine.noteOnBase | channel.rawValue
    private static let noteOffStatus = SoundFontEngine.noteOffBase | channel.rawValue

    private func makeFlatBeat() -> Beat {
        Beat(subdivisions: (0..<4).map { i in
            .note(velocity: i == 0 ? RhythmVelocity.accent : RhythmVelocity.normal, offset: .zero)
        })
    }

    private func events(for beat: Beat, beatOffset: Int64 = 0) -> [ScheduledMIDIEvent] {
        beat.events(
            beatOffset: beatOffset,
            beatDuration: Self.beatDuration,
            sampleRate: Self.sampleRate,
            channel: Self.channel,
            clickNote: Self.clickNote,
            noteOffDelaySamples: Self.noteOffDelay
        )
    }

    // MARK: - Flat beat

    @Test("flat 4-subdivision beat emits 4 note-on and 4 note-off events at equal spacing")
    func flatBeatEmitsAllNotesEquallySpaced() async {
        let events = events(for: makeFlatBeat())
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
        let noteOffs = events.filter { $0.midiStatus == Self.noteOffStatus }
        #expect(noteOns.count == 4)
        #expect(noteOffs.count == 4)

        let expectedSubdivision = Self.beatDuration / 4
        let sortedOns = noteOns.sorted { $0.sampleOffset < $1.sampleOffset }
        for (i, on) in sortedOns.enumerated() {
            #expect(on.sampleOffset == Int64(i) * expectedSubdivision)
        }
    }

    @Test("flat beat first subdivision uses accent velocity, others use normal")
    func flatBeatVelocityPlacement() async {
        let events = events(for: makeFlatBeat())
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }

        #expect(noteOns[0].velocity == RhythmVelocity.accent.rawValue)
        for i in 1..<4 {
            #expect(noteOns[i].velocity == RhythmVelocity.normal.rawValue)
        }
    }

    @Test("beatOffset shifts every event by the same amount")
    func beatOffsetShiftsEvents() async {
        let offset: Int64 = 100_000
        let base = events(for: makeFlatBeat(), beatOffset: 0)
        let shifted = events(for: makeFlatBeat(), beatOffset: offset)
        #expect(base.count == shifted.count)
        for (b, s) in zip(base, shifted) {
            #expect(s.sampleOffset == b.sampleOffset + offset)
        }
    }

    @Test("note-off follows note-on by noteOffDelaySamples")
    func noteOffDelayApplied() async {
        let events = events(for: makeFlatBeat())
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }
        let noteOffs = events.filter { $0.midiStatus == Self.noteOffStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }
        for (on, off) in zip(noteOns, noteOffs) {
            #expect(off.sampleOffset - on.sampleOffset == Self.noteOffDelay)
        }
    }

    @Test("note-off delay is clamped to subdivisionDuration - 1 to prevent overlap")
    func noteOffDelayClampedToSubdivision() async {
        // Request a delay larger than the subdivision can hold; expect it to be clamped.
        let overlongDelay: Int64 = Self.beatDuration / 4 + 1_000  // > subdivisionDuration
        let events = makeFlatBeat().events(
            beatOffset: 0,
            beatDuration: Self.beatDuration,
            sampleRate: Self.sampleRate,
            channel: Self.channel,
            clickNote: Self.clickNote,
            noteOffDelaySamples: overlongDelay
        )
        let subdivisionDuration = Self.beatDuration / 4
        let expectedDelay = subdivisionDuration - 1
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }
        let noteOffs = events.filter { $0.midiStatus == Self.noteOffStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }
        for (on, off) in zip(noteOns, noteOffs) {
            #expect(off.sampleOffset - on.sampleOffset == expectedDelay)
        }
    }

    @Test("emitted events use the supplied click note")
    func clickNoteIsUsed() async {
        let events = events(for: makeFlatBeat())
        for event in events {
            #expect(event.midiNote == UInt8(Self.clickNote.rawValue))
        }
    }

    // MARK: - Rests

    @Test("subdivision with .rest contributes no events at that index")
    func restContributesNoEvents() async {
        let beat = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let events = events(for: beat)
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
        #expect(noteOns.count == 3)

        let subdivisionDuration = Self.beatDuration / 4
        let gapOffset = Int64(1) * subdivisionDuration
        #expect(!noteOns.contains { $0.sampleOffset == gapOffset })
    }

    @Test("beat consisting entirely of rests produces no events")
    func allRestsProducesNoEvents() async {
        let beat = Beat(subdivisions: [.rest, .rest, .rest, .rest])
        let events = events(for: beat)
        #expect(events.isEmpty)
    }

    // MARK: - Offsets (signed)

    @Test("positive .note offset shifts that note's noteOn later by Duration → samples")
    func positiveOffsetShiftsNoteLater() async {
        let offsetMs: Double = 10
        let beat = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .milliseconds(offsetMs)),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let events = events(for: beat)
        let subdivisionDuration = Self.beatDuration / 4
        let expectedShift = Self.sampleRate.samples(for: .milliseconds(offsetMs))
        let expectedNoteOn = Int64(1) * subdivisionDuration + expectedShift

        let shiftedNoteOn = events.first {
            $0.midiStatus == Self.noteOnStatus && $0.sampleOffset == expectedNoteOn
        }
        #expect(shiftedNoteOn != nil)
    }

    @Test("negative .note offset shifts that note's noteOn earlier")
    func negativeOffsetShiftsNoteEarlier() async {
        let offsetMs: Double = -10
        let beat = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .milliseconds(offsetMs)),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let events = events(for: beat, beatOffset: 1_000_000)
        let subdivisionDuration = Self.beatDuration / 4
        let expectedShift = Self.sampleRate.samples(for: .milliseconds(offsetMs))
        let expectedNoteOn = 1_000_000 + Int64(2) * subdivisionDuration + expectedShift

        let shiftedNoteOn = events.first {
            $0.midiStatus == Self.noteOnStatus && $0.sampleOffset == expectedNoteOn
        }
        #expect(shiftedNoteOn != nil)
    }

    // MARK: - Nested beat (tuplet)

    @Test("nested beat emits inner subdivisions equally spaced within the outer slot")
    func nestedBeatEqualSpacingWithinOuterSlot() async {
        // Outer beat with 2 subdivisions; the second is a .nested(Beat) of 3 equal notes (triplet).
        let nested = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let beat = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .nested(nested),
        ])
        let events = events(for: beat)
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }

        // 1 outer + 3 inner = 4 noteOns
        #expect(noteOns.count == 4)

        let outerSubdivision = Self.beatDuration / 2
        let innerSubdivision = outerSubdivision / 3
        let expectedOffsets: [Int64] = [
            0,
            outerSubdivision,
            outerSubdivision + innerSubdivision,
            outerSubdivision + 2 * innerSubdivision,
        ]
        #expect(noteOns.map(\.sampleOffset) == expectedOffsets)
    }

    @Test("nested beat respects beatOffset of the outer beat")
    func nestedBeatRespectsOuterOffset() async {
        let nested = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let beat = Beat(subdivisions: [.nested(nested)])
        let outerOffset: Int64 = 500_000
        let events = events(for: beat, beatOffset: outerOffset)
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
            .sorted { $0.sampleOffset < $1.sampleOffset }

        let innerSubdivision = Self.beatDuration / 2
        #expect(noteOns.map(\.sampleOffset) == [outerOffset, outerOffset + innerSubdivision])
    }

    @Test("nested beat may itself contain a rest")
    func nestedBeatRest() async {
        let nested = Beat(subdivisions: [
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero),
        ])
        let beat = Beat(subdivisions: [.nested(nested)])
        let events = events(for: beat)
        let noteOns = events.filter { $0.midiStatus == Self.noteOnStatus }
        #expect(noteOns.count == 2)
    }
}
