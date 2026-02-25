import Foundation
import OSLog

/// Perceptual profile tracking pitch discrimination ability per MIDI note
/// Aggregates comparison data into per-note statistics (mean, stdDev, sample count)
/// Supports cold start, incremental updates, and weak spot identification
@Observable
final class PerceptualProfile: PitchDiscriminationProfile {

    // MARK: - Properties

    /// Per-note statistics indexed by MIDI note (0-127)
    private var noteStats: [PerceptualNote]

    /// Logger for profile operations
    private let logger = Logger(subsystem: "com.peach.app", category: "PerceptualProfile")

    // MARK: - Initialization

    /// Creates an empty PerceptualProfile
    /// All 128 MIDI notes start with zero statistics (cold start state)
    /// Populate the profile by calling update() for each comparison result
    init() {
        // Initialize all 128 MIDI notes with empty statistics
        self.noteStats = Array(repeating: PerceptualNote(), count: 128)
        logger.info("PerceptualProfile initialized (cold start)")
    }

    // MARK: - Incremental Update

    /// Updates the profile incrementally with a new comparison result
    /// Uses Welford's online algorithm to avoid re-aggregating all records
    /// - Parameters:
    ///   - note: MIDI note (0-127)
    ///   - centOffset: Unsigned cent value (absolute threshold, from Comparison.centDifference)
    ///   - isCorrect: Whether user answered correctly
    func update(note: Int, centOffset: Double, isCorrect: Bool) {
        guard note >= 0 && note < 128 else {
            logger.error("Invalid MIDI note: \(note)")
            return
        }

        var stats = noteStats[note]

        // Welford's online algorithm for incremental mean and variance
        // Track ALL comparisons (correct and incorrect) to properly estimate detection threshold
        stats.sampleCount += 1
        let delta = centOffset - stats.mean
        stats.mean += delta / Double(stats.sampleCount)
        let delta2 = centOffset - stats.mean
        stats.m2 += delta * delta2

        // Update standard deviation
        let variance = stats.sampleCount < 2 ? 0.0 : stats.m2 / Double(stats.sampleCount - 1)
        stats.stdDev = sqrt(variance)

        noteStats[note] = stats

        logger.debug("Updated note \(note): mean=\(stats.mean), stdDev=\(stats.stdDev), count=\(stats.sampleCount), correct=\(isCorrect)")
    }

    // MARK: - Weak Spot Identification

    /// Identifies weak spots (notes with poorest discrimination)
    /// Prioritizes: 1) Untrained notes, 2) High threshold notes
    /// - Parameter count: Number of weak spots to return (default: 10)
    /// - Returns: Array of MIDI notes (0-127) representing weak spots
    func weakSpots(count: Int = 10) -> [Int] {
        var scoredNotes: [(note: Int, score: Double)] = []

        for (midiNote, stats) in noteStats.enumerated() {
            let score: Double
            if stats.sampleCount == 0 {
                // Untrained notes get highest priority (infinite threshold)
                score = Double.infinity
            } else {
                // Trained notes: higher threshold = worse discrimination = higher score
                score = stats.mean
            }
            scoredNotes.append((note: midiNote, score: score))
        }

        // Sort by score descending (worst discrimination first)
        scoredNotes.sort { $0.score > $1.score }

        // Return top N MIDI notes
        return scoredNotes.prefix(count).map { $0.note }
    }

    // MARK: - Summary Statistics

    /// Overall mean detection threshold across all trained notes
    /// - Returns: Arithmetic mean of per-note means, or nil if no data
    var overallMean: Double? {
        let trainedStats = noteStats.filter { $0.sampleCount > 0 }
        guard !trainedStats.isEmpty else { return nil }

        let sum = trainedStats.reduce(0.0) { $0 + $1.mean }
        return sum / Double(trainedStats.count)
    }

    /// Overall standard deviation across all trained notes
    /// - Returns: Standard deviation of per-note means, or nil if no data
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

    /// Average detection threshold for trained notes in a specific range
    /// - Parameter midiRange: The MIDI note range to compute over
    /// - Returns: Rounded average threshold in cents, or nil if no trained notes in range
    func averageThreshold(midiRange: ClosedRange<Int>) -> Int? {
        let trainedNotes = midiRange.filter { statsForNote($0).isTrained }
        guard !trainedNotes.isEmpty else { return nil }
        let avg = trainedNotes.map { statsForNote($0).mean }.reduce(0.0, +) / Double(trainedNotes.count)
        return Int(avg)
    }

    // MARK: - Accessors

    /// Returns statistics for a specific MIDI note
    /// - Parameter note: MIDI note (0-127)
    /// - Returns: PerceptualNote statistics (returns empty stats if invalid note)
    func statsForNote(_ note: Int) -> PerceptualNote {
        guard note >= 0 && note < 128 else {
            logger.error("Invalid MIDI note: \(note)")
            return PerceptualNote()
        }
        return noteStats[note]
    }

    // MARK: - Reset

    /// Resets all per-note statistics to cold start state
    /// Used by Settings "Reset All Training Data" action
    func reset() {
        noteStats = Array(repeating: PerceptualNote(), count: 128)
        logger.info("PerceptualProfile reset to cold start")
    }

    // MARK: - Regional Difficulty Management

    /// Sets the current active difficulty for a note (for regional training)
    /// Used by AdaptiveNoteStrategy to track gradual difficulty adjustments
    /// - Parameters:
    ///   - note: MIDI note (0-127)
    ///   - difficulty: Difficulty in cents
    func setDifficulty(note: Int, difficulty: Double) {
        guard note >= 0 && note < 128 else {
            logger.error("Invalid MIDI note: \(note)")
            return
        }

        noteStats[note].currentDifficulty = difficulty
        logger.debug("Set difficulty for note \(note): \(difficulty) cents")
    }
}

// MARK: - PerceptualNote

/// Per-note statistics for pitch discrimination
struct PerceptualNote {
    /// Mean detection threshold (cents) - unsigned average of absolute cent offsets
    var mean: Double

    /// Standard deviation (cents) - consistency measure
    var stdDev: Double

    /// Sum of squared differences (for Welford's algorithm)
    var m2: Double

    /// Number of comparisons for this note (correct and incorrect)
    var sampleCount: Int

    /// Current active difficulty for regional training (cents)
    /// Used by AdaptiveNoteStrategy for gradual difficulty adjustment
    var currentDifficulty: Double

    /// Creates an empty PerceptualNote (cold start state)
    init(mean: Double = 0.0, stdDev: Double = 0.0, m2: Double = 0.0, sampleCount: Int = 0, currentDifficulty: Double = 100.0) {
        self.mean = mean
        self.stdDev = stdDev
        self.m2 = m2
        self.sampleCount = sampleCount
        self.currentDifficulty = currentDifficulty
    }

    /// Whether this note has been trained
    var isTrained: Bool {
        sampleCount > 0
    }
}

// MARK: - ComparisonObserver Conformance

extension PerceptualProfile: ComparisonObserver {
    /// Observes comparison completion and updates detection threshold statistics
    /// - Parameter completed: The completed comparison with user's answer and result
    func comparisonCompleted(_ completed: CompletedComparison) {
        let comparison = completed.comparison

        // Use unsigned centDifference — direction is irrelevant for threshold measurement
        let centOffset = comparison.centDifference

        // Update profile incrementally using Welford's algorithm
        update(
            note: comparison.note1,
            centOffset: centOffset,
            isCorrect: completed.isCorrect
        )
    }
}
