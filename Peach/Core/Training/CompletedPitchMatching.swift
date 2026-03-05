import Foundation

struct CompletedPitchMatching {
    let referenceNote: MIDINote
    let targetNote: MIDINote
    let initialCentOffset: Cents
    let userCentError: Cents
    let tuningSystem: TuningSystem
    let timestamp: Date

    init(referenceNote: MIDINote, targetNote: MIDINote, initialCentOffset: Cents, userCentError: Cents, tuningSystem: TuningSystem, timestamp: Date = Date()) {
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.initialCentOffset = initialCentOffset
        self.userCentError = userCentError
        self.tuningSystem = tuningSystem
        self.timestamp = timestamp
    }
}
