protocol PitchDiscriminationProfile: AnyObject {
    func update(note: Int, centOffset: Double, isCorrect: Bool)
    func weakSpots(count: Int) -> [Int]
    var overallMean: Double? { get }
    var overallStdDev: Double? { get }
    func statsForNote(_ note: Int) -> PerceptualNote
    func averageThreshold(midiRange: ClosedRange<Int>) -> Int?
    func setDifficulty(note: Int, difficulty: Double)
    func reset()
}
