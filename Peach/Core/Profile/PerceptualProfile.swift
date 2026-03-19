import Foundation
import OSLog

@Observable
final class PerceptualProfile: PitchComparisonProfile, PitchMatchingProfile {

    // MARK: - PitchComparisonProfile State

    private var pitchComparison = WelfordAccumulator()

    // MARK: - PitchMatchingProfile State

    private var pitchMatching = WelfordAccumulator()

    private let logger = Logger(subsystem: "com.peach.app", category: "PerceptualProfile")

    // MARK: - Initialization

    init() {
        logger.info("PerceptualProfile initialized (cold start)")
    }

    // MARK: - PitchComparisonProfile

    func updateComparison(note: MIDINote, centOffset: Cents, isCorrect: Bool) {
        guard isCorrect else { return }
        pitchComparison.update(centOffset.magnitude)
        logger.debug("Updated comparison: mean=\(self.pitchComparison.mean), count=\(self.pitchComparison.count)")
    }

    var comparisonMean: Cents? {
        pitchComparison.centsMean
    }

    var comparisonStdDev: Cents? {
        pitchComparison.centsStdDev
    }

    // MARK: - PitchMatchingProfile

    func updateMatching(note: MIDINote, centError: Cents) {
        pitchMatching.update(centError.magnitude)
    }

    var matchingMean: Cents? {
        pitchMatching.centsMean
    }

    var matchingStdDev: Cents? {
        pitchMatching.centsStdDev
    }

    var matchingSampleCount: Int {
        pitchMatching.count
    }

    // MARK: - Reset

    func resetComparison() {
        pitchComparison = WelfordAccumulator()
        logger.info("PerceptualProfile comparison data reset")
    }

    func resetMatching() {
        pitchMatching = WelfordAccumulator()
        logger.info("Matching statistics reset")
    }

    func resetAll() {
        resetComparison()
        resetMatching()
        logger.info("PerceptualProfile fully reset to cold start")
    }
}

// MARK: - WelfordAccumulator

/// Welford's online algorithm for computing running mean and variance in a single pass.
private struct WelfordAccumulator {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0.0
    private var m2: Double = 0.0

    mutating func update(_ value: Double) {
        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        let delta2 = value - mean
        m2 += delta * delta2
    }

    var centsMean: Cents? {
        count > 0 ? Cents(mean) : nil
    }

    var centsStdDev: Cents? {
        guard count >= 2 else { return nil }
        return Cents(sqrt(m2 / Double(count - 1)))
    }
}

// MARK: - PitchComparisonObserver

extension PerceptualProfile: PitchComparisonObserver {
    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {
        let pitchComparison = completed.pitchComparison

        updateComparison(
            note: pitchComparison.referenceNote,
            centOffset: pitchComparison.targetNote.offset,
            isCorrect: completed.isCorrect
        )
    }
}

// MARK: - PitchMatchingObserver

extension PerceptualProfile: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        updateMatching(note: result.referenceNote, centError: result.userCentError)
    }
}
