protocol PitchComparisonProfile: AnyObject {
    func update(note: MIDINote, centOffset: Cents, isCorrect: Bool)
    func weakSpots(count: Int) -> [MIDINote]
    var overallMean: Cents? { get }
    var overallStdDev: Cents? { get }
    func statsForNote(_ note: MIDINote) -> PerceptualNote
    func averageThreshold(noteRange: NoteRange) -> Cents?
    func setDifficulty(note: MIDINote, difficulty: Cents)
    func reset()
}
