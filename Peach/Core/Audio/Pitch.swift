import Foundation

struct Pitch: Hashable, Sendable {
    let note: MIDINote
    let cents: Cents

    func frequency(referencePitch: Frequency = .concert440) -> Frequency {
        let semitones = Double(note.rawValue - 69) + cents.rawValue / 100.0
        return Frequency(referencePitch.rawValue * pow(2.0, semitones / 12.0))
    }
}

extension Pitch {
    init(frequency: Frequency, referencePitch: Frequency = .concert440) {
        let exactMidi = 69.0 + 12.0 * log2(frequency.rawValue / referencePitch.rawValue)
        let roundedMidi = Int(exactMidi.rounded())
        let centsRemainder = (exactMidi - Double(roundedMidi)) * 100.0
        self.init(
            note: MIDINote(roundedMidi.clamped(to: MIDINote.validRange)),
            cents: Cents(centsRemainder)
        )
    }
}
