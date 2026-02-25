import Foundation
import OSLog

/// Adaptive comparison selection strategy for intelligent training
///
/// Implements NextComparisonStrategy with stateless comparison selection:
/// - Reads user's PitchDiscriminationProfile for difficulty and weak spots
/// - Uses TrainingSettings for configuration
/// - Uses last completed comparison for nearby note selection
/// - Updates profile difficulty state externally (no internal state)
///
/// # Algorithm Design
///
/// **Note Selection:**
/// - Natural (0.0): Nearby notes (±12 semitones from last comparison)
/// - Mechanical (1.0): Weak spots from profile
/// - Blended: Weighted probability between the two
///
/// **Difficulty Determination:**
/// - Chain-based: uses previous comparison's cent difference as Kazez input
/// - Narrows on correct (Kazez formula), widens on incorrect (Kazez formula)
/// - Per-note difficulty still updated for profile tracking and weak spots
/// - Bootstrap (nil lastComparison): weighted effective difficulty from neighbors
///
/// # Performance
///
/// Must be fast (< 1ms) to meet NFR2 (no perceptible delay).
/// - In-memory only, no database queries
/// - Simple math: random selection, weighted probability, mean calculation
final class AdaptiveNoteStrategy: NextComparisonStrategy {

    // MARK: - Difficulty Parameters

    /// Tunable parameters for adaptive difficulty adjustment
    private enum DifficultyParameters {
        /// Regional range in semitones (±12 = one octave)
        /// Used for nearby note selection in Natural mode
        static let regionalRange: Int = 12

        /// Default difficulty for untrained regions (100 cents = 1 semitone)
        static let defaultDifficulty: Double = 100.0

        /// Maximum number of trained neighbors to consider in each direction
        static let maxNeighbors: Int = 5

        /// Kazez narrowing coefficient for correct answers
        /// N = P × [1 - (coefficient × √P)]
        /// Tuned from original 0.05 to 0.08 for faster multi-note convergence
        static let correctNarrowingCoefficient: Double = 0.08

        /// Kazez widening coefficient for incorrect answers
        /// N = P × [1 + (coefficient × √P)]
        static let incorrectWideningCoefficient: Double = 0.09
    }

    // MARK: - Properties

    /// Logger for algorithm decisions
    private let logger = Logger(subsystem: "com.peach.app", category: "AdaptiveNoteStrategy")

    // MARK: - Initialization

    /// Creates an AdaptiveNoteStrategy
    init() {
        logger.info("AdaptiveNoteStrategy initialized (stateless)")
    }

    // MARK: - NextComparisonStrategy Protocol

    /// Selects the next comparison based on perceptual profile and settings
    ///
    /// Stateless selection - updates profile difficulty via setDifficulty() for regional tracking.
    ///
    /// # Algorithm Flow
    ///
    /// 1. Select note using Natural/Mechanical balance
    /// 2. Determine cent difference from profile or default calculation
    /// 3. Return Comparison with note1, note2 (same), centDifference
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile
    ///   - settings: Training configuration
    ///   - lastComparison: Most recently completed comparison (nil on first)
    /// - Returns: Comparison ready for NotePlayer
    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Comparison {
        // Select note using Natural/Mechanical balance
        let selectedNote = selectNote(
            profile: profile,
            settings: settings,
            lastComparison: lastComparison
        )

        // Determine difficulty from profile (with regional adjustment)
        let centDifference = determineCentDifference(
            for: selectedNote,
            profile: profile,
            settings: settings,
            lastComparison: lastComparison
        )

        logger.info("Selected note=\(selectedNote), centDiff=\(centDifference)")

        return Comparison(
            note1: selectedNote,
            note2: selectedNote,  // Same MIDI note (frequency differs by cents)
            centDifference: centDifference,
            isSecondNoteHigher: Bool.random()  // Randomize direction
        )
    }

    // MARK: - Private Implementation

    /// Selects note using Natural/Mechanical balance
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile
    ///   - settings: Training configuration
    ///   - lastComparison: Last completed comparison (for nearby selection)
    /// - Returns: Selected MIDI note
    private func selectNote(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Int {
        let mechanicalRatio = settings.naturalVsMechanical

        // Weighted random: % chance to pick weak spot vs. nearby
        if Double.random(in: 0...1) < mechanicalRatio {
            // Pick weak spot
            return selectWeakSpot(profile: profile, settings: settings)
        } else {
            // Pick nearby note (if we have a last comparison)
            if let lastNote = lastComparison?.comparison.note1 {
                return selectNearbyNote(around: lastNote, settings: settings)
            } else {
                // First comparison: pick from weak spots
                return selectWeakSpot(profile: profile, settings: settings)
            }
        }
    }

    /// Selects a weak spot from profile within range
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile
    ///   - settings: Training configuration
    /// - Returns: MIDI note from weak spots, or random note if no weak spots in range
    private func selectWeakSpot(profile: PitchDiscriminationProfile, settings: TrainingSettings) -> Int {
        let weakSpots = profile.weakSpots(count: 10)
        let filtered = weakSpots.filter { settings.isInRange($0) }

        if let selected = filtered.randomElement() {
            logger.debug("Selected weak spot: \(selected)")
            return selected
        } else {
            // No weak spots in range, fall back to random within range
            logger.debug("No weak spots in range, using random selection")
            return Int.random(in: settings.noteRangeMin...settings.noteRangeMax)
        }
    }

    /// Selects a nearby note within range
    ///
    /// - Parameters:
    ///   - note: Center note for nearby selection
    ///   - settings: Training configuration
    /// - Returns: MIDI note near the center note
    private func selectNearbyNote(around note: Int, settings: TrainingSettings) -> Int {
        // Calculate nearby range using regionalRange (±12 semitones = one octave)
        let minNearby = max(settings.noteRangeMin, note - DifficultyParameters.regionalRange)
        let maxNearby = min(settings.noteRangeMax, note + DifficultyParameters.regionalRange)

        // Ensure valid range
        let actualMin = min(minNearby, settings.noteRangeMax)
        let actualMax = max(maxNearby, settings.noteRangeMin)

        let selected = Int.random(in: actualMin...actualMax)
        logger.debug("Selected nearby note: \(selected) (near \(note))")
        return selected
    }

    /// Determines cent difference for a note using chain-based convergence
    ///
    /// Uses Kazez sqrt(P)-scaled formulas for difficulty convergence:
    /// - Correct answer: `N = P × [1 - (correctNarrowingCoefficient × √P)]`
    /// - Incorrect answer: `N = P × [1 + (incorrectWideningCoefficient × √P)]`
    ///
    /// Where P = previous comparison's cent difference, N = new difficulty.
    ///
    /// Uses the last comparison's actual cent difference as input (not per-note
    /// stored difficulty) so the user sees a single smooth convergence chain
    /// regardless of which note is selected. Per-note difficulty is still
    /// updated for profile tracking and weak spot analysis.
    ///
    /// - Parameters:
    ///   - note: MIDI note
    ///   - profile: User's perceptual profile
    ///   - settings: Training configuration (for difficulty bounds)
    ///   - lastComparison: Most recently completed comparison (nil on first)
    /// - Returns: Cent difference (clamped to min/max)
    private func determineCentDifference(
        for note: Int,
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Double {
        guard let last = lastComparison else {
            let effective = weightedEffectiveDifficulty(for: note, profile: profile, settings: settings)
            return clamp(effective,
                         min: settings.minCentDifference,
                         max: settings.maxCentDifference)
        }

        // Use the previous comparison's cent difference as Kazez input.
        // This creates a single smooth convergence chain regardless of
        // which note is selected, so the user sees steadily narrowing
        // difficulty instead of jumps when switching notes.
        let p = last.comparison.centDifference
        let adjustedDiff = last.isCorrect
            ? max(p * (1.0 - DifficultyParameters.correctNarrowingCoefficient * p.squareRoot()),
                  settings.minCentDifference)
            : min(p * (1.0 + DifficultyParameters.incorrectWideningCoefficient * p.squareRoot()),
                  settings.maxCentDifference)

        profile.setDifficulty(note: note, difficulty: adjustedDiff)
        logger.debug("Difficulty for note \(note): \(last.isCorrect ? "correct" : "incorrect") → \(adjustedDiff) cents")
        return adjustedDiff
    }

    /// Computes weighted effective difficulty for a note using nearby trained neighbors
    ///
    /// Borrows evidence from up to 5 nearest trained notes in each direction,
    /// weighted by `1 / (1 + distance)`. When no trained data exists, returns the default (100 cents).
    ///
    /// - Parameters:
    ///   - note: MIDI note to compute difficulty for
    ///   - profile: User's perceptual profile
    ///   - settings: Training configuration (for note range bounds)
    /// - Returns: Weighted effective difficulty in cents
    private func weightedEffectiveDifficulty(
        for note: Int,
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings
    ) -> Double {
        let range = settings.noteRangeMin...settings.noteRangeMax

        // Include the current note at distance 0 if it has data:
        // either from user comparisons (sampleCount > 0) or from Kazez updates
        var candidates: [(distance: Int, difficulty: Double)] = []
        let currentStats = profile.statsForNote(note)
        if currentStats.sampleCount > 0
            || currentStats.currentDifficulty != DifficultyParameters.defaultDifficulty {
            candidates.append((distance: 0, difficulty: currentStats.currentDifficulty))
        }

        // Collect up to maxNeighbors trained notes below
        // Require non-default difficulty to exclude unrefined notes still at 100 cents
        var leftCount = 0
        for i in stride(from: note - 1, through: range.lowerBound, by: -1) {
            guard leftCount < DifficultyParameters.maxNeighbors else { break }
            let stats = profile.statsForNote(i)
            if stats.sampleCount > 0
                && stats.currentDifficulty != DifficultyParameters.defaultDifficulty {
                candidates.append((distance: note - i, difficulty: stats.currentDifficulty))
                leftCount += 1
            }
        }

        // Collect up to maxNeighbors trained notes above
        // Require non-default difficulty to exclude unrefined notes still at 100 cents
        var rightCount = 0
        for i in stride(from: note + 1, through: range.upperBound, by: 1) {
            guard rightCount < DifficultyParameters.maxNeighbors else { break }
            let stats = profile.statsForNote(i)
            if stats.sampleCount > 0
                && stats.currentDifficulty != DifficultyParameters.defaultDifficulty {
                candidates.append((distance: i - note, difficulty: stats.currentDifficulty))
                rightCount += 1
            }
        }

        guard !candidates.isEmpty else {
            return DifficultyParameters.defaultDifficulty
        }

        var weightSum = 0.0
        var weightedSum = 0.0
        for candidate in candidates {
            let w = 1.0 / (1.0 + Double(candidate.distance))
            weightSum += w
            weightedSum += w * candidate.difficulty
        }

        return weightedSum / weightSum
    }

    /// Clamps a value between min and max bounds
    ///
    /// - Parameters:
    ///   - value: Value to clamp
    ///   - min: Minimum bound
    ///   - max: Maximum bound
    /// - Returns: Clamped value
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
}
