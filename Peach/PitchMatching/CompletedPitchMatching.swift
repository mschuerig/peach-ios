import Foundation

struct CompletedPitchMatching {
    let referenceNote: MIDINote
    let initialCentOffset: Double
    let userCentError: Double
    let timestamp: Date

    init(referenceNote: MIDINote, initialCentOffset: Double, userCentError: Double, timestamp: Date = Date()) {
        self.referenceNote = referenceNote
        self.initialCentOffset = initialCentOffset
        self.userCentError = userCentError
        self.timestamp = timestamp
    }
}
