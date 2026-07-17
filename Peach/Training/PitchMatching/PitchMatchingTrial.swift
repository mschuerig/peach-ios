struct PitchMatchingTrial: PitchTrial {
    let referenceNote: MIDINote
    let targetNote: MIDINote
    let initialCentOffset: Cents
    let interval: DirectedInterval

    init(referenceNote: MIDINote, targetNote: MIDINote, initialCentOffset: Cents, interval: DirectedInterval) {
        precondition(
            referenceNote.transposed(by: interval) == targetNote,
            "targetNote \(targetNote.rawValue) is not referenceNote \(referenceNote.rawValue) transposed by \(interval)"
        )
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.initialCentOffset = initialCentOffset
        self.interval = interval
    }
}
