import Foundation

struct Pitch: Hashable, Sendable {
    let note: MIDINote
    let cents: Cents

    func frequency(referencePitch: Frequency = .concert440) -> Frequency {
        let semitones = Double(note.rawValue - 69) + cents.rawValue / 100.0
        return Frequency(referencePitch.rawValue * pow(2.0, semitones / 12.0))
    }
}
