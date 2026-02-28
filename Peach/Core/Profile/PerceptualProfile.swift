import Foundation
import OSLog

@Observable
final class PerceptualProfile: PitchDiscriminationProfile, PitchMatchingProfile {

    // MARK: - Properties

    private var noteStats: [PerceptualNote]

    // Matching aggregate accumulators (Welford's online algorithm)
    private var matchingCount: Int = 0
    private var matchingMeanAbs: Double = 0.0
    private var matchingM2: Double = 0.0

    private let logger = Logger(subsystem: "com.peach.app", category: "PerceptualProfile")

    // MARK: - Initialization

    init() {
        self.noteStats = Array(repeating: PerceptualNote(), count: 128)
        logger.info("PerceptualProfile initialized (cold start)")
    }

    // MARK: - Incremental Update

    func update(note: MIDINote, centOffset: Double, isCorrect: Bool) {
        let index = note.rawValue

        var stats = noteStats[index]

        stats.sampleCount += 1
        let delta = centOffset - stats.mean
        stats.mean += delta / Double(stats.sampleCount)
        let delta2 = centOffset - stats.mean
        stats.m2 += delta * delta2

        let variance = stats.sampleCount < 2 ? 0.0 : stats.m2 / Double(stats.sampleCount - 1)
        stats.stdDev = sqrt(variance)

        noteStats[index] = stats

        logger.debug("Updated note \(note.rawValue): mean=\(stats.mean), stdDev=\(stats.stdDev), count=\(stats.sampleCount), correct=\(isCorrect)")
    }

    // MARK: - Weak Spot Identification

    func weakSpots(count: Int = 10) -> [MIDINote] {
        var scoredNotes: [(note: Int, score: Double)] = []

        for (midiNote, stats) in noteStats.enumerated() {
            let score: Double
            if stats.sampleCount == 0 {
                score = Double.infinity
            } else {
                score = stats.mean
            }
            scoredNotes.append((note: midiNote, score: score))
        }

        scoredNotes.sort { $0.score > $1.score }

        return scoredNotes.prefix(count).map { MIDINote($0.note) }
    }

    // MARK: - Summary Statistics

    var overallMean: Double? {
        let trainedStats = noteStats.filter { $0.sampleCount > 0 }
        guard !trainedStats.isEmpty else { return nil }

        let sum = trainedStats.reduce(0.0) { $0 + $1.mean }
        return sum / Double(trainedStats.count)
    }

    var overallStdDev: Double? {
        let trainedStats = noteStats.filter { $0.sampleCount > 0 }
        guard trainedStats.count >= 2 else { return nil }

        let means = trainedStats.map { $0.mean }
        let mean = means.reduce(0.0, +) / Double(means.count)

        let variance = means
            .map { pow($0 - mean, 2) }
            .reduce(0.0, +) / Double(means.count - 1)

        return sqrt(variance)
    }

    func averageThreshold(midiRange: ClosedRange<Int>) -> Int? {
        let trainedNotes = midiRange.filter { statsForNote(MIDINote($0)).isTrained }
        guard !trainedNotes.isEmpty else { return nil }
        let avg = trainedNotes.map { statsForNote(MIDINote($0)).mean }.reduce(0.0, +) / Double(trainedNotes.count)
        return Int(avg)
    }

    // MARK: - Accessors

    func statsForNote(_ note: MIDINote) -> PerceptualNote {
        return noteStats[note.rawValue]
    }

    // MARK: - Reset

    func reset() {
        noteStats = Array(repeating: PerceptualNote(), count: 128)
        logger.info("PerceptualProfile reset to cold start")
    }

    // MARK: - Regional Difficulty Management

    func setDifficulty(note: MIDINote, difficulty: Double) {
        noteStats[note.rawValue].currentDifficulty = difficulty
        logger.debug("Set difficulty for note \(note.rawValue): \(difficulty) cents")
    }

    // MARK: - Matching Statistics (PitchMatchingProfile)

    func updateMatching(note: MIDINote, centError: Double) {
        let absError = abs(centError)
        matchingCount += 1
        let delta = absError - matchingMeanAbs
        matchingMeanAbs += delta / Double(matchingCount)
        let delta2 = absError - matchingMeanAbs
        matchingM2 += delta * delta2
    }

    var matchingMean: Double? {
        matchingCount > 0 ? matchingMeanAbs : nil
    }

    var matchingStdDev: Double? {
        guard matchingCount >= 2 else { return nil }
        return sqrt(matchingM2 / Double(matchingCount - 1))
    }

    var matchingSampleCount: Int {
        matchingCount
    }

    func resetMatching() {
        matchingCount = 0
        matchingMeanAbs = 0.0
        matchingM2 = 0.0
        logger.info("Matching statistics reset")
    }
}

// MARK: - PerceptualNote

struct PerceptualNote {
    var mean: Double
    var stdDev: Double
    var m2: Double
    var sampleCount: Int
    var currentDifficulty: Double

    init(mean: Double = 0.0, stdDev: Double = 0.0, m2: Double = 0.0, sampleCount: Int = 0, currentDifficulty: Double = 100.0) {
        self.mean = mean
        self.stdDev = stdDev
        self.m2 = m2
        self.sampleCount = sampleCount
        self.currentDifficulty = currentDifficulty
    }

    var isTrained: Bool {
        sampleCount > 0
    }
}

// MARK: - ComparisonObserver Conformance

extension PerceptualProfile: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        let comparison = completed.comparison
        let centOffset = comparison.targetNote.offset.magnitude

        update(
            note: comparison.referenceNote,
            centOffset: centOffset,
            isCorrect: completed.isCorrect
        )
    }
}

// MARK: - PitchMatchingObserver Conformance

extension PerceptualProfile: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        updateMatching(note: result.referenceNote, centError: result.userCentError)
    }
}
