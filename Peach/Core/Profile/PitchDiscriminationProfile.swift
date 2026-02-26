protocol PitchDiscriminationProfile: AnyObject {
    func update(note: MIDINote, centOffset: Double, isCorrect: Bool)
    func weakSpots(count: Int) -> [MIDINote]
    var overallMean: Double? { get }
    var overallStdDev: Double? { get }
    func statsForNote(_ note: MIDINote) -> PerceptualNote
    func averageThreshold(midiRange: ClosedRange<Int>) -> Int?
    func setDifficulty(note: MIDINote, difficulty: Double)
    func reset()
}
