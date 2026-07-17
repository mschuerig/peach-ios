import Foundation

struct CompletedPitchMatchingTrial {
    let referenceNote: MIDINote
    let targetNote: MIDINote
    let initialCentOffset: Cents
    let interval: DirectedInterval
    let userCentError: Cents
    let tuningSystem: TuningSystem
    let timestamp: Date

    init(referenceNote: MIDINote, targetNote: MIDINote, initialCentOffset: Cents, interval: DirectedInterval, userCentError: Cents, tuningSystem: TuningSystem, timestamp: Date = Date()) {
        precondition(
            referenceNote.transposed(by: interval) == targetNote,
            "targetNote \(targetNote.rawValue) is not referenceNote \(referenceNote.rawValue) transposed by \(interval)"
        )
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.initialCentOffset = initialCentOffset
        self.interval = interval
        self.userCentError = userCentError
        self.tuningSystem = tuningSystem
        self.timestamp = timestamp
    }
}
