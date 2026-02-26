import Testing
import Foundation
@testable import Peach

/// Comprehensive test suite for PerceptualProfile
/// Tests aggregation, incremental updates, and weak spot identification
@Suite("PerceptualProfile Tests")
struct PerceptualProfileTests {

    // MARK: - Task 1 Tests: Data Structure and Cold Start

    @Test("Cold start profile has no statistics")
    func coldStartProfile() async throws {
        let profile = PerceptualProfile()

        // Cold start should have nil summary statistics
        #expect(profile.overallMean == nil)
        #expect(profile.overallStdDev == nil)
    }

    @Test("Cold start treats all notes as weak spots")
    func coldStartWeakSpots() async throws {
        let profile = PerceptualProfile()

        // All 128 MIDI notes should be weak spots when no data exists
        let weakSpots = profile.weakSpots(count: 128)
        #expect(weakSpots.count == 128)
        #expect(weakSpots.contains(60)) // Middle C should be in weak spots
        #expect(weakSpots.contains(0))  // Lowest MIDI note
        #expect(weakSpots.contains(127)) // Highest MIDI note
    }

    @Test("Untrained notes have zero sample count")
    func untrainedNoteStats() async throws {
        let profile = PerceptualProfile()

        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 0)
        #expect(stats.mean == 0.0)
        #expect(stats.stdDev == 0.0)
    }

    // MARK: - Task 2 Tests: Initial Aggregation

    @Test("Aggregation computes correct mean from multiple records")
    func aggregationMean() async throws {
        let profile = PerceptualProfile()

        // Populate profile via update() - simulates app startup aggregation
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 60, centOffset: 45, isCorrect: true)
        profile.update(note: 60, centOffset: 55, isCorrect: true)

        let stats = profile.statsForNote(60)
        #expect(stats.mean == 50.0) // (50+45+55)/3
        #expect(stats.sampleCount == 3)
    }

    @Test("Aggregation handles multiple notes independently")
    func aggregationMultipleNotes() async throws {
        let profile = PerceptualProfile()

        // Populate multiple notes
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 62, centOffset: 30, isCorrect: true)
        profile.update(note: 64, centOffset: 40, isCorrect: true)

        #expect(profile.statsForNote(60).mean == 50.0)
        #expect(profile.statsForNote(62).mean == 30.0)
        #expect(profile.statsForNote(64).mean == 40.0)
        #expect(profile.statsForNote(61).sampleCount == 0) // Untrained note
    }

    @Test("Aggregation includes all answers (both correct and incorrect)")
    func aggregationIncludesAllAnswers() async throws {
        let profile = PerceptualProfile()

        // Mix of correct and incorrect answers - ALL should be tracked
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 60, centOffset: 200, isCorrect: false) // Now included
        profile.update(note: 60, centOffset: 60, isCorrect: true)

        let stats = profile.statsForNote(60)
        let expectedMean = (50.0 + 200.0 + 60.0) / 3.0  // All three comparisons
        #expect(abs(stats.mean - expectedMean) < 0.01) // ~103.33
        #expect(stats.sampleCount == 3)  // All answers counted
    }

    // MARK: - Task 3 Tests: Incremental Update

    @Test("Incremental update from cold start")
    func incrementalUpdateColdStart() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 50, isCorrect: true)

        let stats = profile.statsForNote(60)
        #expect(stats.mean == 50.0)
        #expect(stats.sampleCount == 1)
    }

    @Test("Incremental update computes correct running mean")
    func incrementalUpdateMean() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 60, centOffset: 40, isCorrect: true)

        let stats = profile.statsForNote(60)
        #expect(stats.mean == 45.0) // (50+40)/2
        #expect(stats.sampleCount == 2)
    }

    @Test("Incremental update includes all answers (both correct and incorrect)")
    func incrementalUpdateIncludesAllAnswers() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 60, centOffset: 200, isCorrect: false) // Now included
        profile.update(note: 60, centOffset: 60, isCorrect: true)

        let stats = profile.statsForNote(60)
        let expectedMean = (50.0 + 200.0 + 60.0) / 3.0  // All three comparisons
        #expect(abs(stats.mean - expectedMean) < 0.01) // ~103.33
        #expect(stats.sampleCount == 3)  // All answers counted
    }

    @Test("Incremental update handles multiple notes independently")
    func incrementalUpdateMultipleNotes() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 62, centOffset: 30, isCorrect: true)
        profile.update(note: 60, centOffset: 60, isCorrect: true)

        #expect(profile.statsForNote(60).mean == 55.0) // (50+60)/2
        #expect(profile.statsForNote(62).mean == 30.0)
    }

    // MARK: - Task 4 Tests: Weak Spot Identification

    @Test("Weak spots include untrained notes")
    func weakSpotsIncludeUntrained() async throws {
        let profile = PerceptualProfile()

        // Train only one note
        profile.update(note: 60, centOffset: 10, isCorrect: true)

        let weakSpots = profile.weakSpots(count: 10)

        // All weak spots should be untrained notes (127 total), since untrained has highest priority
        #expect(weakSpots.count == 10)
        // Note 60 is trained (low threshold), so it should NOT be in weak spots
        #expect(!weakSpots.contains(60))
        // All 10 weak spots should be untrained notes (any of the 127 untrained notes)
        let allUntrained = weakSpots.allSatisfy { $0 != 60 }
        #expect(allUntrained)
    }

    @Test("Weak spots prioritize high threshold trained notes over low threshold trained notes")
    func weakSpotsPrioritizeHighThreshold() async throws {
        let profile = PerceptualProfile()

        // Train ALL notes to avoid untrained notes being in weak spots
        for note in 0..<128 {
            let threshold: Double = (note == 60) ? 80.0 : (note == 62) ? 10.0 : 30.0
            profile.update(note: MIDINote(note), centOffset: threshold, isCorrect: true)
        }

        let weakSpots = profile.weakSpots(count: 5)

        // Note 60 (highest threshold=80) should be in top 5 weak spots
        #expect(weakSpots.contains(60))
        // Note 62 (lowest threshold=10) should NOT be in top 5 weak spots
        #expect(!weakSpots.contains(62))
    }

    // MARK: - Task 5 Tests: Summary Statistics

    @Test("Overall mean across trained notes")
    func overallMeanComputation() async throws {
        let profile = PerceptualProfile()

        // Train three notes
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 62, centOffset: 30, isCorrect: true)
        profile.update(note: 64, centOffset: 40, isCorrect: true)

        #expect(profile.overallMean == 40.0) // (50+30+40)/3
    }

    @Test("Overall standard deviation computation")
    func overallStdDevComputation() async throws {
        let profile = PerceptualProfile()

        // Train three notes with same threshold
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 62, centOffset: 50, isCorrect: true)
        profile.update(note: 64, centOffset: 50, isCorrect: true)

        // All same values = stdDev should be 0
        #expect(profile.overallStdDev == 0.0)
    }

    // MARK: - Task 6 Tests: Standard Deviation Calculation

    @Test("Standard deviation for single note with variance")
    func standardDeviationSingleNote() async throws {
        let profile = PerceptualProfile()

        // Add data with variance for note 60
        profile.update(note: 60, centOffset: 40, isCorrect: true)
        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.update(note: 60, centOffset: 60, isCorrect: true)

        let stats = profile.statsForNote(60)
        #expect(stats.mean == 50.0)
        // Sample stdDev = sqrt(((40-50)^2 + (50-50)^2 + (60-50)^2) / 2) = sqrt(100) ≈ 10.0
        #expect(abs(stats.stdDev - 10.0) < 0.01)
    }
}
