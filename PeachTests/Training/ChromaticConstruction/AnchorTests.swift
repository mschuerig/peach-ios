import Testing
import Foundation
@testable import Peach

@Suite("Anchor Tests")
struct AnchorTests {

    // MARK: - Construction

    @Test("Wraps a MIDINote without alteration")
    func wrapsMIDINote() async {
        let anchor = Anchor(note: MIDINote(60))
        #expect(anchor.note == MIDINote(60))
    }

    // MARK: - Frequency derivation

    @Test("frequency(in:referencePitch:) matches TuningSystem.frequency for equal temperament")
    func frequencyMatchesTuningSystemEqualTemperament() async {
        let anchor = Anchor(note: MIDINote(69)) // A4
        let frequency = anchor.frequency(in: .equalTemperament, referencePitch: .concert440)
        let expected = TuningSystem.equalTemperament.frequency(for: MIDINote(69), referencePitch: .concert440)
        #expect(frequency == expected)
    }

    @Test("frequency() of A4 equals reference pitch in equal temperament")
    func a4EqualsReferencePitch() async {
        let anchor = Anchor(note: MIDINote(69))
        let frequency = anchor.frequency(in: .equalTemperament, referencePitch: .concert440)
        #expect(frequency == Frequency(440.0))
    }

    @Test("Different anchors derive different frequencies in equal temperament")
    func differentAnchorsDifferentFrequencies() async {
        let lower = Anchor(note: MIDINote(60))
        let upper = Anchor(note: MIDINote(67))
        let lowerFreq = lower.frequency(in: .equalTemperament, referencePitch: .concert440)
        let upperFreq = upper.frequency(in: .equalTemperament, referencePitch: .concert440)
        #expect(lowerFreq < upperFreq)
    }

    @Test("Anchor delegates to TuningSystem (just intonation also resolves)")
    func justIntonationDelegation() async {
        // Anchor itself does not gate tuning system — only Ladder.init does.
        let anchor = Anchor(note: MIDINote(60))
        let frequency = anchor.frequency(in: .justIntonation, referencePitch: .concert440)
        let expected = TuningSystem.justIntonation.frequency(for: MIDINote(60), referencePitch: .concert440)
        #expect(frequency == expected)
    }

    // MARK: - Hashable / Equatable

    @Test("Anchors with same note are equal")
    func equality() async {
        #expect(Anchor(note: MIDINote(60)) == Anchor(note: MIDINote(60)))
        #expect(Anchor(note: MIDINote(60)) != Anchor(note: MIDINote(61)))
    }
}
