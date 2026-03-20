struct RhythmTempoStats: Sendable {
    let mean: RhythmOffset
    let stdDev: RhythmOffset
    let sampleCount: Int
    let currentDifficulty: RhythmOffset

    nonisolated init(mean: RhythmOffset, stdDev: RhythmOffset, sampleCount: Int, currentDifficulty: RhythmOffset) {
        self.mean = mean
        self.stdDev = stdDev
        self.sampleCount = sampleCount
        self.currentDifficulty = currentDifficulty
    }
}

protocol RhythmProfile: AnyObject {
    func updateRhythmComparison(tempo: TempoBPM, offset: RhythmOffset, isCorrect: Bool)
    func updateRhythmMatching(tempo: TempoBPM, userOffset: RhythmOffset)
    func rhythmStats(tempo: TempoBPM, direction: RhythmDirection) -> RhythmTempoStats
    var trainedTempos: [TempoBPM] { get }
    var rhythmOverallAccuracy: Double? { get }
    func resetRhythm()
}
